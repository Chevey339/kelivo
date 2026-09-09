package com.psyche.kelivo.background

import android.animation.ObjectAnimator
import android.animation.ValueAnimator
import android.content.Context
import android.content.SharedPreferences
import android.content.res.Configuration
import android.graphics.BitmapFactory
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.Paint
import android.graphics.PixelFormat
import android.graphics.Typeface
import android.graphics.drawable.GradientDrawable
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.os.SystemClock
import android.provider.Settings
import android.text.TextUtils
import android.util.TypedValue
import android.view.Gravity
import android.view.MotionEvent
import android.view.View
import android.view.ViewConfiguration
import android.view.WindowManager
import android.view.animation.LinearInterpolator
import android.widget.Chronometer
import android.widget.FrameLayout
import android.widget.ImageView
import android.widget.LinearLayout
import android.widget.TextView
import com.psyche.kelivo.R
import java.io.File
import kotlin.math.abs

/** A presentation owned by the process; keeping a completed capsule never holds
 * the foreground service or WakeLock open. No task is restored after a crash. */
class BackgroundOverlay(
    private val context: Context,
    private val runtime: BackgroundRuntime,
    private val prefs: SharedPreferences,
) {
    private val windowManager = context.getSystemService(WindowManager::class.java)
    private val main = Handler(Looper.getMainLooper())
    private var view: LinearLayout? = null
    private var params: WindowManager.LayoutParams? = null
    private var title: TextView? = null
    private var detail: TextView? = null
    private var clock: Chronometer? = null
    private var icon: FrameLayout? = null
    private var spinner: OverlayProgressRing? = null
    private var appearance = BackgroundOverlayAppearance(emptyMap<String, Any>())
    private var geometry = appearance.layout(290f)
    private var iconKey = ""
    private var current: BackgroundTask? = null
    private var completed: BackgroundTask? = null
    private val dismissed = mutableSetOf<String>()
    private val expire = Runnable { completed = null; refresh() }
    private var pendingLongPress: Runnable? = null
    val isVisible get() = view != null

    fun sync(tasks: List<BackgroundTask>, terminal: BackgroundTask?) {
        if (terminal != null) {
            if (terminal.outcome == "cancelled") {
                if (completed?.id == terminal.id) completed = null
            } else if (tasks.isEmpty() && !runtime.foreground && runtime.enabled("overlayEnabled") &&
                terminal.id !in dismissed && current?.id == terminal.id && isVisible) {
                completed = terminal
            }
        }
        if (tasks.isNotEmpty()) completed = null
        if (!runtime.enabled("overlayEnabled")) completed = null
        dismissed.retainAll(tasks.map { it.id }.toSet() + listOfNotNull(completed?.id))
        refresh()
    }

    fun onForegroundChanged(foreground: Boolean) {
        if (foreground) completed = null
        refresh()
    }

    fun dismissAll() {
        dismissed.addAll(runtime.tasks.map { it.id })
        completed = null
        hide()
    }

    fun clearCompleted() { completed = null }

    fun refresh() {
        main.removeCallbacks(expire)
        if (runtime.foreground || !runtime.enabled("overlayEnabled") ||
            !Settings.canDrawOverlays(context) || runtime.isPromoted()) {
            hide()
            return
        }
        val seconds = ((runtime.setting("completionSeconds") as? Number)?.toLong() ?: 60).coerceIn(0, 900)
        val finish = completed
        if (finish != null) {
            val remaining = finish.finishedAt + seconds * 1000 - System.currentTimeMillis()
            if (remaining <= 0) completed = null else main.postDelayed(expire, remaining)
        }
        val task = runtime.tasks.firstOrNull { it.id !in dismissed } ?: completed
        if (task == null) { hide(); return }
        current = task
        try {
            val next = BackgroundOverlayAppearance(runtime.setting("overlayAppearance") as? Map<*, *> ?: emptyMap<String, Any>())
            val availableWidth = context.resources.displayMetrics.widthPixels / context.resources.displayMetrics.density - 16f
            val nextGeometry = next.layout(availableWidth)
            if (next != appearance || nextGeometry != geometry) {
                hide()
                appearance = next
                geometry = nextGeometry
            }
            if (view == null) create()
            val count = runtime.tasks.size
            title?.text = if (count > 1) "$count ${runtime.label("tasks", "Tasks")}" else task.title
            detail?.text = task.detail
            spinner?.visibility = if (appearance.showProgress && task.outcome.isEmpty()) View.VISIBLE else View.GONE
            clock?.apply {
                stop()
                if (task.outcome.isEmpty()) {
                    base = SystemClock.elapsedRealtime() - (System.currentTimeMillis() - task.startedAt).coerceAtLeast(0)
                    start()
                } else {
                    val duration = ((task.finishedAt - task.startedAt) / 1000).coerceAtLeast(0)
                    text = "%d:%02d".format(duration / 60, duration % 60)
                }
            }
            updateIcon()
            clampPosition()
        } catch (error: RuntimeException) {
            runtime.recordError("overlay_failed: ${error.message}")
            hide()
        }
    }

    private fun dp(value: Int) = (value * context.resources.displayMetrics.density).toInt()
    private fun dp(value: Float) = (value * context.resources.displayMetrics.density).toInt()

    private fun create() {
        val dark = context.resources.configuration.uiMode and Configuration.UI_MODE_NIGHT_MASK == Configuration.UI_MODE_NIGHT_YES
        val foreground = if (dark) Color.WHITE else Color.rgb(30, 32, 38)
        val root = LinearLayout(context).apply {
            orientation = LinearLayout.HORIZONTAL
            gravity = if (appearance.iconOnly) Gravity.CENTER else Gravity.CENTER_VERTICAL
            setPadding(dp(geometry.padding), dp(geometry.padding), dp(geometry.padding), dp(geometry.padding))
            elevation = if (appearance.showBackground) dp(8).toFloat() else 0f
            if (appearance.showBackground || appearance.showBorder) background = GradientDrawable().apply {
                setColor(if (!appearance.showBackground) Color.TRANSPARENT else
                    if (dark) Color.rgb(31, 33, 39) else Color.rgb(249, 250, 253))
                cornerRadius = dp(appearance.cornerRadius).toFloat()
                if (appearance.showBorder) setStroke(dp(1), if (dark) Color.rgb(93, 97, 107) else Color.rgb(200, 204, 213))
            }
            tag = "overlay"
            setOnLongClickListener { dismissAll(); true }
        }
        icon = FrameLayout(context).apply { tag = "icon" }
        root.addView(icon, LinearLayout.LayoutParams(dp(geometry.badge), dp(geometry.badge)))
        val textColumn = LinearLayout(context).apply {
            orientation = LinearLayout.VERTICAL
            gravity = Gravity.CENTER_VERTICAL
        }
        title = TextView(context).apply {
            tag = "title"
            setTextColor(foreground); setTextSize(TypedValue.COMPLEX_UNIT_DIP, 13f * geometry.textScale)
            setTypeface(null, Typeface.BOLD); includeFontPadding = false; gravity = Gravity.CENTER_VERTICAL
            maxLines = 1; ellipsize = TextUtils.TruncateAt.END
        }
        detail = TextView(context).apply {
            tag = "subtitle"
            setTextColor(foreground); alpha = 0.75f
            setTextSize(TypedValue.COMPLEX_UNIT_DIP, 11f * geometry.textScale)
            includeFontPadding = false; gravity = Gravity.CENTER_VERTICAL
            maxLines = 2; ellipsize = TextUtils.TruncateAt.END
        }
        clock = if (appearance.showTime) Chronometer(context).apply {
            tag = "time"; setTextColor(foreground); alpha = 0.65f
            setTextSize(TypedValue.COMPLEX_UNIT_DIP, 10f * geometry.textScale)
            includeFontPadding = false; gravity = Gravity.CENTER_VERTICAL
        } else null
        if (appearance.showTitle) textColumn.addView(title, LinearLayout.LayoutParams(-1, dp(16f * geometry.textScale)))
        if (appearance.showSubtitle) textColumn.addView(detail, LinearLayout.LayoutParams(-1, dp(28f * geometry.textScale)))
        if (appearance.showTime) textColumn.addView(clock, LinearLayout.LayoutParams(-1, dp(14f * geometry.textScale)))
        if (!appearance.iconOnly) root.addView(textColumn, LinearLayout.LayoutParams(0, -1, 1f).apply {
            leftMargin = dp(geometry.gap)
        })
        if (appearance.showClose) root.addView(TextView(context).apply {
            tag = "close"
            text = "×"; textSize = 24f; setTextColor(foreground); gravity = Gravity.CENTER
            contentDescription = runtime.label("close", "Dismiss")
            setOnClickListener { dismissAll() }
        }, LinearLayout.LayoutParams(dp(geometry.closeWidth), -1))
        val metrics = context.resources.displayMetrics
        val layout = WindowManager.LayoutParams(
            dp(geometry.width), dp(appearance.height),
            if (Build.VERSION.SDK_INT >= 26) WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY else WindowManager.LayoutParams.TYPE_PHONE,
            WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or WindowManager.LayoutParams.FLAG_NOT_TOUCH_MODAL,
            PixelFormat.TRANSLUCENT,
        ).apply {
            gravity = Gravity.TOP or Gravity.START
            x = prefs.getInt("overlay_x", dp(8))
            y = prefs.getInt("overlay_y", metrics.heightPixels * 2 / 3)
        }
        params = layout
        var startX = 0; var startY = 0
        var touchX = 0f; var touchY = 0f; var dragging = false; var longPressed = false
        val longPress = Runnable { longPressed = true; root.performLongClick() }
        pendingLongPress = longPress
        root.setOnTouchListener { _, event ->
            when (event.actionMasked) {
                MotionEvent.ACTION_DOWN -> {
                    startX = layout.x; startY = layout.y
                    touchX = event.rawX; touchY = event.rawY; dragging = false
                    longPressed = false
                    main.postDelayed(longPress, ViewConfiguration.getLongPressTimeout().toLong())
                    true
                }
                MotionEvent.ACTION_MOVE -> {
                    val dx = event.rawX - touchX; val dy = event.rawY - touchY
                    if (abs(dx) + abs(dy) > dp(6)) { dragging = true; main.removeCallbacks(longPress) }
                    if (dragging) {
                        layout.x = startX + dx.toInt(); layout.y = startY + dy.toInt()
                        clampPosition()
                    }
                    true
                }
                MotionEvent.ACTION_UP -> {
                    main.removeCallbacks(longPress)
                    if (dragging) prefs.edit().putInt("overlay_x", layout.x).putInt("overlay_y", layout.y).apply()
                    else if (!longPressed) current?.let {
                        completed = null; hide(); runtime.openConversation(it.conversationId)
                    }
                    true
                }
                MotionEvent.ACTION_CANCEL -> { main.removeCallbacks(longPress); true }
                else -> false
            }
        }
        windowManager.addView(root, layout)
        view = root
        iconKey = ""
    }

    private fun updateIcon() {
        val container = icon ?: return
        val kind = runtime.setting("overlayIconKind") as? String ?: "app"
        val value = runtime.setting("overlayIconValue") as? String ?: ""
        val key = "$kind:$value"
        if (iconKey == key) return
        iconKey = key
        container.removeAllViews()
        val scale = geometry.badge / appearance.badgeSize
        val imageSize = dp(appearance.iconSize * scale)
        if (kind == "emoji") {
            container.addView(TextView(context).apply {
                text = value; setTextSize(TypedValue.COMPLEX_UNIT_PX, imageSize * .85f)
                includeFontPadding = false; gravity = Gravity.CENTER
            }, FrameLayout.LayoutParams(imageSize, imageSize, Gravity.CENTER))
        } else {
            val image = ImageView(context).apply {
                scaleType = ImageView.ScaleType.CENTER_CROP
                background = GradientDrawable().apply { shape = GradientDrawable.OVAL; setColor(Color.TRANSPARENT) }
                clipToOutline = true
                setImageResource(R.mipmap.ic_launcher)
            }
            if (kind == "image") {
                val file = File(value)
                val root = File(context.filesDir, "background-icons").canonicalFile
                if (file.isFile && file.canonicalFile.parentFile == root && file.length() <= 1024 * 1024) {
                    val dimensions = BitmapFactory.Options().apply { inJustDecodeBounds = true }
                    BitmapFactory.decodeFile(value, dimensions)
                    if (dimensions.outWidth in 1..512 && dimensions.outHeight in 1..512) {
                        BitmapFactory.decodeFile(value)?.let(image::setImageBitmap)
                    }
                }
            }
            container.addView(image, FrameLayout.LayoutParams(imageSize, imageSize, Gravity.CENTER))
        }
        spinner = OverlayProgressRing(context, dp(appearance.progressStrokeWidth * scale).coerceAtLeast(1).toFloat()).apply {
            tag = "progress"
            visibility = if (appearance.showProgress && current?.outcome.isNullOrEmpty()) View.VISIBLE else View.GONE
        }
        val ringSize = dp(appearance.progressSize * scale)
        container.addView(spinner, FrameLayout.LayoutParams(ringSize, ringSize, Gravity.CENTER))
    }

    private fun clampPosition() {
        val layout = params ?: return
        val root = view ?: return
        val metrics = context.resources.displayMetrics
        layout.x = layout.x.coerceIn(0, (metrics.widthPixels - layout.width).coerceAtLeast(0))
        layout.y = layout.y.coerceIn(dp(24), (metrics.heightPixels - layout.height).coerceAtLeast(dp(24)))
        try { windowManager.updateViewLayout(root, layout) } catch (_: IllegalArgumentException) { hide() }
    }

    private fun hide() {
        pendingLongPress?.let(main::removeCallbacks)
        pendingLongPress = null
        clock?.stop()
        view?.let { try { windowManager.removeView(it) } catch (_: IllegalArgumentException) {} }
        view = null; params = null; title = null; detail = null; clock = null; icon = null; spinner = null
    }
}

