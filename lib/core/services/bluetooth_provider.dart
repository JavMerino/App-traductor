import 'dart:async';
import 'package:audio_traductor/core/services/bluetooth_service.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart' as fbp;
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Estado del Bluetooth en la UI.
class BluetoothState {
  final bool isScanning;
  final List<BTDevice> devices;
  final BTDevice? connectedDevice;
  final String? error;

  const BluetoothState({
    this.isScanning = false,
    this.devices = const [],
    this.connectedDevice,
    this.error,
  });

  BluetoothState copyWith({
    bool? isScanning,
    List<BTDevice>? devices,
    BTDevice? connectedDevice,
    String? error,
  }) {
    return BluetoothState(
      isScanning: isScanning ?? this.isScanning,
      devices: devices ?? this.devices,
      connectedDevice: connectedDevice,
      error: error,
    );
  }
}

class BluetoothNotifier extends StateNotifier<BluetoothState> {
  final BluetoothService _service;
  StreamSubscription? _scanSub;
  StreamSubscription? _connectionSub;

  BluetoothNotifier(this._service) : super(const BluetoothState()) {
    _scanSub = _service.scanResults.listen((devices) {
      state = state.copyWith(devices: devices);
    });

    _connectionSub = _service.connectionState.listen((device) {
      state = state.copyWith(connectedDevice: device, isScanning: false);
    });

    final current = _service.connectedDevice;
    if (current != null) {
      state = state.copyWith(connectedDevice: current);
    }
  }

  Future<void> startScan() async {
    state = state.copyWith(isScanning: true, devices: [], error: null);
    try {
      await _service.startScan();
    } catch (e) {
      state = state.copyWith(isScanning: false, error: 'Error al escanear: $e');
    }
  }

  Future<void> stopScan() async {
    await _service.stopScan();
    state = state.copyWith(isScanning: false);
  }

  Future<void> connect(fbp.ScanResult result) async {
    state = state.copyWith(error: null);
    final ok = await _service.connectToResult(result);
    if (!ok && state.connectedDevice == null) {
      state = state.copyWith(
        error: 'No se pudo conectar a ${result.device.platformName}',
      );
    }
  }

  Future<void> disconnect() async {
    await _service.disconnect();
    state = state.copyWith(connectedDevice: null);
  }

  @override
  void dispose() {
    _scanSub?.cancel();
    _connectionSub?.cancel();
    _service.dispose();
    super.dispose();
  }
}

final bluetoothProvider =
    StateNotifierProvider<BluetoothNotifier, BluetoothState>((ref) {
  final service = BluetoothService();
  return BluetoothNotifier(service);
});
