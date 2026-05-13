import 'dart:async';
import 'dart:convert';
import 'package:audio_traductor/core/constants/api_constants.dart';
import 'package:audio_traductor/core/errors/exceptions.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
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
  bool _stopping = false;
  String _languageCode = 'es_ES';

  @override
  Stream<SttResult> startStreaming({
    required Stream<List<int>> audioStream,
    required String languageCode,
  }) async* {
    _controller = StreamController<SttResult>.broadcast();
    _stopping = false;
    _languageCode = _mapLanguage(languageCode);

    final available = await _speech.initialize();

    if (!available) {
      _controller?.addError('Reconocimiento de voz no disponible');
      yield* _controller!.stream;
      return;
    }

    // Primera escucha
    _startListening();

    yield* _controller!.stream;
  }

  void _startListening() {
    _speech.listen(
      onResult: (SpeechRecognitionResult result) {
        if (result.recognizedWords.isEmpty) return;
        _controller?.add(SttResult(
          transcript: result.recognizedWords,
          isFinal: result.finalResult,
          confidence: 1.0,
        ));
      },
      localeId: _languageCode,
      listenOptions: SpeechListenOptions(
        listenMode: ListenMode.search,
        partialResults: true,
      ),
    ).then((_) {
      // Sesión terminó naturalmente — reiniciar con delay mínimo
      if (!_stopping) {
        Future.delayed(const Duration(milliseconds: 300), _startListening);
      }
    }).catchError((_) {
      // Error en la sesión — reintentar
      if (!_stopping) {
        Future.delayed(const Duration(milliseconds: 500), _startListening);
      }
    });
  }

  @override
  Future<void> stop() async {
    _stopping = true;
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

/// Implementación con Google Cloud Speech-to-Text API.
///
/// Captura audio desde el micrófono nativo de Android (NO BT)
/// mediante [EventChannel] que recibe PCM del AudioRecord nativo
/// configurado con VOICE_RECOGNITION + setPreferredDevice.
/// Cada ~3 segundos envía el audio a Google STT API.
class GoogleSttDatasource implements SttDatasource {
  static const _audioChannel = MethodChannel('com.audiotraductor/audio');
  static const _micChannel = EventChannel('com.audiotraductor/mic');

  final String _apiKey;
  StreamSubscription? _micSub;
  StreamController<SttResult>? _controller;
  bool _stopping = false;
  String _languageCode = 'es';
  final List<int> _buffer = [];

  GoogleSttDatasource(this._apiKey);

  @override
  Stream<SttResult> startStreaming({
    required Stream<List<int>> audioStream,
    required String languageCode,
  }) async* {
    _controller = StreamController<SttResult>.broadcast();
    _stopping = false;
    _languageCode = languageCode;
    _buffer.clear();

    // Iniciar captura nativa (VOICE_RECOGNITION + built-in mic)
    await _audioChannel.invokeMethod('startRecording');

    // Escuchar el stream de audio nativo
    _micSub = _micChannel.receiveBroadcastStream().listen(
      (data) {
        if (_stopping) return;
        if (data is! List<int>) return;
        _onAudioData(data);
      },
      onError: (e) => _controller?.addError('Error de micrófono: $e'),
    );

    yield* _controller!.stream;
  }

  void _onAudioData(List<int> chunk) {
    if (_stopping) return;
    _buffer.addAll(chunk);

    // ~3 segundos de audio a 16kHz mono 16-bit = 96000 bytes
    if (_buffer.length >= 96000) {
      _recognizeBatch();
    }
  }

  Future<void> _recognizeBatch() async {
    if (_buffer.isEmpty || _stopping) return;
    final pcmData = List<int>.from(_buffer);
    _buffer.clear();

    try {
      final base64Audio = base64Encode(pcmData);
      final uri = Uri.parse(ApiConstants.sttEndpoint).replace(
        queryParameters: {'key': _apiKey},
      );

      final response = await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'config': {
            'encoding': 'LINEAR16',
            'sampleRateHertz': 16000,
            'languageCode': _mapLanguage(_languageCode),
            'model': 'default',
          },
          'audio': {
            'content': base64Audio,
          },
        }),
      );

      if (response.statusCode != 200 || _stopping) return;

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final results = data['results'] as List?;
      if (results == null || results.isEmpty) return;

      final result = results.last as Map<String, dynamic>;
      final alternatives = result['alternatives'] as List?;
      if (alternatives == null || alternatives.isEmpty) return;

      final transcript = (alternatives.first as Map)['transcript'] as String?;
      if (transcript == null || transcript.isEmpty) return;

      final confidence =
          ((alternatives.first as Map)['confidence'] as num?)?.toDouble() ?? 1.0;

      _controller?.add(SttResult(
        transcript: transcript,
        isFinal: result['isFinal'] as bool? ?? true,
        confidence: confidence,
      ));
    } catch (_) {}
  }

  @override
  Future<void> stop() async {
    _stopping = true;
    await _micSub?.cancel();
    _micSub = null;
    await _audioChannel.invokeMethod('stopRecording');
    await _controller?.close();
    _controller = null;
    _buffer.clear();
  }

  String _mapLanguage(String code) {
    const map = {
      'es': 'es-ES', 'en': 'en-US', 'pt': 'pt-BR',
      'fr': 'fr-FR', 'de': 'de-DE', 'it': 'it-IT',
      'ja': 'ja-JP', 'zh': 'zh-CN', 'ko': 'ko-KR',
      'ru': 'ru-RU', 'ar': 'ar-SA', 'nl': 'nl-NL',
    };
    return map[code] ?? 'en-US';
  }
}
