package com.gamespace.core

import android.content.pm.PackageManager
import rikka.shizuku.Shizuku

object ShizukuManager {

    private var isBinderReceived = false

    private val binderReceivedListener = Shizuku.OnBinderReceivedListener {
        isBinderReceived = true
    }

    private val binderDeadListener = Shizuku.OnBinderDeadListener {
        isBinderReceived = false
    }

    fun init() {
        try {
            Shizuku.addBinderReceivedListenerSticky(binderReceivedListener)
            Shizuku.addBinderDeadListener(binderDeadListener)
        } catch (e: Exception) {
            e.printStackTrace()
        }
    }

    fun isShizukuAvailable(): Boolean {
        return try {
            Shizuku.pingBinder()
        } catch (e: Exception) {
            false
        }
    }

    fun hasPermission(): Boolean {
        return if (isShizukuAvailable()) {
            try {
                Shizuku.checkSelfPermission() == PackageManager.PERMISSION_GRANTED
            } catch (e: Exception) {
                false
            }
        } else {
            false
        }
    }

    fun requestPermission(requestCode: Int = 1001) {
        if (isShizukuAvailable() && !hasPermission()) {
            try {
                Shizuku.requestPermission(requestCode)
            } catch (e: Exception) {
                e.printStackTrace()
            }
        }
    }
}
