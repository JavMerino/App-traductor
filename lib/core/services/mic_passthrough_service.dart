import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/services.dart';

/// Servicio de passthrough: captura el micrófono y lo reproduce
/// por el altavoz en tiempo real usando AudioTrack nativo de Android.
///
/// Latencia ~100ms. Sin archivos, sin just_audio.
class MicPassthroughService {
  static const _channel = MethodChannel('com.audiotraductor/passthrough');
  static const _audioChannel = MethodChannel('com.audiotraductor/audio');
  static const _micChannel = EventChannel('com.audiotraductor/mic');

  StreamSubscription<List<int>>? _micSub;
  bool _running = false;

  bool get isRunning => _running;

  /// Inicia el passthrough (mic → parlante).
  Future<void> start() async {
    if (_running) return;
    _running = true;

    try {
      await _audioChannel.invokeMethod('startRecording');
      await _channel.invokeMethod('start');
    } catch (_) {
      _running = false;
      return;
    }

    try {
      final stream = _micChannel.receiveBroadcastStream().map<List<int>>((event) {
        if (event is Uint8List) return event;
        if (event is List<int>) return event;
        if (event is List) return List<int>.from(event);
        return const <int>[];
      });

      _micSub = stream.listen(
        (chunk) {
          if (!_running) return;
          _channel.invokeMethod('write', <String, dynamic>{
            'bytes': chunk,
          });
        },
        onError: (_) => stop(),
      );
    } catch (_) {
      _running = false;
    }
  }

  /// Detiene el passthrough.
  Future<void> stop() async {
    _running = false;
    await _micSub?.cancel();
    _micSub = null;
    try {
      await _audioChannel.invokeMethod('stopRecording');
    } catch (_) {}
    await _channel.invokeMethod('stop');
  }

  void dispose() {
    stop();
  }
}
