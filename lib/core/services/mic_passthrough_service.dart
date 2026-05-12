import 'dart:async';
import 'package:flutter/services.dart';
import 'package:record/record.dart';

/// Servicio de passthrough: captura el micrófono y lo reproduce
/// por el altavoz en tiempo real usando AudioTrack nativo de Android.
///
/// Latencia ~100ms. Sin archivos, sin just_audio.
class MicPassthroughService {
  static const _channel = MethodChannel('com.audiotraductor/passthrough');

  final _recorder = AudioRecorder();
  StreamSubscription<List<int>>? _micSub;
  bool _running = false;

  bool get isRunning => _running;

  /// Inicia el passthrough (mic → parlante).
  Future<void> start() async {
    if (_running) return;
    _running = true;

    await _channel.invokeMethod('start');

    try {
      final stream = await _recorder.startStream(
        const RecordConfig(
          encoder: AudioEncoder.pcm16bits,
          numChannels: 1,
          sampleRate: 16000,
        ),
      );

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
      await _recorder.stop();
    } catch (_) {}
    await _channel.invokeMethod('stop');
  }

  void dispose() {
    stop();
    _recorder.dispose();
  }
}
