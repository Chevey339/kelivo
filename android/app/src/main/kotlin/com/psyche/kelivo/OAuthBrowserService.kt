package com.psyche.kelivo

import android.app.Service
import android.content.Intent
import android.os.Binder
import android.os.IBinder

/** A browser-only lifecycle binding; this binder exposes no app data or operations. */
class OAuthBrowserService : Service() {
    private val binder = Binder()

    override fun onBind(intent: Intent?): IBinder = binder
}
