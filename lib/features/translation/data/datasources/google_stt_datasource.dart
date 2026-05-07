import 'dart:async';
import 'package:audio_traductor/core/errors/exceptions.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart';

/// DataSource para reconocimiento de voz.
///
/// Responsabilidad: escuchar el micrófono y devolver texto transcrito.
///
/// [RealSttDatasource] usa el motor de reconocimiento nativo del dispositivo
/// (Android SpeechRecognizer / iOS SFSpeechRecognizer) — NO requiere
/// credenciales de cloud y funciona offline.
abstract class SttDatasource {
  Stream<SttResult> startStreaming({
    required Stream<List<int>> audioStream,
    required String languageCode,
  });

  Future<void> stop();
}

/// Resultado del STT.
class SttResult {
  final String transcript;
  final bool isFinal;
  final double confidence;

  const SttResult({
    required this.transcript,
    this.isFinal = false,
    this.confidence = 0.0,
  });
}

/// Implementación REAL con [speech_to_text] nativo del dispositivo.
///
/// Usa el reconocimiento de voz on-device (Android/iOS).
/// Maneja el micrófono internamente — el parámetro [audioStream] se ignora.
class RealSttDatasource implements SttDatasource {
  final _speech = SpeechToText();
  StreamController<SttResult>? _controller;

  @override
  Stream<SttResult> startStreaming({
    required Stream<List<int>> audioStream,
    required String languageCode,
  }) async* {
    _controller = StreamController<SttResult>.broadcast();

    final available = await _speech.initialize(
      onError: (error) => _controller?.addError(error),
    );

    if (!available) {
      _controller?.addError('Reconocimiento de voz no disponible');
      yield* _controller!.stream;
      return;
    }

    // Iniciar escucha SIN await — el callback onResult alimenta el stream
    unawaited(_speech.listen(
      onResult: (SpeechRecognitionResult result) {
        if (result.recognizedWords.isEmpty) return;

        _controller?.add(SttResult(
          transcript: result.recognizedWords,
          isFinal: result.finalResult,
          confidence: 1.0,
        ));
      },
      localeId: _mapLanguage(languageCode),
      listenOptions: SpeechListenOptions(
        listenMode: ListenMode.confirmation,
        partialResults: true,
        cancelOnError: false,
      ),
    ));

    yield* _controller!.stream;
  }

  @override
  Future<void> stop() async {
    await _speech.stop();
    await _controller?.close();
    _controller = null;
  }

  /// Mapea códigos ISO cortos a locales completos.
  String _mapLanguage(String code) {
    const map = {
      'es': 'es_ES',
      'en': 'en_US',
      'pt': 'pt_BR',
      'fr': 'fr_FR',
      'de': 'de_DE',
      'it': 'it_IT',
      'ja': 'ja_JP',
      'zh': 'zh_CN',
      'ko': 'ko_KR',
      'ru': 'ru_RU',
      'ar': 'ar_SA',
      'nl': 'nl_NL',
    };
    return map[code] ?? 'en_US';
  }
}

/// Implementación mock — genera frases predeterminadas (legado).
class MockSttDatasource implements SttDatasource {
  final _phrases = <String>[
    'Buenos días a todos',
    'Hoy vamos a hablar sobre',
    'la importancia de la traducción',
    'en tiempo real para conferencias',
    'Muchas gracias por su atención',
  ];

  @override
  Stream<SttResult> startStreaming({
    required Stream<List<int>> audioStream,
    required String languageCode,
  }) async* {
    for (final phrase in _phrases) {
      await Future.delayed(const Duration(milliseconds: 2000));
      yield SttResult(transcript: phrase, isFinal: false);
      await Future.delayed(const Duration(milliseconds: 500));
      yield SttResult(transcript: phrase, isFinal: true, confidence: 0.95);
    }
  }

  @override
  Future<void> stop() async {}
}

/// Implementación con Google Cloud Speech-to-Text API (futura).
class GoogleSttDatasource implements SttDatasource {
  final String _apiKey;

  GoogleSttDatasource(this._apiKey);

  @override
  Stream<SttResult> startStreaming({
    required Stream<List<int>> audioStream,
    required String languageCode,
  }) async* {
    throw const ServerException(
      message: 'Google STT no está configurado. '
          'Usá RealSttDatasource para desarrollo.',
    );
  }

  @override
  Future<void> stop() async {}
}
