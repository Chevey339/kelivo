package com.tundralabs.fluttertts

import android.content.ContentValues
import android.content.Context
import android.media.AudioAttributes
import android.media.AudioFocusRequest
import android.media.AudioManager
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.os.Environment
import android.os.Handler
import android.os.Looper
import android.os.ParcelFileDescriptor
import android.provider.MediaStore
import android.provider.OpenableColumns
import android.speech.tts.TextToSpeech
import android.speech.tts.UtteranceProgressListener
import android.speech.tts.Voice
import io.flutter.Log
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result
import java.io.File
import java.lang.reflect.Field
import java.util.Locale
import java.util.MissingResourceException
import java.util.UUID


/** FlutterTtsPlugin  */
class FlutterTtsPlugin : MethodCallHandler, FlutterPlugin {
    private var handler: Handler? = null
    private var methodChannel: MethodChannel? = null
    private var speakResult: Result? = null
    private var synthResult: Result? = null
    private var awaitSpeakCompletion = false
    private var speaking = false
    private var awaitSynthCompletion = false
    private var synth = false
    private var context: Context? = null
    private var tts: TextToSpeech? = null
    private var speechRate: Float? = null
    private val tag = "TTS"
    private val pendingMethodCalls = ArrayList<Runnable>()
    private val utterances = HashMap<String, String>()
    private var bundle: Bundle? = null
    private var silencems = 0
    private var lastProgress = 0
    private var currentText: String? = null
    private var pauseText: String? = null
    private var isPaused: Boolean = false
    private var queueMode: Int = TextToSpeech.QUEUE_FLUSH
    private var ttsStatus: Int? = null
    private var selectedEngine: String? = null
    private var engineResult: Result? = null
    private var parcelFileDescriptor: ParcelFileDescriptor? = null
    private var audioManager: AudioManager? = null
    private var audioFocusRequest: AudioFocusRequest? = null

    companion object {
        private const val SILENCE_PREFIX = "SIL_"
        private const val SYNTHESIZE_TO_FILE_PREFIX = "STF_"
    }

    private fun initInstance(messenger: BinaryMessenger, context: Context) {
        this.context = context
        methodChannel = MethodChannel(messenger, "flutter_tts")
        methodChannel!!.setMethodCallHandler(this)
        handler = Handler(Looper.getMainLooper())
        bundle = Bundle()
        tts = TextToSpeech(context, onInitListenerWithoutCallback)
    }

