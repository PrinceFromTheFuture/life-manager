package com.amirw.shopping_list

import android.app.Activity
import android.content.ContentUris
import android.content.ContentValues
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.os.Environment
import android.provider.MediaStore
import androidx.annotation.RequiresApi
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.IOException
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
                "saveSharedCopy" -> {
                    val name = call.argument<String>("name")
                    val bytes = call.argument<ByteArray>("bytes")
                    when {
                        name == null || bytes == null ->
                            result.error("args", "name and bytes are required.", null)
                        !sharedCopiesSupported() ->
                            result.error("unsupported", "Needs Android 10 or newer.", null)
                        else -> try {
                            result.success(saveSharedCopy(name, bytes))
                        } catch (e: Exception) {
                            result.error("write", e.message, null)
                        }
                    }
                }
                "listSharedCopies" -> {
                    if (!sharedCopiesSupported()) {
                        result.error("unsupported", "Needs Android 10 or newer.", null)
                    } else {
                        try {
                            result.success(listSharedCopies())
                        } catch (e: Exception) {
                            result.error("list", e.message, null)
                        }
                    }
                }
                "readSharedCopy" -> {
                    val id = call.argument<String>("id")
                    if (id == null) {
                        result.error("args", "id is required.", null)
                    } else {
                        try {
                            result.success(readSharedCopy(id))
                        } catch (e: Exception) {
                            result.error("read", e.message, null)
                        }
                    }
                }
                "deleteSharedCopy" -> {
                    val id = call.argument<String>("id")
                    if (id == null) {
                        result.error("args", "id is required.", null)
                    } else {
                        try {
                            result.success(deleteSharedCopy(id))
                        } catch (e: Exception) {
                            result.error("delete", e.message, null)
                        }
                    }
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

    /// MediaStore's Downloads collection is API 29. Below that the app keeps
    /// its copies in its own folder, which is what the Dart side falls back to.
    private fun sharedCopiesSupported(): Boolean =
        Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q

    /// Writes one copy into `Download/Spindle`.
    ///
    /// Deliberately not the app's own directory: files there are deleted with
    /// the app, so an uninstall — or an installer that replaces rather than
    /// updates — takes every copy with it. A file published through MediaStore
    /// stays on the phone.
    @RequiresApi(Build.VERSION_CODES.Q)
    private fun saveSharedCopy(name: String, bytes: ByteArray): String {
        val pending = ContentValues().apply {
            put(MediaStore.MediaColumns.DISPLAY_NAME, name)
            put(MediaStore.MediaColumns.MIME_TYPE, "application/zip")
            put(MediaStore.MediaColumns.RELATIVE_PATH, SHARED_COPIES_PATH)
            // Hidden from other apps until the bytes are all there, so a
            // half-written zip is never offered as a restore candidate.
            put(MediaStore.MediaColumns.IS_PENDING, 1)
        }
        val uri = contentResolver.insert(MediaStore.Downloads.EXTERNAL_CONTENT_URI, pending)
            ?: throw IOException("Downloads would not take $name.")
        contentResolver.openOutputStream(uri)?.use { it.write(bytes) }
            ?: throw IOException("Could not open $name for writing.")
        contentResolver.update(
            uri,
            ContentValues().apply { put(MediaStore.MediaColumns.IS_PENDING, 0) },
            null,
            null,
        )
        return uri.toString()
    }

    /// Newest first.
    @RequiresApi(Build.VERSION_CODES.Q)
    private fun listSharedCopies(): List<Map<String, Any>> {
        val copies = mutableListOf<Map<String, Any>>()
        contentResolver.query(
            MediaStore.Downloads.EXTERNAL_CONTENT_URI,
            arrayOf(
                MediaStore.MediaColumns._ID,
                MediaStore.MediaColumns.DISPLAY_NAME,
                MediaStore.MediaColumns.DATE_MODIFIED,
            ),
            "${MediaStore.MediaColumns.RELATIVE_PATH} LIKE ?",
            arrayOf("$SHARED_COPIES_PATH%"),
            "${MediaStore.MediaColumns.DATE_MODIFIED} DESC",
        )?.use { cursor ->
            val idColumn = cursor.getColumnIndexOrThrow(MediaStore.MediaColumns._ID)
            val nameColumn = cursor.getColumnIndexOrThrow(MediaStore.MediaColumns.DISPLAY_NAME)
            val atColumn = cursor.getColumnIndexOrThrow(MediaStore.MediaColumns.DATE_MODIFIED)
            while (cursor.moveToNext()) {
                val name = cursor.getString(nameColumn) ?: continue
                if (!name.endsWith(".zip")) continue
                val uri = ContentUris.withAppendedId(
                    MediaStore.Downloads.EXTERNAL_CONTENT_URI,
                    cursor.getLong(idColumn),
                )
                copies.add(
                    mapOf(
                        "id" to uri.toString(),
                        "name" to name,
                        "at" to cursor.getLong(atColumn) * 1000L,
                    ),
                )
            }
        }
        return copies
    }

    private fun readSharedCopy(id: String): ByteArray =
        contentResolver.openInputStream(Uri.parse(id))?.use { it.readBytes() }
            ?: throw IOException("That copy could not be read.")

    private fun deleteSharedCopy(id: String): Boolean =
        contentResolver.delete(Uri.parse(id), null, null) > 0

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

        /// Visible in Files under Downloads, and outside the app sandbox.
        private val SHARED_COPIES_PATH = "${Environment.DIRECTORY_DOWNLOADS}/Spindle"
    }
}
