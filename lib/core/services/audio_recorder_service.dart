import 'dart:async';
import 'package:record/record.dart';

/// Servicio de grabación de audio desde el micrófono.
///
/// Encapsula el paquete `record` y expone un stream de chunks de audio.
class AudioRecorderService {
  final _recorder = AudioRecorder();
  StreamSubscription<List<int>>? _subscription;

  /// ¿Hay una grabación en curso?
  bool get isRecording => _subscription != null;

  /// Inicia la captura de audio y devuelve un stream de bytes.
  ///
  /// El audio se captura en formato PCM 16-bit, 16kHz, mono.
  Stream<List<int>> start({int sampleRate = 16000}) {
    final controller = StreamController<List<int>>();

    _recorder
        .startStream(
          const RecordConfig(
            encoder: AudioEncoder.pcm16bits,
            numChannels: 1,
            sampleRate: 16000,
          ),
        )
        .then((stream) {
          _subscription = stream.listen(
            controller.add,
            onError: controller.addError,
            onDone: () => controller.close(),
          );
        })
        .catchError((Object e) {
          controller.addError(e);
        });

    return controller.stream;
  }

  /// Detiene la grabación.
  Future<void> stop() async {
    await _subscription?.cancel();
    _subscription = null;
    await _recorder.stop();
  }

  /// Libera recursos.
  void dispose() {
    _subscription?.cancel();
    _recorder.dispose();
  }
}
