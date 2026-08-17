package com.amirw.shopping_list

import android.app.Activity
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.security.MessageDigest

class MainActivity : FlutterActivity() {
    private var pickResult: MethodChannel.Result? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "spindle/android",
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "signingCertSha1" -> {
                    try {
                        result.success(signingCertSha1())
                    } catch (e: Exception) {
                        result.error("sha1", e.message, null)
                    }
                }
                "pickBackupZip" -> {
                    if (pickResult != null) {
                        result.error("busy", "A file picker is already open.", null)
                        return@setMethodCallHandler
                    }
                    pickResult = result
                    val intent = Intent(Intent.ACTION_OPEN_DOCUMENT).apply {
                        addCategory(Intent.CATEGORY_OPENABLE)
                        type = "application/zip"
                        putExtra(
                            Intent.EXTRA_MIME_TYPES,
                            arrayOf(
                                "application/zip",
                                "application/x-zip-compressed",
                                "application/octet-stream",
                            ),
                        )
                    }
                    startActivityForResult(intent, PICK_BACKUP)
                }
                else -> result.notImplemented()
            }
        }
    }

    @Deprecated("Deprecated in Java")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        if (requestCode != PICK_BACKUP) {
            @Suppress("DEPRECATION")
            super.onActivityResult(requestCode, resultCode, data)
            return
        }
        val pending = pickResult
        pickResult = null
        if (pending == null) return
        if (resultCode != Activity.RESULT_OK || data?.data == null) {
            pending.success(null)
            return
        }
        try {
            val dest = File(cacheDir, "restore_backup.zip")
            contentResolver.openInputStream(data.data!!).use { input ->
                if (input == null) {
                    pending.error("read", "Could not read that file.", null)
                    return
                }
                dest.outputStream().use { output -> input.copyTo(output) }
            }
            pending.success(dest.absolutePath)
        } catch (e: Exception) {
            pending.error("read", e.message, null)
        }
    }

    /// Hex SHA-1 of the signing cert, no colons — the form Google's
    /// restricted API keys expect in `X-Android-Cert`.
    private fun signingCertSha1(): String {
        val signature = if (Build.VERSION.SDK_INT >= 28) {
            val info = packageManager.getPackageInfo(
                packageName,
                PackageManager.GET_SIGNING_CERTIFICATES,
            )
            info.signingInfo!!.apkContentsSigners[0]
        } else {
            @Suppress("DEPRECATION")
            val info = packageManager.getPackageInfo(
                packageName,
                PackageManager.GET_SIGNATURES,
            )
            @Suppress("DEPRECATION")
            info.signatures!![0]
        }
        val digest = MessageDigest.getInstance("SHA1").digest(signature.toByteArray())
        return digest.joinToString("") { b -> "%02X".format(b) }
    }

    companion object {
        private const val PICK_BACKUP = 7102
    }
}
