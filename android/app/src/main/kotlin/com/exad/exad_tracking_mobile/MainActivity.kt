package com.exad.exad_tracking_mobile

import android.content.ActivityNotFoundException
import android.content.Intent
import android.net.Uri
import com.google.android.play.core.appupdate.AppUpdateManagerFactory
import com.google.android.play.core.install.model.UpdateAvailability
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "com.exad.exad_tracking_mobile/updates")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "checkForUpdate" -> {
                        AppUpdateManagerFactory.create(applicationContext).appUpdateInfo
                            .addOnSuccessListener { info ->
                                result.success(mapOf(
                                    "available" to (info.updateAvailability() == UpdateAvailability.UPDATE_AVAILABLE),
                                    "build" to info.availableVersionCode()
                                ))
                            }
                            .addOnFailureListener {
                                result.error("UPDATE_CHECK_FAILED", "Update status unavailable", null)
                            }
                    }
                    "openStore" -> {
                        try {
                            try {
                                startActivity(Intent(Intent.ACTION_VIEW, Uri.parse("market://details?id=$packageName"))
                                    .setPackage("com.android.vending"))
                            } catch (_: ActivityNotFoundException) {
                                startActivity(Intent(Intent.ACTION_VIEW, Uri.parse("https://play.google.com/store/apps/details?id=$packageName")))
                            }
                            result.success(true)
                        } catch (_: Exception) {
                            result.error("STORE_UNAVAILABLE", "Unable to open Play Store", null)
                        }
                    }
                    else -> result.notImplemented()
                }
            }
    }
}
