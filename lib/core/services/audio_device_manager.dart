import 'dart:async';
import 'package:audio_session/audio_session.dart' as a;
import 'package:flutter/services.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart' as fbp;
import 'package:flutter_riverpod/flutter_riverpod.dart';

class AudioDevice {
  final String id;
  final String name;
  final bool isInput;
  final bool isOutput;
  final String typeLabel;
  final bool isConnected;

  const AudioDevice({
    required this.id,
    required this.name,
    required this.isInput,
    required this.isOutput,
    required this.typeLabel,
    this.isConnected = false,
  });
}

class AudioDevicesState {
  final List<AudioDevice> devices;
  final String? selectedInputId;
  final String? selectedOutputId;
  final bool hasManualOutputSelection;
  final bool isScanning;

  const AudioDevicesState({
    this.devices = const [],
    this.selectedInputId = 'builtin-mic',
    this.selectedOutputId = 'builtin-speaker',
    this.hasManualOutputSelection = false,
    this.isScanning = false,
  });

  AudioDevicesState copyWith({
    List<AudioDevice>? devices,
    String? selectedInputId,
    String? selectedOutputId,
    bool? hasManualOutputSelection,
    bool? isScanning,
  }) {
    return AudioDevicesState(
      devices: devices ?? this.devices,
      selectedInputId: selectedInputId ?? this.selectedInputId,
      selectedOutputId: selectedOutputId ?? this.selectedOutputId,
      hasManualOutputSelection:
          hasManualOutputSelection ?? this.hasManualOutputSelection,
      isScanning: isScanning ?? this.isScanning,
    );
  }
}

class AudioDeviceNotifier extends StateNotifier<AudioDevicesState> {
  a.AudioSession? _session;
  StreamSubscription<Set<a.AudioDevice>>? _deviceSub;
  StreamSubscription<bool>? _btScanSub;
  List<Map<String, dynamic>> _bondedDevices = [];

  AudioDeviceNotifier() : super(const AudioDevicesState()) {
    _init();
  }

  Future<void> _init() async {
    _session = await a.AudioSession.instance;
    await _configureSession();
    _loadInitial();
    _listenChanges();
    _listenBT();
    _loadConnectedBT();
  }

  /// Configura la sesión de audio para Bluetooth.
  /// voiceCommunication activa el perfil SCO (bidireccional) en Android,
  /// necesario para headsets con micrófono.
  Future<void> _configureSession() async {
    try {
      await _session?.configure(a.AudioSessionConfiguration(
        avAudioSessionCategory: a.AVAudioSessionCategory.playAndRecord,
        avAudioSessionCategoryOptions: a.AVAudioSessionCategoryOptions.allowBluetooth |
            a.AVAudioSessionCategoryOptions.defaultToSpeaker,
        androidAudioAttributes: const a.AndroidAudioAttributes(
          contentType: a.AndroidAudioContentType.speech,
          usage: a.AndroidAudioUsage.voiceCommunication,
        ),
        androidAudioFocusGainType: a.AndroidAudioFocusGainType.gain,
      ));
      await _session?.setActive(true);
      await _forceBuiltinMic();
    } catch (_) {}
  }

  Future<void> _loadInitial() async {
    try {
      final set = await _session?.getDevices() ?? {};
      _updateFromSet(set);
    } catch (_) {
      _fallbackDevices();
    }
  }

  /// Carga dispositivos BT vinculados + conectados (independiente).
  Future<void> _loadConnectedBT() async {
    // Primero cargar vinculados (no depende de flutter_blue_plus)
    _bondedDevices = await _getBondedDevices();

    final set = await _session?.getDevices() ?? {};
    _updateFromSet(set);
  }

  /// Obtiene dispositivos BT vinculados (clásico + BLE).
  Future<List<Map<String, dynamic>>> _getBondedDevices() async {
    try {
      const channel = MethodChannel('com.audiotraductor/audio');
      final result = await channel.invokeMethod('getBondedDevices');
      if (result is List) return List<Map<String, dynamic>>.from(
        result.map((e) => Map<String, dynamic>.from(e as Map)),
      );
    } catch (_) {}
    return [];
  }

  void _listenChanges() {
    // Pequeño delay para evitar doble carga con _loadInitial
    Future.delayed(const Duration(milliseconds: 300), () {
      _deviceSub = _session?.devicesStream.listen((_) => _loadConnectedBT());
    });
  }

  void _listenBT() {
    _btScanSub = fbp.FlutterBluePlus.isScanning.listen((s) {
      state = state.copyWith(isScanning: s);
    });
  }

  void selectInput(String id) {
    state = state.copyWith(selectedInputId: 'builtin-mic');
    _configureSession();
  }

  void selectOutput(String id) {
    state = state.copyWith(
      selectedOutputId: id,
      hasManualOutputSelection: true,
    );
    _routeOutputById(id);
  }

  /// Rutea el audio al dispositivo seleccionado vía nativo.
  Future<void> _routeOutput({required String deviceName, required String deviceId}) async {
    try {
      final device = state.devices.where((d) => d.id == deviceId).firstOrNull;
      const channel = MethodChannel('com.audiotraductor/audio');
      await channel.invokeMethod('selectOutput', {
        'name': deviceName,
        'id': deviceId,
        'type': device?.typeLabel ?? '',
      });
      await _forceBuiltinMic();
    } catch (_) {}
  }

  Future<void> _forceBuiltinMic() async {
    try {
      const channel = MethodChannel('com.audiotraductor/audio');
      await channel.invokeMethod('forceBuiltinMic');
    } catch (_) {}
  }

