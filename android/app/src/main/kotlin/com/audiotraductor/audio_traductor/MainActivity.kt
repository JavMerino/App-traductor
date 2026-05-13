package com.audiotraductor.audio_traductor

import android.bluetooth.BluetoothAdapter
import android.bluetooth.BluetoothDevice
import android.bluetooth.BluetoothHeadset
import android.bluetooth.BluetoothProfile
import android.content.Context
import android.media.*
import android.os.Build
import android.os.Handler
import android.os.Looper
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private var audioTrack: AudioTrack? = null
    private val minBufferSize = AudioTrack.getMinBufferSize(
        16000,
        AudioFormat.CHANNEL_OUT_MONO,
        AudioFormat.ENCODING_PCM_16BIT
    )

    // AudioRecord nativo para capturar del mic del teléfono
    private var audioRecord: AudioRecord? = null
    private var recordThread: Thread? = null
    private var recordSink: EventChannel.EventSink? = null
    private val recordHandler = Handler(Looper.getMainLooper())

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // ── Canal: forzar mic + captura nativa ──
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "com.audiotraductor/audio"
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "forceBuiltinMic" -> {
                    forceBuiltinMic()
                    result.success(true)
                }
                "startRecording" -> {
                    forceBuiltinMic()
                    startNativeRecording(flutterEngine.dartExecutor.binaryMessenger)
                    result.success(true)
                }
                "stopRecording" -> {
                    stopNativeRecording()
                    result.success(true)
                }
                else -> result.notImplemented()
            }
        }

        // ── Canal de passthrough ──
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "com.audiotraductor/passthrough"
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "start" -> {
                    forceBuiltinMic()
                    startAudioTrack()
                    result.success(true)
                }
                "write" -> {
                    val bytes = call.argument<ByteArray>("bytes")
                    if (bytes != null) writeAudio(bytes)
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

    /// Captura audio nativo con AudioRecord usando VOICE_RECOGNITION
    /// para forzar el micrófono del teléfono en vez del BT.
    private fun startNativeRecording(messenger: BinaryMessenger) {
        stopNativeRecording()

        EventChannel(messenger, "com.audiotraductor/mic").setStreamHandler(
            object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink) {
                    recordSink = events
                    recordThread = Thread {
                        val bufferSize = AudioRecord.getMinBufferSize(
                            16000,
                            AudioFormat.CHANNEL_IN_MONO,
                            AudioFormat.ENCODING_PCM_16BIT
                        )

                        audioRecord = AudioRecord.Builder()
                            .setAudioSource(MediaRecorder.AudioSource.CAMCORDER)
                            .setAudioFormat(
                                AudioFormat.Builder()
                                    .setSampleRate(16000)
                                    .setChannelMask(AudioFormat.CHANNEL_IN_MONO)
                                    .setEncoding(AudioFormat.ENCODING_PCM_16BIT)
                                    .build()
                            )
                            .setBufferSizeInBytes(bufferSize)
                            .build()

                        // API 31+: forzar el mic del teléfono
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                            val preferredDevice = getSystemService(Context.AUDIO_SERVICE)
                                ?.let { (it as AudioManager).availableCommunicationDevices }
                                ?.firstOrNull { it.type == AudioDeviceInfo.TYPE_BUILTIN_MIC }
                            if (preferredDevice != null) {
                                audioRecord?.preferredDevice = preferredDevice
                            }
                        }

                        audioRecord?.startRecording()

                        val buffer = ByteArray(bufferSize)
                        while (!Thread.currentThread().isInterrupted && audioRecord?.recordingState == AudioRecord.RECORDSTATE_RECORDING) {
                            val read = audioRecord?.read(buffer, 0, buffer.size) ?: 0
                            if (read > 0) {
                                val chunk = buffer.copyOf(read)
                                recordHandler.post { recordSink?.success(chunk) }
                            }
                        }
                    }
                    recordThread?.start()
                }

                override fun onCancel(arguments: Any?) {
                    stopNativeRecording()
                }
            }
        )
    }

    private fun stopNativeRecording() {
        recordThread?.interrupt()
        recordThread = null
        audioRecord?.stop()
        audioRecord?.release()
        audioRecord = null
        recordSink = null
    }

    private fun forceBuiltinMic() {
        val audioManager = getSystemService(Context.AUDIO_SERVICE) as AudioManager
        audioManager.isBluetoothScoOn = false
        audioManager.stopBluetoothSco()
        audioManager.mode = AudioManager.MODE_NORMAL
        audioManager.isSpeakerphoneOn = true

        // Forzar parámetros adicionales (Samsung)
        audioManager.setParameters("BT_SCO=off")
        audioManager.setParameters("A2DP_SUSPENDED=true")

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            val builtinMic = audioManager.availableCommunicationDevices
                .firstOrNull { it.type == AudioDeviceInfo.TYPE_BUILTIN_MIC }
            if (builtinMic != null) {
                audioManager.setCommunicationDevice(builtinMic)
            }
        }

        // Desconectar HFP del headset (Samsung) para liberar el micrófono
        disconnectHeadsetHfp()
    }

    /// Desconecta el perfil HFP (manos libres) de todos los headsets BT.
    /// Así el micrófono vuelve al teléfono manteniendo A2DP para salida.
    private fun disconnectHeadsetHfp() {
        try {
            val adapter = BluetoothAdapter.getDefaultAdapter() ?: return
            adapter.getProfileProxy(this, object : BluetoothProfile.ServiceListener {
                override fun onServiceConnected(profile: Int, proxy: BluetoothProfile) {
                    if (profile != BluetoothProfile.HEADSET) return
                    val headset = proxy as BluetoothHeadset
                    val devices = headset.connectedDevices
                    for (device in devices) {
                        try { headset.stopVoiceRecognition(device) } catch (_: Exception) {}
                    }
                    adapter.closeProfileProxy(BluetoothProfile.HEADSET, proxy)
                }
                override fun onServiceDisconnected(profile: Int) {}
            }, BluetoothProfile.HEADSET)
        } catch (_: Exception) {}
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
        stopNativeRecording()
        super.onDestroy()
    }
}