    /** Android Plugin APIs  */
    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        initInstance(binding.binaryMessenger, binding.applicationContext)
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        stop()
        tts!!.shutdown()
        context = null
        methodChannel!!.setMethodCallHandler(null)
        methodChannel = null
    }

    private val utteranceProgressListener: UtteranceProgressListener =
        object : UtteranceProgressListener() {
            override fun onStart(utteranceId: String) {
                if (utteranceId.startsWith(SYNTHESIZE_TO_FILE_PREFIX)) {
                    invokeMethod("synth.onStart", true)
                } else {
                    if (isPaused) {
                        invokeMethod("speak.onContinue", true)
                        isPaused = false
                    } else {
                        Log.d(tag, "Utterance ID has started: $utteranceId")
                        invokeMethod("speak.onStart", true)
                    }
                }
                if (Build.VERSION.SDK_INT < 26) {
                    onProgress(utteranceId, 0, utterances[utteranceId]!!.length)
                }
            }

            override fun onDone(utteranceId: String) {
                if (utteranceId.startsWith(SILENCE_PREFIX)) return
                if (utteranceId.startsWith(SYNTHESIZE_TO_FILE_PREFIX)) {
                    closeParcelFileDescriptor(false)
                    Log.d(tag, "Utterance ID has completed: $utteranceId")
                    if (awaitSynthCompletion) {
                        synthCompletion(1)
                    }
                    invokeMethod("synth.onComplete", true)
                } else {
                    Log.d(tag, "Utterance ID has completed: $utteranceId")
                    if (awaitSpeakCompletion && queueMode == TextToSpeech.QUEUE_FLUSH) {
                        speakCompletion(1)
                    }
                    invokeMethod("speak.onComplete", true)
                }
                lastProgress = 0
                pauseText = null
                utterances.remove(utteranceId)
                releaseAudioFocus()
            }

            override fun onStop(utteranceId: String, interrupted: Boolean) {
                Log.d(
                    tag,
                    "Utterance ID has been stopped: $utteranceId. Interrupted: $interrupted"
                )
                if (awaitSpeakCompletion) {
                    speaking = false
                }
                if (isPaused) {
                    invokeMethod("speak.onPause", true)
                } else {
                    invokeMethod("speak.onCancel", true)
                }
                releaseAudioFocus()
            }

            private fun onProgress(utteranceId: String?, startAt: Int, endAt: Int) {
                if (utteranceId != null && !utteranceId.startsWith(SYNTHESIZE_TO_FILE_PREFIX)) {
                    val text = utterances[utteranceId]
                    val data = HashMap<String, String?>()
                    data["text"] = text
                    data["start"] = startAt.toString()
                    data["end"] = endAt.toString()
                    data["word"] = text!!.substring(startAt, endAt)
                    invokeMethod("speak.onProgress", data)
                }
            }

            // Requires Android 26 or later
            override fun onRangeStart(utteranceId: String, startAt: Int, endAt: Int, frame: Int) {
                if (!utteranceId.startsWith(SYNTHESIZE_TO_FILE_PREFIX)) {
                    lastProgress = startAt
                    super.onRangeStart(utteranceId, startAt, endAt, frame)
                    onProgress(utteranceId, startAt, endAt)
                }
            }

            @Deprecated("")
            override fun onError(utteranceId: String) {
                if (utteranceId.startsWith(SYNTHESIZE_TO_FILE_PREFIX)) {
                    closeParcelFileDescriptor(true)
                    if (awaitSynthCompletion) {
                        synth = false
                    }
                    invokeMethod("synth.onError", "Error from TextToSpeech (synth)")
                } else {
                    if (awaitSpeakCompletion) {
                        speaking = false
                    }
                    invokeMethod("speak.onError", "Error from TextToSpeech (speak)")
                }
                releaseAudioFocus()
            }

            override fun onError(utteranceId: String, errorCode: Int) {
                if (utteranceId.startsWith(SYNTHESIZE_TO_FILE_PREFIX)) {
                    closeParcelFileDescriptor(true)
                    if (awaitSynthCompletion) {
                        synth = false
                    }
                    invokeMethod("synth.onError", "Error from TextToSpeech (synth) - $errorCode")
                } else {
                    if (awaitSpeakCompletion) {
                        speaking = false
                    }
                    invokeMethod("speak.onError", "Error from TextToSpeech (speak) - $errorCode")
                }
            }
        }

    fun speakCompletion(success: Int) {
        speaking = false
        handler!!.post {
            speakResult?.success(success)
            speakResult = null
        }
    }

    fun synthCompletion(success: Int) {
        synth = false
        handler!!.post {
            synthResult?.success(success)
            synthResult = null
        }
    }

    @Synchronized
    private fun runPendingMethodCalls(status: Int) {
        ttsStatus = status
        if (status == TextToSpeech.SUCCESS) {
            // A queued speak may be retried before Dart sees the new engine.
            speechRate?.let { tts!!.setSpeechRate(it) }
        }
        val pending = pendingMethodCalls.toList()
        pendingMethodCalls.clear()
        for (call in pending) call.run()
    }

    private val onInitListenerWithCallback: TextToSpeech.OnInitListener =
        TextToSpeech.OnInitListener { status ->
            runPendingMethodCalls(status)
            if (status == TextToSpeech.SUCCESS) {
                tts!!.setOnUtteranceProgressListener(utteranceProgressListener)
                try {
                    val locale: Locale = tts!!.defaultVoice.locale
                    if (isLanguageAvailable(locale)) {
                        tts!!.language = locale
                    }
                } catch (e: NullPointerException) {
                    Log.e(tag, "getDefaultLocale: " + e.message)
                } catch (e: IllegalArgumentException) {
                    Log.e(tag, "getDefaultLocale: " + e.message)
                }

                engineResult!!.success(1)
            } else {
                engineResult!!.error("TtsError","Failed to initialize TextToSpeech with status: $status", null)
            }
            //engineResult = null
        }

    private val onInitListenerWithoutCallback: TextToSpeech.OnInitListener =
        TextToSpeech.OnInitListener { status ->
            runPendingMethodCalls(status)

            if (status == TextToSpeech.SUCCESS) {
                tts!!.setOnUtteranceProgressListener(utteranceProgressListener)
                try {
                    val locale: Locale = tts!!.defaultVoice.locale
                    if (isLanguageAvailable(locale)) {
                        tts!!.language = locale
                    }
                } catch (e: NullPointerException) {
                    Log.e(tag, "getDefaultLocale: " + e.message)
                } catch (e: IllegalArgumentException) {
                    Log.e(tag, "getDefaultLocale: " + e.message)
                }
            } else {
                Log.e(tag, "Failed to initialize TextToSpeech with status: $status")
            }
        }

    override fun onMethodCall(call: MethodCall, result: Result) {
        // If TTS is still loading
        synchronized(this@FlutterTtsPlugin) {
            if (ttsStatus == null) {
                // Suspend method call until the TTS engine is ready
                val suspendedCall = Runnable { onMethodCall(call, result) }
                pendingMethodCalls.add(suspendedCall)
                return
            }
        }
        when (call.method) {
            "speak" -> {
                var text: String = call.argument("text")!!
                val focus: Boolean = call.argument("focus")!!
                if (pauseText == null) {
                    pauseText = text
                    currentText = pauseText!!
                }
                if (isPaused) {
                    // Ensure the text hasn't changed
                    if (currentText == text) {
                        text = pauseText!!
                    } else {
                        pauseText = text
                        currentText = pauseText!!
                        lastProgress = 0
                    }
                }
                if (speaking) {
                    // If TTS is set to queue mode, allow the utterance to be queued up rather than discarded
                    if (queueMode == TextToSpeech.QUEUE_FLUSH) {
                        result.success(0)
                        return
                    }
                }
                val b = speak(text, focus)
                if (!b) {
                    synchronized(this@FlutterTtsPlugin) {
                        val suspendedCall = Runnable { onMethodCall(call, result) }
                        pendingMethodCalls.add(suspendedCall)
                    }
                    return
                }
                // Only use await speak completion if queueMode is set to QUEUE_FLUSH
                if (awaitSpeakCompletion && queueMode == TextToSpeech.QUEUE_FLUSH) {
                    speaking = true
                    speakResult = result
                } else {
                    result.success(1)
                }
            }

            "awaitSpeakCompletion" -> {
                awaitSpeakCompletion = java.lang.Boolean.parseBoolean(call.arguments.toString())
                result.success(1)
            }

            "awaitSynthCompletion" -> {
                awaitSynthCompletion = java.lang.Boolean.parseBoolean(call.arguments.toString())
                result.success(1)
            }

            "getMaxSpeechInputLength" -> {
                val res = maxSpeechInputLength
                result.success(res)
            }

            "synthesizeToFile" -> {
                val text: String? = call.argument("text")
                if (synth) {
                    result.success(0)
                    return
                }
                val fileName: String? = call.argument("fileName")
                val isFullPath: Boolean? = call.argument("isFullPath")
                synthesizeToFile(text!!, fileName!!, isFullPath!!)
                if (awaitSynthCompletion) {
                    synth = true
                    synthResult = result
                } else {
                    result.success(1)
                }
            }

            "pause" -> {
                isPaused = true
                if (pauseText != null) {
                    pauseText = pauseText!!.substring(lastProgress)
                }
                stop()
                result.success(1)
                if (speakResult != null) {
                    speakResult!!.success(0)
                    speakResult = null
                }
            }

            "stop" -> {
                isPaused = false
                pauseText = null
                stop()
                lastProgress = 0
                result.success(1)
                if (speakResult != null) {
                    speakResult!!.success(0)
                    speakResult = null
                }
            }

            "setEngine" -> {
                val engine: String = call.arguments.toString()
                setEngine(engine, result)
            }

            "setSpeechRate" -> {
                val rate: String = call.arguments.toString()
                // To make the FlutterTts API consistent across platforms,
                // Android 1.0 is mapped to flutter 0.5.
                val nativeRate = rate.toFloat() * 2.0f
                speechRate = nativeRate
                tts!!.setSpeechRate(nativeRate)
                result.success(1)
            }

            "setVolume" -> {
                val volume: String = call.arguments.toString()
                setVolume(volume.toFloat(), result)
            }

            "setPitch" -> {
                val pitch: String = call.arguments.toString()
                setPitch(pitch.toFloat(), result)
            }

            "setLanguage" -> {
                val language: String = call.arguments.toString()
                setLanguage(language, result)
            }

            "getLanguages" -> getLanguages(result)
            "getVoices" -> getVoices(result)
            "getSpeechRateValidRange" -> getSpeechRateValidRange(result)
            "getEngines" -> getEngines(result)
            "getDefaultEngine" -> getDefaultEngine(result)
            "getDefaultVoice" -> getDefaultVoice(result)
            "setVoice" -> {
                val voice: HashMap<String?, String>? = call.arguments()
                setVoice(voice!!, result)
            }

            "clearVoice" -> clearVoice(result)

            "isLanguageAvailable" -> {
                val language: String = call.arguments.toString()
                val locale: Locale = Locale.forLanguageTag(language)
                result.success(isLanguageAvailable(locale))
            }

            "setSilence" -> {
                val silencems: String = call.arguments.toString()
                this.silencems = silencems.toInt()
            }

            "setSharedInstance" -> result.success(1)
            "isLanguageInstalled" -> {
                val language: String = call.arguments.toString()
                result.success(isLanguageInstalled(language))
            }

            "areLanguagesInstalled" -> {
                val languages: List<String?>? = call.arguments()
                result.success(areLanguagesInstalled(languages!!))
            }

            "setQueueMode" -> {
                val queueMode: String = call.arguments.toString()
                this.queueMode = queueMode.toInt()
                result.success(1)
            }

            "setAudioAttributesForNavigation" -> {
                setAudioAttributesForNavigation()
                result.success(1)
            }

            else -> result.notImplemented()
        }
    }

    private fun isLanguageAvailable(locale: Locale?): Boolean {
        return tts!!.isLanguageAvailable(locale) >= TextToSpeech.LANG_AVAILABLE
    }

    private fun areLanguagesInstalled(languages: List<String?>): Map<String?, Boolean> {
        val result: MutableMap<String?, Boolean> = HashMap()
        for (language in languages) {
            result[language] = isLanguageInstalled(language)
        }
        return result
    }

    private fun isLanguageInstalled(language: String?): Boolean {
        val locale: Locale = Locale.forLanguageTag(language!!)
        if (isLanguageAvailable(locale)) {
            var voiceToCheck: Voice? = null
            for (v in tts!!.voices) {
                if (v.locale == locale && !v.isNetworkConnectionRequired) {
                    voiceToCheck = v
                    break
                }
            }
            if (voiceToCheck != null) {
                val features: Set<String> = voiceToCheck.features
                return (!features.contains(TextToSpeech.Engine.KEY_FEATURE_NOT_INSTALLED))
            }
        }
        return false
    }

    private fun setEngine(engine: String?, result: Result) {
        ttsStatus = null
        selectedEngine = engine
        engineResult = result
        tts = TextToSpeech(context, onInitListenerWithCallback, engine)
    }

    private fun setLanguage(language: String?, result: Result) {
        val locale: Locale = Locale.forLanguageTag(language!!)
        if (isLanguageAvailable(locale)) {
            tts!!.language = locale
            result.success(1)
        } else {
            result.success(0)
        }
    }

    private fun setVoice(voice: HashMap<String?, String>, result: Result) {
        for (ttsVoice in tts!!.voices) {
            if (ttsVoice.name == voice["name"] && ttsVoice.locale
                    .toLanguageTag() == voice["locale"]
            ) {
                tts!!.voice = ttsVoice
                result.success(1)
                return
            }
        }
        Log.d(tag, "Voice name not found: $voice")
        result.success(0)
    }

    private fun clearVoice(result: Result) {
        tts!!.voice = tts!!.defaultVoice
        result.success(1)
    }

    private fun setVolume(volume: Float, result: Result) {
        if (volume in (0.0f..1.0f)) {
            bundle!!.putFloat(TextToSpeech.Engine.KEY_PARAM_VOLUME, volume)
            result.success(1)
        } else {
            Log.d(tag, "Invalid volume $volume value - Range is from 0.0 to 1.0")
            result.success(0)
        }
    }

    private fun setPitch(pitch: Float, result: Result) {
        if (pitch in (0.5f..2.0f)) {
            tts!!.setPitch(pitch)
            result.success(1)
        } else {
            Log.d(tag, "Invalid pitch $pitch value - Range is from 0.5 to 2.0")
            result.success(0)
        }
    }

    private fun getVoices(result: Result) {
        val voices = ArrayList<HashMap<String, String>>()
        try {
            for (voice in tts!!.voices) {
                val voiceMap = HashMap<String, String>()
                readVoiceProperties(voiceMap, voice)
                voices.add(voiceMap)
            }
            result.success(voices)
        } catch (e: NullPointerException) {
            Log.d(tag, "getVoices: " + e.message)
            result.success(null)
        }
    }

    private fun getLanguages(result: Result) {
        val locales = ArrayList<String>()
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                // While this method was introduced in API level 21, it seems that it
                // has not been implemented in the speech service side until API Level 23.
                for (locale in tts!!.availableLanguages) {
                    locales.add(locale.toLanguageTag())
                }
            } else {
                for (locale in Locale.getAvailableLocales()) {
                    if (locale.variant.isEmpty() && isLanguageAvailable(locale)) {
                        locales.add(locale.toLanguageTag())
                    }
                }
            }
        } catch (e: MissingResourceException) {
            Log.d(tag, "getLanguages: " + e.message)
        } catch (e: NullPointerException) {
            Log.d(tag, "getLanguages: " + e.message)
        }
        result.success(locales)
    }

    private fun getEngines(result: Result) {
        val engines = ArrayList<String>()
        try {
            for (engineInfo in tts!!.engines) {
                engines.add(engineInfo.name)
            }
        } catch (e: Exception) {
            Log.d(tag, "getEngines: " + e.message)
        }
        result.success(engines)
    }

    private fun getDefaultEngine(result: Result) {
        val defaultEngine: String? = tts!!.defaultEngine
        result.success(defaultEngine)
    }

    private fun getDefaultVoice(result: Result) {
        val defaultVoice: Voice? = tts!!.defaultVoice
        val voice = HashMap<String, String>()
        if (defaultVoice != null) {
            readVoiceProperties(voice, defaultVoice)
        }
        result.success(voice)
    }
    // Add voice properties into the voice map
    fun readVoiceProperties(map: MutableMap<String, String>, voice: Voice) {
        map["name"] = voice.name
        map["locale"] = voice.locale.toLanguageTag()
        map["quality"] = qualityToString(voice.quality)
        map["latency"] = latencyToString(voice.latency)
        map["network_required"] = if (voice.isNetworkConnectionRequired) "1" else "0"
        map["features"] = voice.features.joinToString(separator = "\t")
        
    }

    // Function to map quality integer to the constant name
    fun qualityToString(quality: Int): String {
        return when (quality) {
            Voice.QUALITY_VERY_HIGH -> "very high"
            Voice.QUALITY_HIGH -> "high"
            Voice.QUALITY_NORMAL -> "normal"
            Voice.QUALITY_LOW -> "low"
            Voice.QUALITY_VERY_LOW -> "very low"
            else -> "unknown"
        }
    }
    // Function to map latency integer to the constant name
    fun latencyToString(quality: Int): String {
        return when (quality) {
            Voice.LATENCY_VERY_HIGH -> "very high"
            Voice.LATENCY_HIGH -> "high"
            Voice.LATENCY_NORMAL -> "normal"
            Voice.LATENCY_LOW -> "low"
            Voice.LATENCY_VERY_LOW -> "very low"
            else -> "unknown"
        }
    }

    private fun getSpeechRateValidRange(result: Result) {
        // Valid values available in the android documentation.
        // https://developer.android.com/reference/android/speech/tts/TextToSpeech#setSpeechRate(float)
        // To make the FlutterTts API consistent across platforms,
        // we map Android 1.0 to flutter 0.5 and so on.
        val data = HashMap<String, String>()
        data["min"] = "0"
        data["normal"] = "0.5"
        data["max"] = "1.5"
        data["platform"] = "android"
        result.success(data)
    }

    private fun speak(text: String, focus: Boolean): Boolean {
        val uuid: String = UUID.randomUUID().toString()
        utterances[uuid] = text
        return if (ismServiceConnectionUsable(tts)) {
            if(focus){
                requestAudioFocus()
            }

            if (silencems > 0) {
                tts!!.playSilentUtterance(
                    silencems.toLong(),
                    TextToSpeech.QUEUE_FLUSH,
                    SILENCE_PREFIX + uuid
                )
                tts!!.speak(text, TextToSpeech.QUEUE_ADD, bundle, uuid) == 0
            } else {
                tts!!.speak(text, queueMode, bundle, uuid) == 0
            }
        } else {
            ttsStatus = null
            tts = TextToSpeech(context, onInitListenerWithoutCallback, selectedEngine)
            false
        }
    }

    private fun stop() {
        if (awaitSynthCompletion) synth = false
        if (awaitSpeakCompletion) speaking = false
        tts!!.stop()
    }

    private val maxSpeechInputLength: Int
        get() = TextToSpeech.getMaxSpeechInputLength()

    private fun closeParcelFileDescriptor(isError: Boolean)  {
        if (this.parcelFileDescriptor != null)  {
            if (isError) {
                this.parcelFileDescriptor!!.closeWithError("Error synthesizing TTS to file")
            } else {
                this.parcelFileDescriptor!!.close()
            }
        }
    }

    private fun synthesizeToFile(text: String, fileName: String, isFullPath: Boolean) {
        val fullPath: String
        val uuid: String = UUID.randomUUID().toString()
        bundle!!.putString(
            TextToSpeech.Engine.KEY_PARAM_UTTERANCE_ID,
            SYNTHESIZE_TO_FILE_PREFIX + uuid
        )

        val result: Int =
            if(isFullPath){
                val file = File(fileName)
                fullPath = file.path

                tts!!.synthesizeToFile(text, bundle!!, file!!, SYNTHESIZE_TO_FILE_PREFIX + uuid)
            } else if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
                val resolver = this.context?.contentResolver
                val contentValues = ContentValues().apply {
                    put(MediaStore.MediaColumns.DISPLAY_NAME, fileName)
                    put(MediaStore.MediaColumns.MIME_TYPE, "audio/wav")
                    put(MediaStore.MediaColumns.RELATIVE_PATH, Environment.DIRECTORY_MUSIC)
                }
                val uri = resolver?.insert(MediaStore.Audio.Media.EXTERNAL_CONTENT_URI, contentValues)
                this.parcelFileDescriptor = resolver?.openFileDescriptor(uri!!, "rw")
                fullPath = uri?.path + File.separatorChar + fileName

                tts!!.synthesizeToFile(text, bundle!!, parcelFileDescriptor!!, SYNTHESIZE_TO_FILE_PREFIX + uuid)
            } else {
                val musicDir = Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_MUSIC)
                val file = File(musicDir, fileName)
                fullPath = file.path

                tts!!.synthesizeToFile(text, bundle!!, file!!, SYNTHESIZE_TO_FILE_PREFIX + uuid)
            }

        if (result == TextToSpeech.SUCCESS) {
            Log.d(tag, "Successfully created file : $fullPath")
        } else {
            Log.d(tag, "Failed creating file : $fullPath")
        }
    }

    private fun invokeMethod(method: String, arguments: Any) {
        handler!!.post {
            if (methodChannel != null) methodChannel!!.invokeMethod(
                method,
                arguments
            )
        }
    }

    private fun ismServiceConnectionUsable(tts: TextToSpeech?): Boolean {
        var isBindConnection = true
        if (tts == null) {
            return false
        }
        val fields: Array<Field> = tts.javaClass.declaredFields
        for (j in fields.indices) {
            fields[j].isAccessible = true
            if ("mServiceConnection" == fields[j].name && "android.speech.tts.TextToSpeech\$Connection" == fields[j].type.name) {
                try {
                    if (fields[j][tts] == null) {
                        isBindConnection = false
                        Log.e(tag, "*******TTS -> mServiceConnection == null*******")
                    }
                } catch (e: IllegalArgumentException) {
                    e.printStackTrace()
                } catch (e: IllegalAccessException) {
                    e.printStackTrace()
                } catch (e: Exception) {
                    e.printStackTrace()
                }
            }
        }
        return isBindConnection
    }

    // Method to set AudioAttributes for navigation usage
    private fun setAudioAttributesForNavigation() {
        if (tts != null) {
            val audioAttributes = AudioAttributes.Builder()
                .setUsage(AudioAttributes.USAGE_ASSISTANCE_NAVIGATION_GUIDANCE)
                .setContentType(AudioAttributes.CONTENT_TYPE_SPEECH)
                .build()
            tts!!.setAudioAttributes(audioAttributes)
        }
    }

    private fun requestAudioFocus() {
        audioManager = context?.getSystemService(Context.AUDIO_SERVICE) as AudioManager

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            audioFocusRequest = AudioFocusRequest.Builder(AudioManager.AUDIOFOCUS_GAIN_TRANSIENT_MAY_DUCK)
                .setOnAudioFocusChangeListener { /* opcional para monitorar mudanças de foco */ }
                .build()
            audioManager?.requestAudioFocus(audioFocusRequest!!)
        } else {
            audioManager?.requestAudioFocus(null, AudioManager.STREAM_MUSIC, AudioManager.AUDIOFOCUS_GAIN_TRANSIENT_MAY_DUCK)
        }
    }

    private fun releaseAudioFocus() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            audioFocusRequest?.let { audioManager?.abandonAudioFocusRequest(it) }
        } else {
            audioManager?.abandonAudioFocus(null)
        }
    }
}