  /// Refresca la lista de dispositivos (llamar después de conectar BT).
  Future<void> refreshDevices() async {
    await _loadConnectedBT();
  }

  void _updateFromSet(Set<a.AudioDevice> set) {
    final devices = <AudioDevice>[];
    final seen = <String>{'builtin-mic', 'micrófono integrado'};

    // Siempre el micrófono integrado
    devices.add(const AudioDevice(id: 'builtin-mic', name: 'Micrófono integrado', isInput: true, isOutput: false, typeLabel: 'Integrado', isConnected: true));

    for (final d in set) {
      final typeStr = d.type.name;
      if (typeStr == 'builtInEarpiece') continue;

      final name = _cleanName(d.name);
      if (name.isEmpty) continue;
      if (seen.contains(name.toLowerCase())) continue;
      seen.add(name.toLowerCase());

      devices.add(AudioDevice(
        id: d.id,
        name: name,
        isInput: false,
        isOutput: d.isOutput,
        typeLabel: _labelFor(typeStr),
        isConnected: true,
      ));
    }

    // Agregar dispositivos BT vinculados no detectados
    for (final b in _bondedDevices) {
      final addr = b['address'] as String? ?? '';
      final rawName = b['name'] as String? ?? '';
      final isConnected = b['connected'] as bool? ?? false;
      final name = rawName.isNotEmpty ? rawName : addr;
      if (addr.isEmpty) continue;
      if (seen.contains(addr.toLowerCase())) continue;
      seen.add(addr.toLowerCase());

      devices.add(AudioDevice(
        id: 'bt-bonded-$addr-out',
        name: name,
        isInput: false,
        isOutput: true,
        typeLabel: 'Bluetooth',
        isConnected: isConnected,
      ));
    }

    // Limitar a 15 dispositivos máx
    final list = devices.take(15).toList();
    final previousSelection = state.selectedOutputId;
    final keepManualSelection = state.hasManualOutputSelection &&
        list.any((d) => d.isOutput && d.id == previousSelection);

    final inferredOutput = _resolvePreferredOutputId(list);
    final nextOutputId = keepManualSelection
        ? previousSelection
        : inferredOutput;

    state = state.copyWith(
      devices: list,
      selectedInputId: 'builtin-mic',
      selectedOutputId: nextOutputId,
      hasManualOutputSelection: keepManualSelection,
    );

    if (nextOutputId != null) {
      _routeOutputById(nextOutputId);
    }
  }

  void _fallbackDevices() {
    final devices = <AudioDevice>[
      const AudioDevice(id: 'builtin-mic', name: 'Micrófono integrado', isInput: true, isOutput: false, typeLabel: 'Integrado', isConnected: true),
    ];

    for (final b in _bondedDevices) {
      final addr = b['address'] as String? ?? '';
      final rawName = b['name'] as String? ?? '';
      final isConnected = b['connected'] as bool? ?? false;
      final name = rawName.isNotEmpty ? rawName : addr;
      if (addr.isEmpty) continue;
      devices.add(AudioDevice(
        id: 'bt-bonded-$addr-out',
        name: name,
        isInput: false,
        isOutput: true,
        typeLabel: 'Bluetooth',
        isConnected: isConnected,
      ));
    }

    final btOutput = devices.cast<AudioDevice?>().firstWhere(
      (d) => d!.isOutput && d.typeLabel == 'Bluetooth',
      orElse: () => null,
    );
    state = state.copyWith(
      devices: devices,
      selectedInputId: 'builtin-mic',
      selectedOutputId: btOutput?.id ?? 'builtin-speaker',
      hasManualOutputSelection: false,
    );

    if (state.selectedOutputId != null) {
      _routeOutputById(state.selectedOutputId!);
    }
  }

  Future<void> _routeOutputById(String id) async {
    final device = state.devices.where((d) => d.id == id).firstOrNull;
    final name = device?.name ?? '';
    await _routeOutput(deviceName: name, deviceId: id);
  }

  String _resolvePreferredOutputId(List<AudioDevice> devices) {
    final connectedBluetoothOutput = devices.cast<AudioDevice?>().firstWhere(
      (d) => d!.isOutput && d.isConnected && d.typeLabel == 'Bluetooth',
      orElse: () => null,
    );
    if (connectedBluetoothOutput != null) return connectedBluetoothOutput.id;

    final connectedOutput = devices.cast<AudioDevice?>().firstWhere(
      (d) => d!.isOutput && d.isConnected,
      orElse: () => null,
    );
    if (connectedOutput != null) return connectedOutput.id;

    final anyOutput = devices.cast<AudioDevice?>().firstWhere(
      (d) => d!.isOutput,
      orElse: () => null,
    );
    return anyOutput?.id ?? 'builtin-speaker';
  }

  String _labelFor(String type) {
    if (type.contains('bluetooth')) return 'Bluetooth';
    return switch (type) {
      'wiredHeadset' || 'wiredHeadphones' => 'Cable',
      'builtInSpeaker' => 'Integrado',
      _ => 'Externo',
    };
  }

  String _cleanName(String raw) => raw.replaceAll(RegExp(r'\[.*?\]'), '').trim();

  @override
  void dispose() {
    _deviceSub?.cancel();
    _btScanSub?.cancel();
    super.dispose();
  }
}

final audioDevicesProvider = StateNotifierProvider<AudioDeviceNotifier, AudioDevicesState>((ref) {
  return AudioDeviceNotifier();
});
