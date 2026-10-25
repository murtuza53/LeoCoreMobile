package sek.leocore.erp

import android.content.ActivityNotFoundException
import android.content.ContentValues
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.Environment
import android.provider.MediaStore
import androidx.core.content.FileProvider
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

/** FlutterFragmentActivity is required by local_auth's BiometricPrompt. */
class MainActivity : FlutterFragmentActivity() {

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "leocore/downloads")
            .setMethodCallHandler { call, result ->
                try {
                    when (call.method) {
                        "save" -> {
                            val bytes = call.argument<ByteArray>("bytes")!!
                            val name = call.argument<String>("name")!!
                            val mime = call.argument<String>("mime") ?: "application/pdf"
                            result.success(saveToDownloads(bytes, name, mime))
                        }
                        "open" -> {
                            val uri = call.argument<String>("uri")!!
                            val mime = call.argument<String>("mime") ?: "application/pdf"
                            result.success(openInDefaultApp(uri, mime))
                        }
                        "share" -> {
                            val uri = call.argument<String>("uri")!!
                            val mime = call.argument<String>("mime") ?: "application/pdf"
                            shareFile(uri, mime, call.argument<String>("subject"))
                            result.success("done")
                        }
                        else -> result.notImplemented()
                    }
                } catch (e: Exception) {
                    result.error("downloads", e.message ?: e.toString(), null)
                }
            }
    }

    /**
     * Writes [bytes] to the public Downloads folder and returns a URI string
     * other apps can read. Android 10+ uses MediaStore (no permission needed);
     * older versions write the file directly (WRITE_EXTERNAL_STORAGE ≤ API 28).
     */
    private fun saveToDownloads(bytes: ByteArray, name: String, mime: String): String {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            val resolver = contentResolver
            val collection = MediaStore.Downloads.EXTERNAL_CONTENT_URI
            // Replace a previous copy we saved under the same name instead of
            // piling up "statement (1).pdf", "statement (2).pdf", …
            resolver.delete(
                collection,
                "${MediaStore.MediaColumns.DISPLAY_NAME}=? AND ${MediaStore.MediaColumns.RELATIVE_PATH}=?",
                arrayOf(name, Environment.DIRECTORY_DOWNLOADS + "/")
            )
            val values = ContentValues().apply {
                put(MediaStore.MediaColumns.DISPLAY_NAME, name)
                put(MediaStore.MediaColumns.MIME_TYPE, mime)
                put(MediaStore.MediaColumns.RELATIVE_PATH, Environment.DIRECTORY_DOWNLOADS)
                put(MediaStore.MediaColumns.IS_PENDING, 1)
            }
            val uri = resolver.insert(collection, values)
                ?: throw IllegalStateException("Could not create the file in Downloads")
            resolver.openOutputStream(uri, "w").use { out ->
                (out ?: throw IllegalStateException("Could not write to Downloads")).write(bytes)
            }
            values.clear()
            values.put(MediaStore.MediaColumns.IS_PENDING, 0)
            resolver.update(uri, values, null, null)
            return uri.toString()
        }
        @Suppress("DEPRECATION")
        val dir = Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_DOWNLOADS)
        val target = try {
            dir.mkdirs()
            File(dir, name).apply { writeBytes(bytes) }
        } catch (e: Exception) {
            // Storage permission not granted — keep it in the app's own
            // external Downloads folder, which needs no permission.
            File(getExternalFilesDir(Environment.DIRECTORY_DOWNLOADS), name).apply { writeBytes(bytes) }
        }
        return FileProvider.getUriForFile(this, "$packageName.fileProvider.com.crazecoder.openfile", target).toString()
    }

    /** Opens the system share sheet for the saved file at [uri]. */
    private fun shareFile(uri: String, mime: String, subject: String?) {
        val send = Intent(Intent.ACTION_SEND).apply {
            type = mime
            putExtra(Intent.EXTRA_STREAM, Uri.parse(uri))
            if (subject != null) putExtra(Intent.EXTRA_SUBJECT, subject)
            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
        }
        startActivity(Intent.createChooser(send, null).addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION))
    }

    /** Opens [uri] in the app the user has set as default for [mime]. */
    private fun openInDefaultApp(uri: String, mime: String): String {
        val intent = Intent(Intent.ACTION_VIEW).apply {
            setDataAndType(Uri.parse(uri), mime)
            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION or Intent.FLAG_ACTIVITY_NEW_TASK)
        }
        return try {
            startActivity(intent)
            "done"
        } catch (e: ActivityNotFoundException) {
            "noApp"
        }
    }
}
