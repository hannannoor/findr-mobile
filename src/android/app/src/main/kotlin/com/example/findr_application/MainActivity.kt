package com.example.findr_application

import android.content.ActivityNotFoundException
import android.content.Intent
import android.os.Build
import android.provider.Settings
import androidx.biometric.BiometricManager
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterFragmentActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "findr/biometrics",
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "biometricStatus" -> result.success(biometricStatus())

                "openBiometricEnrollment" -> {
                    try {
                        openBiometricEnrollment()
                        result.success(true)
                    } catch (error: Exception) {
                        result.error(
                            "BIOMETRIC_SETTINGS_UNAVAILABLE",
                            "Could not open biometric settings.",
                            error.message,
                        )
                    }
                }

                else -> result.notImplemented()
            }
        }
    }

    /**
     * Reports exactly why biometrics can or cannot be used.
     *
     * local_auth's canCheckBiometrics returns false both when the device has no
     * sensor and when it has one that nobody has enrolled a fingerprint on, so
     * on its own it cannot tell "unsupported" from "not set up yet". Asking
     * BiometricManager directly separates the two, which matters because the
     * two states need opposite things from the user.
     */
    private fun biometricStatus(): String {
        val manager = BiometricManager.from(this)

        return when (manager.canAuthenticate(BiometricManager.Authenticators.BIOMETRIC_WEAK)) {
            BiometricManager.BIOMETRIC_SUCCESS -> "available"

            // A sensor is present but the user has not registered a fingerprint
            // or face yet, so Findr can offer to open the enrolment screen.
            BiometricManager.BIOMETRIC_ERROR_NONE_ENROLLED -> "notEnrolled"

            BiometricManager.BIOMETRIC_ERROR_NO_HARDWARE,
            BiometricManager.BIOMETRIC_ERROR_UNSUPPORTED,
            BiometricManager.BIOMETRIC_ERROR_SECURITY_UPDATE_REQUIRED,
            -> "unsupported"

            // The sensor exists but is busy or disabled for the moment, so
            // trying again shortly is the right advice.
            BiometricManager.BIOMETRIC_ERROR_HW_UNAVAILABLE,
            BiometricManager.BIOMETRIC_STATUS_UNKNOWN,
            -> "temporarilyUnavailable"

            else -> "temporarilyUnavailable"
        }
    }

    private fun openBiometricEnrollment() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            try {
                val enrollmentIntent = Intent(Settings.ACTION_BIOMETRIC_ENROLL).apply {
                    putExtra(
                        Settings.EXTRA_BIOMETRIC_AUTHENTICATORS_ALLOWED,
                        BiometricManager.Authenticators.BIOMETRIC_WEAK,
                    )
                }
                startActivity(enrollmentIntent)
                return
            } catch (_: ActivityNotFoundException) {
                // Some vendor devices do not expose the dedicated enrollment
                // activity, so fall back to the general security page below.
            }
        }

        startActivity(Intent(Settings.ACTION_SECURITY_SETTINGS))
    }
}
