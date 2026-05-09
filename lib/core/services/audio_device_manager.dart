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

  AudioDeviceNotifier() : super(const AudioDevicesState()) {
    _init();
  }

  Future<void> _init() async {
    _session = await a.AudioSession.instance;
    _loadInitial();
    _listenChanges();
    _listenBT();
  }

  Future<void> _loadInitial() async {
    try {
      final set = await _session?.getDevices() ?? {};
      _updateFromSet(set);
    } catch (_) {
      _fallbackDevices();
    }
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
  }

  void selectOutput(String id) {
    state = state.copyWith(selectedOutputId: id);
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

    // Limitar a 7 dispositivos máx (2 integrados + 5 externos)
    state = state.copyWith(devices: devices.take(7).toList());
  }

  void _fallbackDevices() {
    state = state.copyWith(devices: [
      const AudioDevice(id: 'builtin-mic', name: 'Micrófono integrado', isInput: true, isOutput: false, typeLabel: 'Integrado', isConnected: true),
      const AudioDevice(id: 'builtin-speaker', name: 'Altavoz integrado', isInput: false, isOutput: true, typeLabel: 'Integrado', isConnected: true),
    ]);
  }

  String _labelFor(String type) => switch (type) {
    'wiredHeadset' || 'wiredHeadphones' => 'Cable',
    'bluetooth' || 'bluetoothA2DP' || 'bluetoothLE' => 'Bluetooth',
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