/** An indeterminate arc with a real, configurable stroke, unlike the themed
 * platform ProgressBar whose ring thickness is fixed by its drawable. */
private class OverlayProgressRing(context: Context, private val stroke: Float) : View(context) {
    private val paint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        style = Paint.Style.STROKE; strokeWidth = stroke; strokeCap = Paint.Cap.ROUND
        color = Color.rgb(0, 137, 153)
    }
    private var animator: ObjectAnimator? = null
    override fun onDraw(canvas: Canvas) {
        val inset = stroke / 2
        canvas.drawArc(inset, inset, width - inset, height - inset, -90f, 270f, false, paint)
    }
    override fun onAttachedToWindow() { super.onAttachedToWindow(); updateAnimation() }
    override fun onVisibilityChanged(changedView: View, visibility: Int) {
        super.onVisibilityChanged(changedView, visibility); updateAnimation()
    }
    override fun onDetachedFromWindow() { animator?.cancel(); animator = null; super.onDetachedFromWindow() }
    private fun updateAnimation() {
        if (!isAttachedToWindow || visibility != VISIBLE) {
            animator?.cancel(); animator = null; return
        }
        if (animator != null) return
        animator = ObjectAnimator.ofFloat(this, ROTATION, 0f, 360f).apply {
            duration = 1100; repeatCount = ValueAnimator.INFINITE
            interpolator = LinearInterpolator(); start()
        }
    }
}
