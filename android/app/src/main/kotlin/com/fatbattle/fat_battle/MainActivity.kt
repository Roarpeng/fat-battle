package com.fatbattle.fat_battle

import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.ImageFormat
import android.graphics.Matrix
import android.graphics.Rect
import android.graphics.YuvImage
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.ByteArrayOutputStream

/**
 * NV21 → JPEG。可选按 rotation 顺时针摆正，使 ML Kit 关键点与 CameraPreview 同向。
 */
class MainActivity : FlutterActivity() {
    private val channelName = "fat_battle/mlkit_frame"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "nv21ToJpeg", "nv21ToUprightJpeg" -> {
                        try {
                            val nv21 = call.argument<ByteArray>("nv21")
                                ?: throw IllegalArgumentException("nv21 missing")
                            val width = call.argument<Int>("width")
                                ?: throw IllegalArgumentException("width missing")
                            val height = call.argument<Int>("height")
                                ?: throw IllegalArgumentException("height missing")
                            val rotation = call.argument<Int>("rotation") ?: 0
                            val quality = call.argument<Int>("quality") ?: 80
                            result.success(
                                nv21ToJpeg(nv21, width, height, rotation, quality),
                            )
                        } catch (e: Exception) {
                            result.error("YUV_JPEG", e.message, null)
                        }
                    }
                    else -> result.notImplemented()
                }
            }
    }

    private fun nv21ToJpeg(
        nv21: ByteArray,
        width: Int,
        height: Int,
        rotation: Int,
        quality: Int,
    ): ByteArray {
        val yuv = YuvImage(nv21, ImageFormat.NV21, width, height, null)
        val rawJpeg = ByteArrayOutputStream()
        if (!yuv.compressToJpeg(Rect(0, 0, width, height), quality, rawJpeg)) {
            throw IllegalStateException("YuvImage.compressToJpeg failed")
        }
        if (rotation % 360 == 0) {
            return rawJpeg.toByteArray()
        }

        var bitmap = BitmapFactory.decodeByteArray(
            rawJpeg.toByteArray(),
            0,
            rawJpeg.size(),
        ) ?: throw IllegalStateException("BitmapFactory.decodeByteArray failed")

        val matrix = Matrix()
        matrix.postRotate(rotation.toFloat())
        val rotated = Bitmap.createBitmap(
            bitmap,
            0,
            0,
            bitmap.width,
            bitmap.height,
            matrix,
            true,
        )
        if (rotated != bitmap) {
            bitmap.recycle()
            bitmap = rotated
        }

        val out = ByteArrayOutputStream()
        if (!bitmap.compress(Bitmap.CompressFormat.JPEG, quality, out)) {
            bitmap.recycle()
            throw IllegalStateException("Bitmap.compress failed")
        }
        bitmap.recycle()
        return out.toByteArray()
    }
}
