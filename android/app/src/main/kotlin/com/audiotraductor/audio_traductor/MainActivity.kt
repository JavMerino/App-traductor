package com.audiotraductor.audio_traductor

import android.bluetooth.BluetoothA2dp
import android.bluetooth.BluetoothAdapter
import android.bluetooth.BluetoothDevice
import android.bluetooth.BluetoothHeadset
import android.bluetooth.BluetoothProfile
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.content.pm.PackageManager
import android.media.*
import android.os.Build
import android.os.Handler
import android.os.Looper
import java.util.concurrent.atomic.AtomicBoolean
import java.util.concurrent.atomic.AtomicInteger
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
    private val mainHandler = Handler(Looper.getMainLooper())
    private var btReceiverRegistered = false
    private var lastCommDevice: AudioDeviceInfo? = null
    private var selectedOutputAddress: String? = null
    private var selectedOutputName: String? = null
    private val btStateReceiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context?, intent: Intent?) {
            try {
                forceBuiltinMic()
                enforceBuiltinMicOnActiveRecording()
            } catch (_: Exception) {}
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        registerBluetoothStateReceiver()

        // ── Canal: forzar mic + captura nativa ──
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "com.audiotraductor/audio"
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "forceBuiltinMic" -> {
                    try {
                        saveCurrentCommDevice()
                        clearCommDevice()
                        forceBuiltinMic()
                    } catch (_: Exception) {}
                    result.success(true)
                }
                "restoreOutput" -> {
                    try { restoreOutput() } catch (_: Exception) {}
                    result.success(true)
                }
                "selectOutput" -> {
                    try {
                        val name = call.argument<String>("name") ?: ""
                        val id = call.argument<String>("id") ?: ""
                        val type = call.argument<String>("type") ?: ""
                        selectOutputDevice(name, id, type)
                    } catch (_: Exception) {}
                    result.success(true)
                }
                "startRecording" -> {
                    startNativeRecording(flutterEngine.dartExecutor.binaryMessenger)
                    result.success(true)
                }
                "stopRecording" -> {
                    stopNativeRecording()
                    result.success(true)
                }
                "getBondedDevices" -> {
                    getBluetoothAudioDevices(result)
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
    private fun selectOutputDevice(name: String, id: String, type: String) {
        val audioManager = getSystemService(Context.AUDIO_SERVICE) as AudioManager
        val normalizedName = name.trim().lowercase()
        val normalizedId = id.trim().lowercase()
        val normalizedType = type.trim().lowercase()
        val addressFromId = extractAddressFromId(normalizedId)
        val isBuiltinOutput = normalizedType == "integrado" ||
            normalizedType == "builtin" ||
            normalizedId == "builtin-speaker" ||
            normalizedName == "builtin-speaker" ||
            addressFromId.isEmpty() && !normalizedType.contains("bluetooth") && !normalizedId.contains(":")

        if (normalizedName.isEmpty() || isBuiltinOutput) {
            selectedOutputAddress = null
            selectedOutputName = null
            audioManager.mode = AudioManager.MODE_NORMAL
            audioManager.isSpeakerphoneOn = true
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                audioManager.clearCommunicationDevice()
            }
            applyPreferredOutputToAudioTrack()
            scheduleBuiltinMicReassertion()
            return
        }

        // Rutear salida al BT seleccionado SIN tocar el dispositivo de entrada.
        // setCommunicationDevice() roba también el micrófono y lo mueve al BT.
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            audioManager.mode = AudioManager.MODE_NORMAL
            audioManager.clearCommunicationDevice()

            val allDevices = buildList {
                addAll(audioManager.getDevices(AudioManager.GET_DEVICES_OUTPUTS).toList())
                addAll(audioManager.availableCommunicationDevices)
            }.distinctBy { it.id }

            val matched = allDevices.firstOrNull { device ->
                val productName = device.productName?.toString()?.trim()?.lowercase().orEmpty()
                val address = device.address?.trim()?.lowercase().orEmpty()

                addressFromId.isNotEmpty() && address == addressFromId ||
                normalizedId.isNotEmpty() && address == normalizedId ||
                normalizedName.isNotEmpty() && productName == normalizedName ||
                normalizedName.isNotEmpty() && productName.contains(normalizedName)
            }

            if (matched != null) {
                selectedOutputAddress = matched.address?.trim()?.lowercase()
                selectedOutputName = matched.productName?.toString()?.trim()?.lowercase()
                audioManager.isSpeakerphoneOn = false
                applyPreferredOutputToAudioTrack()
                scheduleBuiltinMicReassertion()
                rebuildActiveRecordingToBuiltinMic()
            }
        }
    }

    private fun applyPreferredOutputToAudioTrack() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.M) return
        val track = audioTrack ?: return
        val audioManager = getSystemService(Context.AUDIO_SERVICE) as AudioManager
        val devices = audioManager.getDevices(AudioManager.GET_DEVICES_OUTPUTS)

        val address = selectedOutputAddress
        val name = selectedOutputName

        val preferred = devices.firstOrNull { device ->
            val deviceAddress = device.address?.trim()?.lowercase().orEmpty()
            val productName = device.productName?.toString()?.trim()?.lowercase().orEmpty()
            (address != null && address.isNotEmpty() && deviceAddress == address) ||
            (name != null && name.isNotEmpty() && productName == name)
        }

        try {
            track.preferredDevice = preferred
        } catch (_: Exception) {}
    }

    private fun extractAddressFromId(id: String): String {
        if (id.startsWith("bt-bonded-") && id.endsWith("-out")) {
            return id.removePrefix("bt-bonded-").removeSuffix("-out")
        }
        if (id.endsWith("-out")) {
            return id.removeSuffix("-out")
        }
        return ""
    }

    private fun getBluetoothAudioDevices(result: MethodChannel.Result) {
        val devices = linkedMapOf<String, MutableMap<String, Any?>>()
        val audioManager = getSystemService(Context.AUDIO_SERVICE) as AudioManager
        val btAdapter = BluetoothAdapter.getDefaultAdapter()
        val mainHandler = Handler(Looper.getMainLooper())
        val delivered = AtomicBoolean(false)

        fun isBluetoothAudioType(type: Int): Boolean {
            return type == AudioDeviceInfo.TYPE_BLUETOOTH_A2DP ||
                type == AudioDeviceInfo.TYPE_BLUETOOTH_SCO ||
                (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S && type == AudioDeviceInfo.TYPE_BLE_HEADSET)
        }

        fun upsertDevice(name: String?, address: String?, type: Int?, connected: Boolean) {
            val safeName = name?.trim().orEmpty()
            val safeAddress = address?.trim().orEmpty()
            if (safeName.isEmpty() && safeAddress.isEmpty()) return

            val key = if (safeAddress.isNotEmpty()) safeAddress.lowercase() else safeName.lowercase()
            val existing = devices[key]
            if (existing == null) {
                devices[key] = mutableMapOf(
                    "name" to if (safeName.isNotEmpty()) safeName else safeAddress,
                    "address" to safeAddress,
                    "type" to type,
                    "connected" to connected,
                )
                return
            }

            if ((existing["name"] as? String).isNullOrBlank() && safeName.isNotEmpty()) {
                existing["name"] = safeName
            }
            if ((existing["address"] as? String).isNullOrBlank() && safeAddress.isNotEmpty()) {
                existing["address"] = safeAddress
            }
            if (type != null) {
                existing["type"] = type
            }
            val wasConnected = existing["connected"] as? Boolean ?: false
            existing["connected"] = wasConnected || connected
        }

        fun markBondedDevicesFromProfile(proxy: BluetoothProfile, profileId: Int) {
            try {
                btAdapter?.bondedDevices?.forEach { device ->
                    val isConnected = proxy.getConnectionState(device) == BluetoothProfile.STATE_CONNECTED
                    if (isConnected) {
                        upsertDevice(device.name, device.address, profileId, true)
                    }
                }
            } catch (_: Exception) {}
        }

        fun deliverOnce() {
            if (delivered.compareAndSet(false, true)) {
                result.success(devices.values.map { it.toMap() })
            }
        }

        try {
            val audioDevices = audioManager.getDevices(AudioManager.GET_DEVICES_OUTPUTS)
            for (device in audioDevices) {
                if (!isBluetoothAudioType(device.type)) continue
                upsertDevice(
                    device.productName?.toString(),
                    device.address,
                    device.type,
                    true,
                )
            }

            btAdapter?.bondedDevices?.forEach { bt ->
                upsertDevice(bt.name, bt.address, bt.type, false)
            }
        } catch (_: Exception) {}

        if (btAdapter == null) {
            deliverOnce()
            return
        }

        val profiles = listOf(BluetoothProfile.A2DP, BluetoothProfile.HEADSET)
        val pending = AtomicInteger(profiles.size)

        fun finishProfile() {
            if (pending.decrementAndGet() <= 0) {
                deliverOnce()
            }
        }

        mainHandler.postDelayed({ deliverOnce() }, 1200)

        profiles.forEach { profile ->
            try {
                val started = btAdapter.getProfileProxy(
                    this,
                    object : BluetoothProfile.ServiceListener {
                        override fun onServiceConnected(profileId: Int, proxy: BluetoothProfile) {
                            try {
                                markBondedDevicesFromProfile(proxy, profileId)
                                proxy.connectedDevices.forEach { device ->
                                    upsertDevice(device.name, device.address, profileId, true)
                                }
                            } catch (_: Exception) {
                            } finally {
                                try {
                                    btAdapter.closeProfileProxy(profileId, proxy)
                                } catch (_: Exception) {}
                                finishProfile()
                            }
                        }

                        override fun onServiceDisconnected(profileId: Int) = Unit
                    },
                    profile,
                )

                if (!started) {
                    finishProfile()
                }
            } catch (_: Exception) {
                finishProfile()
            }
        }
    }

    private fun startNativeRecording(messenger: BinaryMessenger) {
        stopNativeRecording()
        forceBuiltinMic()

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

                        audioRecord = buildBuiltinAudioRecord(bufferSize)

                        // Forzar el mic interno usando DISPOSITIVOS DE ENTRADA.
                        // preferredDevice de AudioRecord debe apuntar a un input real,
                        // no a availableCommunicationDevices.
                        enforceBuiltinMicOnActiveRecording()

                        // Desconectar HFP justo antes de arrancar
                        disconnectHeadsetHfp()
                        audioRecord?.startRecording()
                        scheduleBuiltinMicReassertion()

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
        try {
            audioRecord?.stop()
        } catch (_: Exception) {}
        audioRecord?.release()
        audioRecord = null
        recordSink = null
    }

    /// Guarda el comm device actual antes de limpiarlo (para restaurar salida luego).
    private fun saveCurrentCommDevice() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            val am = getSystemService(Context.AUDIO_SERVICE) as AudioManager
            lastCommDevice = am.communicationDevice
        }
    }

    /// Restaura el dispositivo de salida guardado.
    ///
    /// IMPORTANTE: NO usa setCommunicationDevice porque eso reactiva el HFP
    /// del BT y vuelve a tomar el micrófono del headset. En su lugar solo
    /// controlamos el altavoz y reaffirmamos el mic del celu.
    private fun restoreOutput() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            val am = getSystemService(Context.AUDIO_SERVICE) as AudioManager
            val comm = lastCommDevice
            if (comm != null &&
                comm.type != AudioDeviceInfo.TYPE_BLUETOOTH_A2DP &&
                comm.type != AudioDeviceInfo.TYPE_BLUETOOTH_SCO
            ) {
                // Solo restaurar dispositivos NO Bluetooth
                am.setCommunicationDevice(comm)
            }
            am.isSpeakerphoneOn = false
        }
        // Re-afirmar mic del celular
        enforceBuiltinMicOnActiveRecording()
        scheduleBuiltinMicReassertion()
    }

    /// Limpia el comm device (solo API ≥ 31).
    private fun clearCommDevice() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            val am = getSystemService(Context.AUDIO_SERVICE) as AudioManager
            am.clearCommunicationDevice()
        }
    }

    /// Fuerza el micrófono del teléfono (no toca comm device).
    private fun forceBuiltinMic() {
        val audioManager = getSystemService(Context.AUDIO_SERVICE) as AudioManager
        audioManager.isBluetoothScoOn = false
        audioManager.stopBluetoothSco()
        audioManager.mode = AudioManager.MODE_NORMAL

        try {
            audioManager.setParameters("BT_SCO=off")
        } catch (_: Exception) {}

        // Cortamos HFP/manos libres para que Android no vuelva a tomar
        // el micrófono del headset. A2DP puede seguir para salida.
        disconnectHeadsetHfp()
        enforceBuiltinMicOnActiveRecording()
    }

    private fun buildBuiltinAudioRecord(bufferSize: Int): AudioRecord {
        // Usamos VOICE_RECOGNITION que prioriza el micrófono interno
        val source = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE)
            MediaRecorder.AudioSource.VOICE_RECOGNITION else
            MediaRecorder.AudioSource.VOICE_RECOGNITION
        return AudioRecord.Builder()
            .setAudioSource(source)
            .setAudioFormat(
                AudioFormat.Builder()
                    .setSampleRate(16000)
                    .setChannelMask(AudioFormat.CHANNEL_IN_MONO)
                    .setEncoding(AudioFormat.ENCODING_PCM_16BIT)
                    .build()
            )
            .setBufferSizeInBytes(bufferSize)
            .build()
    }

    private fun rebuildActiveRecordingToBuiltinMic() {
        val current = audioRecord ?: return
        try {
            val bufferSize = AudioRecord.getMinBufferSize(
                16000,
                AudioFormat.CHANNEL_IN_MONO,
                AudioFormat.ENCODING_PCM_16BIT
            )
            current.stop()
            current.release()
            audioRecord = buildBuiltinAudioRecord(bufferSize)
            enforceBuiltinMicOnActiveRecording()
            audioRecord?.startRecording()
            scheduleBuiltinMicReassertion()
        } catch (_: Exception) {}
    }

    private fun scheduleBuiltinMicReassertion() {
        val delays = listOf<Long>(0, 250, 800)
        delays.forEach { delayMs ->
            mainHandler.postDelayed({
                try {
                    forceBuiltinMic()
                } catch (_: Exception) {}
            }, delayMs)
        }
    }

    private fun enforceBuiltinMicOnActiveRecording() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.M) return
        try {
            val am = getSystemService(Context.AUDIO_SERVICE) as AudioManager
            val preferredInput = am.getDevices(AudioManager.GET_DEVICES_INPUTS)
                .firstOrNull { device ->
                    device.type == AudioDeviceInfo.TYPE_BUILTIN_MIC
                }
            if (preferredInput != null) {
                audioRecord?.preferredDevice = preferredInput
            }
        } catch (_: Exception) {}
    }

    private fun registerBluetoothStateReceiver() {
        if (btReceiverRegistered) return
        try {
            val filter = IntentFilter().apply {
                addAction(BluetoothAdapter.ACTION_CONNECTION_STATE_CHANGED)
                addAction(BluetoothA2dp.ACTION_CONNECTION_STATE_CHANGED)
                addAction(BluetoothHeadset.ACTION_CONNECTION_STATE_CHANGED)
                addAction(AudioManager.ACTION_SCO_AUDIO_STATE_UPDATED)
            }
            registerReceiver(btStateReceiver, filter)
            btReceiverRegistered = true
        } catch (_: Exception) {}
    }

    /// Desconecta el perfil HFP (manos libres) de todos los headsets BT.
    /// Así el micrófono vuelve al teléfono manteniendo A2DP para salida.
    private fun disconnectHeadsetHfp() {
        // Si no tenemos permiso BLUETOOTH_CONNECT, no podemos interactuar con HFP
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S &&
            checkSelfPermission(android.Manifest.permission.BLUETOOTH_CONNECT)
                != PackageManager.PERMISSION_GRANTED
        ) return

        try {
            val adapter = BluetoothAdapter.getDefaultAdapter() ?: return
            adapter.getProfileProxy(this, object : BluetoothProfile.ServiceListener {
                override fun onServiceConnected(profile: Int, proxy: BluetoothProfile) {
                    try {
                        if (profile != BluetoothProfile.HEADSET) return
                        val headset = proxy as BluetoothHeadset
                        val devices = headset.connectedDevices
                        for (device in devices) {
                            try { headset.stopVoiceRecognition(device) } catch (_: Exception) {}
                        }
                    } catch (_: Exception) {}
                    adapter.closeProfileProxy(BluetoothProfile.HEADSET, proxy)
                }
                override fun onServiceDisconnected(profile: Int) {}
            }, BluetoothProfile.HEADSET)
        } catch (_: Exception) {}
    }

    private fun startAudioTrack() {
        stopAudioTrack()
        try {
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
            applyPreferredOutputToAudioTrack()
            audioTrack?.play()
        } catch (_: Exception) {
            stopAudioTrack()
        }
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
        if (btReceiverRegistered) {
            try {
                unregisterReceiver(btStateReceiver)
            } catch (_: Exception) {}
            btReceiverRegistered = false
        }
        stopAudioTrack()
        stopNativeRecording()
        super.onDestroy()
    }
}
