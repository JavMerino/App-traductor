package com.audiotraductor.audio_traductor

import android.media.AudioAttributes
import android.media.AudioFormat
import android.media.AudioManager
import android.media.AudioTrack
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private var audioTrack: AudioTrack? = null
    private val minBufferSize = AudioTrack.getMinBufferSize(
        16000,
        AudioFormat.CHANNEL_OUT_MONO,
        AudioFormat.ENCODING_PCM_16BIT
    )

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "com.audiotraductor/passthrough"
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "start" -> {
                    startAudioTrack()
                    result.success(true)
                }
                "write" -> {
                    val bytes = call.argument<ByteArray>("bytes")
                    if (bytes != null) {
                        writeAudio(bytes)
                    }
                    result.success(true)
                }
                "stop" -> {
                    stopAudioTrack()
                    result.success(true)
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun startAudioTrack() {
        stopAudioTrack()
        val bufferSize = maxOf(minBufferSize, 6400)
        audioTrack = AudioTrack.Builder()
            .setAudioAttributes(
                AudioAttributes.Builder()
                    .setUsage(AudioAttributes.USAGE_VOICE_COMMUNICATION)
                    .setContentType(AudioAttributes.CONTENT_TYPE_SPEECH)
                    .build()
            )
            .setAudioFormat(
                AudioFormat.Builder()
                    .setSampleRate(16000)
                    .setChannelMask(AudioFormat.CHANNEL_OUT_MONO)
                    .setEncoding(AudioFormat.ENCODING_PCM_16BIT)
                    .build()
            )
            .setBufferSizeInBytes(bufferSize)
            .setTransferMode(AudioTrack.MODE_STREAM)
            .build()
        audioTrack?.play()
    }

    private fun writeAudio(bytes: ByteArray) {
        audioTrack?.write(bytes, 0, bytes.size)
    }

    private fun stopAudioTrack() {
        audioTrack?.stop()
        audioTrack?.release()
        audioTrack = null
    }

    override fun onDestroy() {
        stopAudioTrack()
        super.onDestroy()
    }
}
