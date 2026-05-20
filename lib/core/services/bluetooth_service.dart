import 'dart:async';
import 'package:flutter/services.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart' as fbp;

/// Dispositivo Bluetooth encontrado en el scan.
class BTDevice {
  final String id;
  final String name;
  final int rssi;
  final bool isConnected;

  const BTDevice({
    required this.id,
    required this.name,
    this.rssi = 0,
    this.isConnected = false,
  });
}

/// Servicio de Bluetooth – scan, conexión y estado de dispositivos de audio.
class BluetoothService {
  static const MethodChannel _systemChannel = MethodChannel('com.audiotraductor/system');
  StreamSubscription<List<fbp.ScanResult>>? _scanSub;
  fbp.BluetoothDevice? _connectedDevice;

  final _devicesController = StreamController<List<BTDevice>>.broadcast();
  Stream<List<BTDevice>> get scanResults => _devicesController.stream;

  final _connectionController = StreamController<BTDevice?>.broadcast();
  Stream<BTDevice?> get connectionState => _connectionController.stream;

  BTDevice? get connectedDevice => _currentConnected;
  BTDevice? _currentConnected;

  /// ¿El Bluetooth está encendido?
  Future<bool> get isAvailable async =>
      (await fbp.FlutterBluePlus.adapterState.first) == fbp.BluetoothAdapterState.on;

  /// Inicia escaneo de dispositivos.
  Future<void> startScan({int timeoutSec = 10}) async {
    if (_currentConnected != null) {
      _connectionController.add(_currentConnected);
    }

    _devicesController.add([]);

    final state = await fbp.FlutterBluePlus.adapterState.first;
    if (state != fbp.BluetoothAdapterState.on) {
      try {
        await fbp.FlutterBluePlus.turnOn();
      } catch (_) {}
    }

    await fbp.FlutterBluePlus.startScan(
      timeout: Duration(seconds: timeoutSec),
    );

    _scanSub?.cancel();
    _scanSub = fbp.FlutterBluePlus.scanResults.listen((results) {
      final devices = results
          .map((r) => BTDevice(
                id: r.device.remoteId.str,
                name: r.device.platformName.isNotEmpty
                    ? r.device.platformName
                    : r.advertisementData.advName.isNotEmpty
                        ? r.advertisementData.advName
                        : r.device.remoteId.str,
                rssi: r.rssi,
              ))
          .where((d) => d.name.isNotEmpty)
          .toList();

      final unique = <String, BTDevice>{};
      for (final d in devices) {
        final existing = unique[d.id];
        if (existing == null || d.rssi > existing.rssi) {
          unique[d.id] = d;
        }
      }

      _devicesController.add(unique.values.toList());
    });
  }

  /// Detiene el scan.
  Future<void> stopScan() async {
    await _scanSub?.cancel();
    _scanSub = null;
    try {
      await fbp.FlutterBluePlus.stopScan();
    } catch (_) {}
  }

  /// Conecta a un dispositivo escaneado.
  Future<bool> connectToResult(fbp.ScanResult scanResult) async {
    try {
      await scanResult.device.connect();
      _connectedDevice = scanResult.device;
      _currentConnected = BTDevice(
        id: scanResult.device.remoteId.str,
        name: scanResult.device.platformName.isNotEmpty
            ? scanResult.device.platformName
            : scanResult.advertisementData.advName,
        isConnected: true,
      );
      _connectionController.add(_currentConnected);

      scanResult.device.connectionState.listen((state) {
        if (state == fbp.BluetoothConnectionState.disconnected) {
          _currentConnected = null;
          _connectedDevice = null;
          _connectionController.add(null);
        }
      });

      return true;
    } catch (_) {
      return false;
    }
  }

  /// Desconecta el dispositivo actual.
  Future<void> disconnect() async {
    await _connectedDevice?.disconnect();
    _connectedDevice = null;
    _currentConnected = null;
    _connectionController.add(null);
  }

  Future<void> openSystemBluetoothSettings() async {
    await _systemChannel.invokeMethod('openBluetoothSettings');
  }

  void dispose() {
    _scanSub?.cancel();
    _devicesController.close();
    _connectionController.close();
  }
}
