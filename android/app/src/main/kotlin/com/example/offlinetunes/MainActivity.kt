package com.example.offlinetunes

import android.app.PictureInPictureParams
import android.content.pm.PackageManager
import android.content.res.Configuration
import android.graphics.Bitmap
import android.media.MediaMetadataRetriever
import android.os.Build
import android.util.Rational
import com.ryanheise.audioservice.AudioServiceActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.StandardMethodCodec
import java.io.ByteArrayOutputStream

class MainActivity : AudioServiceActivity() {
    private var compactChannel: MethodChannel? = null
    private var compactOnLeave = false

    override fun configureFlutterEngine(engine: FlutterEngine) {
        super.configureFlutterEngine(engine)
        val messenger = engine.dartExecutor.binaryMessenger
        compactChannel = MethodChannel(messenger, "otune/compact_window").apply {
            setMethodCallHandler { call, result ->
                when (call.method) {
                    "state" -> result.success(Build.VERSION.SDK_INT >= 26 && isInPictureInPictureMode)
                    "configure" -> {
                        compactOnLeave = call.arguments == true
                        configurePictureInPicture()
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }
        }
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

    private fun supportsPictureInPicture() = Build.VERSION.SDK_INT >= 26 &&
        packageManager.hasSystemFeature(PackageManager.FEATURE_PICTURE_IN_PICTURE)

    private fun configurePictureInPicture() {
        if (!supportsPictureInPicture() || Build.VERSION.SDK_INT < 31) return
        setPictureInPictureParams(PictureInPictureParams.Builder()
            .setAspectRatio(Rational(3, 2))
            .setAutoEnterEnabled(compactOnLeave)
            .setSeamlessResizeEnabled(false)
            .build())
    }

    override fun onUserLeaveHint() {
        super.onUserLeaveHint()
        if (Build.VERSION.SDK_INT in 26..30 && compactOnLeave && supportsPictureInPicture()) {
            enterPictureInPictureMode(PictureInPictureParams.Builder()
                .setAspectRatio(Rational(3, 2)).build())
        }
    }

    override fun onPictureInPictureModeChanged(inPictureInPicture: Boolean, configuration: Configuration) {
        super.onPictureInPictureModeChanged(inPictureInPicture, configuration)
        compactChannel?.invokeMethod("changed", inPictureInPicture)
    }

    override fun cleanUpFlutterEngine(engine: FlutterEngine) {
        compactChannel?.setMethodCallHandler(null)
        compactChannel = null
        super.cleanUpFlutterEngine(engine)
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
