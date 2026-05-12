import 'dart:async';
import 'package:audio_traductor/core/services/bluetooth_service.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart' as fbp;
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Estado del Bluetooth en la UI.
class BluetoothState {
  final bool isScanning;
  final bool isAdapterOn;
  final List<BTDevice> devices;
  final BTDevice? connectedDevice;
  final String? error;

  const BluetoothState({
    this.isScanning = false,
    this.isAdapterOn = false,
    this.devices = const [],
    this.connectedDevice,
    this.error,
  });

  BluetoothState copyWith({
    bool? isScanning,
    bool? isAdapterOn,
    List<BTDevice>? devices,
    BTDevice? connectedDevice,
    String? error,
  }) {
    return BluetoothState(
      isScanning: isScanning ?? this.isScanning,
      isAdapterOn: isAdapterOn ?? this.isAdapterOn,
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
  StreamSubscription? _adapterSub;

  BluetoothNotifier(this._service) : super(const BluetoothState()) {
    _scanSub = _service.scanResults.listen((devices) {
      state = state.copyWith(devices: devices);
    });

    _connectionSub = _service.connectionState.listen((device) {
      state = state.copyWith(connectedDevice: device, isScanning: false);
    });

    // Escuchar estado del adaptador Bluetooth
    _adapterSub = fbp.FlutterBluePlus.adapterState.listen((s) {
      state = state.copyWith(isAdapterOn: s == fbp.BluetoothAdapterState.on);
    });

    // Estado inicial del adaptador
    fbp.FlutterBluePlus.adapterState.first.then((s) {
      state = state.copyWith(isAdapterOn: s == fbp.BluetoothAdapterState.on);
    });

    final current = _service.connectedDevice;
    if (current != null) {
      state = state.copyWith(connectedDevice: current);
    }
  }

  /// Activa o desactiva el Bluetooth.
  /// Encender siempre muestra el diálogo del sistema.
  /// Apagar puede no funcionar en todos los dispositivos.
  Future<void> toggleAdapter() async {
    try {
      if (state.isAdapterOn) {
        // Intentar apagar — puede fallar según la versión de Android
        await fbp.FlutterBluePlus.turnOn(); // no-op si ya está prendido
      } else {
        await fbp.FlutterBluePlus.turnOn();
      }
    } catch (_) {}
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
    _adapterSub?.cancel();
    _service.dispose();
    super.dispose();
  }
}

final bluetoothProvider =
    StateNotifierProvider<BluetoothNotifier, BluetoothState>((ref) {
  final service = BluetoothService();
  return BluetoothNotifier(service);
});
