package com.example.medsync_app

import android.content.ContentValues
import android.os.Build
import android.os.Environment
import android.provider.MediaStore
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

    private companion object {
        const val CHANNEL =
            "com.example.medsync_app/report"
        const val SAVE_REPORT_METHOD =
            "savePdfToDownloads"
    }

    override fun configureFlutterEngine(
        flutterEngine: FlutterEngine
    ) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            CHANNEL
        ).setMethodCallHandler { call, result ->

            when (call.method) {
                SAVE_REPORT_METHOD -> {
                    val fileName =
                        call.argument<String>("fileName")

                    val bytes =
                        call.argument<ByteArray>("bytes")

                    if (fileName.isNullOrBlank()) {
                        result.error(
                            "INVALID_FILE_NAME",
                            "A valid PDF file name is required.",
                            null
                        )
                        return@setMethodCallHandler
                    }

                    if (bytes == null || bytes.isEmpty()) {
                        result.error(
                            "INVALID_PDF",
                            "The PDF data is empty.",
                            null
                        )
                        return@setMethodCallHandler
                    }

                    try {
                        val uri = savePdfToDownloads(
                            fileName,
                            bytes
                        )

                        if (uri != null) {
                            result.success(uri.toString())
                        } else {
                            result.error(
                                "SAVE_FAILED",
                                "Android could not create the PDF file.",
                                null
                            )
                        }
                    } catch (error: Exception) {
                        result.error(
                            "SAVE_EXCEPTION",
                            error.message,
                            null
                        )
                    }
                }

                else -> {
                    result.notImplemented()
                }
            }
        }
    }

    private fun savePdfToDownloads(
        fileName: String,
        bytes: ByteArray
    ): android.net.Uri? {

        if (Build.VERSION.SDK_INT >=
            Build.VERSION_CODES.Q
        ) {
            val resolver = contentResolver

            val values = ContentValues().apply {
                put(
                    MediaStore.Downloads.DISPLAY_NAME,
                    fileName
                )
                put(
                    MediaStore.Downloads.MIME_TYPE,
                    "application/pdf"
                )
                put(
                    MediaStore.Downloads.RELATIVE_PATH,
                    Environment.DIRECTORY_DOWNLOADS +
                        "/MedSync"
                )
                put(
                    MediaStore.Downloads.IS_PENDING,
                    1
                )
            }

            val uri = resolver.insert(
                MediaStore.Downloads.EXTERNAL_CONTENT_URI,
                values
            ) ?: return null

            try {
                resolver.openOutputStream(uri)
                    ?.use { output ->
                        output.write(bytes)
                        output.flush()
                    }
                    ?: throw IllegalStateException(
                        "Unable to open the PDF output stream."
                    )

                val completedValues =
                    ContentValues().apply {
                        put(
                            MediaStore.Downloads.IS_PENDING,
                            0
                        )
                    }

                resolver.update(
                    uri,
                    completedValues,
                    null,
                    null
                )

                return uri
            } catch (error: Exception) {
                resolver.delete(
                    uri,
                    null,
                    null
                )
                throw error
            }
        }

        throw UnsupportedOperationException(
            "Saving directly to Downloads requires Android 10 or newer."
        )
    }
}