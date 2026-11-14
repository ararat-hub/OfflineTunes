package com.example.offlinetunes

import android.graphics.Bitmap
import android.media.MediaMetadataRetriever
import android.os.Build
import com.ryanheise.audioservice.AudioServiceActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.StandardMethodCodec
import java.io.ByteArrayOutputStream

class MainActivity : AudioServiceActivity() {
    override fun configureFlutterEngine(engine: FlutterEngine) {
        super.configureFlutterEngine(engine)
        val messenger = engine.dartExecutor.binaryMessenger
        MethodChannel(
            messenger, "otune/background_thumbnail", StandardMethodCodec.INSTANCE,
            messenger.makeBackgroundTaskQueue()
        ).setMethodCallHandler { call, result ->
            if (call.method != "frame") {
                result.notImplemented()
            } else {
                result.success((call.arguments as? String)?.let(::videoFrame))
            }
        }
    }

    private fun videoFrame(path: String): ByteArray? {
        val media = MediaMetadataRetriever()
        return try {
            media.setDataSource(path)
            val option = MediaMetadataRetriever.OPTION_CLOSEST_SYNC
            val frame = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O_MR1) {
                media.getScaledFrameAtTime(-1, option, 256, 144)
            } else {
                media.getFrameAtTime(-1, option)
            } ?: return null
            try {
                val bytes = ByteArrayOutputStream()
                if (frame.compress(Bitmap.CompressFormat.JPEG, 78, bytes)) {
                    bytes.toByteArray()
                } else {
                    null
                }
            } finally {
                frame.recycle()
            }
        } catch (_: Exception) {
            null
        } finally {
            media.release()
        }
    }
}
