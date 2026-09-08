package com.psyche.kelivo

import android.Manifest
import android.annotation.SuppressLint
import android.content.Context
import android.content.pm.PackageManager
import android.location.Location
import android.location.LocationManager
import android.os.Build
import android.os.CancellationSignal
import android.os.Handler
import android.os.Looper
import androidx.core.content.ContextCompat
import androidx.core.location.LocationManagerCompat
import io.flutter.plugin.common.MethodChannel
import org.json.JSONObject
import java.time.Instant

/** One-shot system location; no Play Services or background permission required. */
class LocationToolHandler(private val context: Context) {
    private val manager = context.getSystemService(Context.LOCATION_SERVICE) as LocationManager
    private val mainHandler = Handler(Looper.getMainLooper())
    private val cancellations = mutableListOf<CancellationSignal>()
    private var pending: MethodChannel.Result? = null
    private val timeout = Runnable {
        finish(errorPayload("LOCATION_TIMEOUT", "Timed out waiting for a location fix. Please try again."))
    }

    private fun hasPermission(permission: String): Boolean =
        ContextCompat.checkSelfPermission(context, permission) == PackageManager.PERMISSION_GRANTED

    fun hasPermission(): Boolean =
        hasPermission(Manifest.permission.ACCESS_COARSE_LOCATION) ||
            hasPermission(Manifest.permission.ACCESS_FINE_LOCATION)

    @SuppressLint("MissingPermission") // Checked before requesting; revocation is caught below.
    fun getCurrentLocation(result: MethodChannel.Result) {
        if (pending != null) {
            result.success(errorPayload("LOCATION_BUSY", "A location request is already in progress. Please try again."))
            return
        }
        pending = result
        if (!hasPermission()) {
            finish(noPermissionPayload())
            return
        }
        try {
            if (!LocationManagerCompat.isLocationEnabled(manager)) {
                finish(errorPayload("LOCATION_DISABLED", "Location services are turned off on this device."))
                return
            }
            val fine = hasPermission(Manifest.permission.ACCESS_FINE_LOCATION)
            val providers = manager.getProviders(true).filter {
                it == LocationManager.NETWORK_PROVIDER ||
                    (it == LocationManager.GPS_PROVIDER && fine) ||
                    (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S && it == LocationManager.FUSED_PROVIDER)
            }
            if (providers.isEmpty()) {
                finish(unavailablePayload())
                return
            }
            mainHandler.postDelayed(timeout, 20_000)
            var remaining = providers.size
            // Race the available providers so GPS also works on devices without
            // a network location backend. Stop every request after the first fix.
            for (provider in providers) {
                if (pending !== result) break
                val cancellation = CancellationSignal()
                cancellations.add(cancellation)
                try {
                    LocationManagerCompat.getCurrentLocation(
                        manager,
                        provider,
                        cancellation,
                        // Always queue callbacks to avoid reentrancy during registration.
                        { command -> mainHandler.post(command) },
                    ) locationCallback@ { location ->
                        if (pending !== result) return@locationCallback
                        remaining--
                        if (location != null) {
                            finish(buildPayload(location))
                        } else if (remaining == 0) {
                            finish(unavailablePayload())
                        }
                    }
                } catch (e: SecurityException) {
                    throw e
                } catch (_: IllegalArgumentException) {
                    // A provider may disappear between enumeration and registration.
                    remaining--
                    if (remaining == 0) finish(unavailablePayload())
                }
            }
        } catch (_: SecurityException) {
            finish(noPermissionPayload())
        } catch (_: Exception) {
            finish(unavailablePayload())
        }
    }

    fun dispose() {
        finish(errorPayload("LOCATION_UNAVAILABLE", "Location request cancelled because the activity was destroyed."))
    }

    private fun finish(payload: String) {
        val result = pending
        pending = null
        mainHandler.removeCallbacks(timeout)
        cancellations.forEach { it.cancel() }
        cancellations.clear()
        result?.success(payload)
    }

    private fun buildPayload(location: Location): String {
        val payload = JSONObject()
            .put("latitude", location.latitude)
            .put("longitude", location.longitude)
            .put("accuracy_m", if (location.hasAccuracy()) location.accuracy else JSONObject.NULL)
            .put("timestamp", Instant.ofEpochMilli(location.time).toString())
            .put("timestamp_ms", location.time)
        if (location.hasAltitude()) payload.put("altitude_m", location.altitude)
        return payload.toString()
    }

    private fun noPermissionPayload(): String = errorPayload(
        "NO_PERMISSION",
        "Location permission is not granted. Please allow location while using the app in system Settings and try again.",
    )

    private fun unavailablePayload(): String = errorPayload(
        "LOCATION_UNAVAILABLE", "Could not determine the current location.",
    )

    private fun errorPayload(error: String, message: String): String =
        JSONObject().put("error", error).put("message", message).toString()
}
