import 'dart:async';
import 'package:audio_session/audio_session.dart' as a;
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
  final bool isScanning;

  const AudioDevicesState({
    this.devices = const [],
    this.selectedInputId = 'builtin-mic',
    this.selectedOutputId = 'builtin-speaker',
    this.isScanning = false,
  });

  AudioDevicesState copyWith({
    List<AudioDevice>? devices,
    String? selectedInputId,
    String? selectedOutputId,
    bool? isScanning,
  }) {
    return AudioDevicesState(
      devices: devices ?? this.devices,
      selectedInputId: selectedInputId ?? this.selectedInputId,
      selectedOutputId: selectedOutputId ?? this.selectedOutputId,
      isScanning: isScanning ?? this.isScanning,
    );
  }
}

class AudioDeviceNotifier extends StateNotifier<AudioDevicesState> {
  a.AudioSession? _session;
  StreamSubscription<Set<a.AudioDevice>>? _deviceSub;
  StreamSubscription<bool>? _btScanSub;
  List<fbp.BluetoothDevice> _btDevices = [];

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

  /// Carga dispositivos BT ya conectados vía flutter_blue_plus.
  /// audio_session no siempre detecta headsets Bluetooth en todos los Android.
  Future<void> _loadConnectedBT() async {
    try {
      _btDevices = await fbp.FlutterBluePlus.connectedDevices;
      // Reconstruir lista combinando audio_session + BT
      final set = await _session?.getDevices() ?? {};
      _updateFromSet(set);
    } catch (_) {}
  }

  void _listenChanges() {
    // Pequeño delay para evitar doble carga con _loadInitial
    Future.delayed(const Duration(milliseconds: 300), () {
      _deviceSub = _session?.devicesStream.listen((set) => _updateFromSet(set));
    });
  }

  void _listenBT() {
    _btScanSub = fbp.FlutterBluePlus.isScanning.listen((s) {
      state = state.copyWith(isScanning: s);
    });
  }

  void selectInput(String id) {
    state = state.copyWith(selectedInputId: id);
    _configureSession();
  }

  void selectOutput(String id) {
    state = state.copyWith(selectedOutputId: id);
    _configureSession();
  }

  void _updateFromSet(Set<a.AudioDevice> set) {
    final devices = <AudioDevice>[];
    final seen = <String>{'builtin-mic', 'builtin-speaker', 'micrófono integrado', 'altavoz integrado'};

    // Siempre los integrados
    devices.add(const AudioDevice(id: 'builtin-mic', name: 'Micrófono integrado', isInput: true, isOutput: false, typeLabel: 'Integrado', isConnected: true));
    devices.add(const AudioDevice(id: 'builtin-speaker', name: 'Altavoz integrado', isInput: false, isOutput: true, typeLabel: 'Integrado', isConnected: true));

    for (final d in set) {
      final typeStr = d.type.name;
      if (typeStr == 'builtInSpeaker' || typeStr == 'builtInEarpiece') continue;

      final name = _cleanName(d.name);
      if (name.isEmpty) continue;
      if (seen.any((s) => name.toLowerCase().contains(s.toLowerCase()) || s.contains(name.toLowerCase()))) continue;
      seen.add(name.toLowerCase());

      devices.add(AudioDevice(
        id: d.id,
        name: name,
        isInput: d.isInput,
        isOutput: d.isOutput,
        typeLabel: _labelFor(typeStr),
        isConnected: true,
      ));
    }

    // Agregar dispositivos BT ya conectados que audio_session no detectó
    for (final bt in _btDevices) {
      final name = bt.platformName.isNotEmpty ? bt.platformName : bt.remoteId.str;
      if (name.isEmpty) continue;
      if (seen.any((s) => name.toLowerCase().contains(s.toLowerCase()) || s.contains(name.toLowerCase()))) continue;
      seen.add(name.toLowerCase());

      final id = bt.remoteId.str;

      // Agregar como entrada (mic) y salida (parlante)
      devices.add(AudioDevice(
        id: '$id-in',
        name: '$name 🎤',
        isInput: true,
        isOutput: false,
        typeLabel: 'Bluetooth',
        isConnected: true,
      ));
      devices.add(AudioDevice(
        id: '$id-out',
        name: name,
        isInput: false,
        isOutput: true,
        typeLabel: 'Bluetooth',
        isConnected: true,
      ));
    }

    // Limitar a 10 dispositivos máx
    state = state.copyWith(devices: devices.take(10).toList());
  }

  void _fallbackDevices() {
    final devices = <AudioDevice>[
      const AudioDevice(id: 'builtin-mic', name: 'Micrófono integrado', isInput: true, isOutput: false, typeLabel: 'Integrado', isConnected: true),
      const AudioDevice(id: 'builtin-speaker', name: 'Altavoz integrado', isInput: false, isOutput: true, typeLabel: 'Integrado', isConnected: true),
    ];

    // Agregar todos los BT como entrada y salida
    for (final bt in _btDevices) {
      final name = bt.platformName.isNotEmpty ? bt.platformName : bt.remoteId.str;
      if (name.isEmpty) continue;
      final id = bt.remoteId.str;
      devices.add(AudioDevice(id: '$id-in', name: '$name 🎤', isInput: true, isOutput: false, typeLabel: 'Bluetooth', isConnected: true));
      devices.add(AudioDevice(id: '$id-out', name: name, isInput: false, isOutput: true, typeLabel: 'Bluetooth', isConnected: true));
    }

    state = state.copyWith(devices: devices);
  }

  String _labelFor(String type) => switch (type) {
    'wiredHeadset' || 'wiredHeadphones' => 'Cable',
    'bluetooth' || 'bluetoothA2DP' || 'bluetoothLE' || 'bluetoothSCOHeadset' || 'bluetoothHeadset' => 'Bluetooth',
    _ => 'Externo',
  };

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
