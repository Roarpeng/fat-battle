package com.fatbattle.fat_battle

import android.content.ComponentName
import android.content.Context
import android.content.pm.PackageManager
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.ImageFormat
import android.graphics.Matrix
import android.graphics.Rect
import android.graphics.YuvImage
import android.media.AudioDeviceInfo
import android.media.AudioManager
import android.os.Build
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.ByteArrayOutputStream

/**
 * NV21 → JPEG。可选按 rotation 顺时针摆正，使 ML Kit 关键点与 CameraPreview 同向。
 * 另：教练语音输出路由（有耳机走耳机，无耳机外放）。
 */
class MainActivity : FlutterActivity() {
    private val mlkitChannelName = "fat_battle/mlkit_frame"
    private val audioChannelName = "fat_battle/audio_route"
    private val sculptChannelName = "fat_battle/sculpt_icon"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, mlkitChannelName)
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

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, audioChannelName)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "isHeadsetConnected" -> result.success(isHeadsetConnected())
                    "prepareCoachPlayback" -> {
                        try {
                            result.success(prepareCoachPlayback())
                        } catch (e: Exception) {
                            result.error("AUDIO_ROUTE", e.message, null)
                        }
                    }
                    "restorePlayback" -> {
                        try {
                            restorePlayback()
                            result.success(null)
                        } catch (e: Exception) {
                            result.error("AUDIO_ROUTE", e.message, null)
                        }
                    }
                    else -> result.notImplemented()
                }
            }

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, sculptChannelName)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "setSculptStage" -> {
                        val parsed = parseSculptArgs(call.arguments)
                        if (parsed == null) {
                            result.error("SCULPT", "stage missing", null)
                            return@setMethodCallHandler
                        }
                        try {
                            setSculptIcon(parsed.first, parsed.second)
                            result.success(null)
                        } catch (e: Exception) {
                            result.error("SCULPT", e.message, null)
                        }
                    }
                    else -> result.notImplemented()
                }
            }
    }

    /**
     * 启用对应雕刻阶段+雕塑线的 activity-alias，关闭其余。
     * 部分启动器会缓存图标，需长按主屏或重启后才刷新。
     */
    private fun parseSculptArgs(args: Any?): Pair<Int, String>? {
        when (args) {
            is Int -> return Pair(args, "venus")
            is Number -> return Pair(args.toInt(), "venus")
            is Map<*, *> -> {
                val stage = (args["stage"] as? Number)?.toInt() ?: return null
                val line = (args["line"] as? String) ?: "venus"
                return Pair(stage, line)
            }
        }
        return null
    }

    private fun setSculptIcon(stage: Int, line: String) {
        val next = stage.coerceIn(0, 7)
        val lineName = if (line == "david") "David" else "Venus"
        val target = "$packageName.Sculpt$lineName$next"
        val pm = packageManager
        pm.setComponentEnabledSetting(
            ComponentName(this, target),
            PackageManager.COMPONENT_ENABLED_STATE_ENABLED,
            PackageManager.DONT_KILL_APP,
        )
        for (ln in arrayOf("Venus", "David")) {
            for (i in 0..7) {
                val name = "$packageName.Sculpt$ln$i"
                if (name == target) continue
                pm.setComponentEnabledSetting(
                    ComponentName(this, name),
                    PackageManager.COMPONENT_ENABLED_STATE_DISABLED,
                    PackageManager.DONT_KILL_APP,
                )
            }
        }
    }

    private fun audioManager(): AudioManager =
        getSystemService(Context.AUDIO_SERVICE) as AudioManager

    private fun isHeadsetConnected(): Boolean {
        val am = audioManager()
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            val devices = am.getDevices(AudioManager.GET_DEVICES_OUTPUTS)
            return devices.any { device ->
                when (device.type) {
                    AudioDeviceInfo.TYPE_WIRED_HEADSET,
                    AudioDeviceInfo.TYPE_WIRED_HEADPHONES,
                    AudioDeviceInfo.TYPE_BLUETOOTH_A2DP,
                    AudioDeviceInfo.TYPE_BLUETOOTH_SCO,
                    AudioDeviceInfo.TYPE_BLE_HEADSET,
                    AudioDeviceInfo.TYPE_USB_HEADSET,
                    -> true
                    else -> false
                }
            }
        }
        @Suppress("DEPRECATION")
        return am.isWiredHeadsetOn || am.isBluetoothA2dpOn || am.isBluetoothScoOn
    }

    /**
     * @return map: headsetConnected, routedTo ("headset"|"speaker")
     */
    private fun prepareCoachPlayback(): Map<String, Any> {
        val am = audioManager()
        val headset = isHeadsetConnected()
        am.mode = AudioManager.MODE_NORMAL
        if (headset) {
            @Suppress("DEPRECATION")
            am.isSpeakerphoneOn = false
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                // 有耳机时清掉强制扬声器，交给系统路由到耳机
                am.clearCommunicationDevice()
            }
            return mapOf(
                "headsetConnected" to true,
                "routedTo" to "headset",
            )
        }

        // 无耳机：强制外放，远场才听得见（避免走听筒）
        @Suppress("DEPRECATION")
        am.isSpeakerphoneOn = true
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            val speaker = am.availableCommunicationDevices.firstOrNull {
                it.type == AudioDeviceInfo.TYPE_BUILTIN_SPEAKER
            }
            if (speaker != null) {
                am.setCommunicationDevice(speaker)
            }
        }
        return mapOf(
            "headsetConnected" to false,
            "routedTo" to "speaker",
        )
    }

    private fun restorePlayback() {
        val am = audioManager()
        @Suppress("DEPRECATION")
        am.isSpeakerphoneOn = false
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            am.clearCommunicationDevice()
        }
        am.mode = AudioManager.MODE_NORMAL
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
