import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:audio_traductor/core/constants/api_constants.dart';
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
/// Captura audio con [record] package y detecta pausas para enviar párrafos.
class GoogleSttDatasource implements SttDatasource {
  static const _silenceThresholdMs = 500;
  static const _rmsThreshold = 1000;
  static const _audioChannel = MethodChannel('com.audiotraductor/audio');
  static const _micChannel = EventChannel('com.audiotraductor/mic');

  final String _apiKey;
  final http.Client _http = http.Client(); // persistente para reusar conexión
  StreamSubscription<List<int>>? _micSub;
  StreamController<SttResult>? _controller;
  bool _stopping = false;
  String _languageCode = 'es';
  final List<int> _buffer = [];
  int _silenceSamples = 0;
  bool _hadSpeech = false;

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
    _silenceSamples = 0;
    _hadSpeech = false;

    try {
      // 1. Forzar mic del celular (también guarda comm device antes de limpiar)
      await _audioChannel.invokeMethod('forceBuiltinMic');
      // 2. Esperar que SCO se desconecte
      await Future.delayed(const Duration(milliseconds: 150));

      // 3. Iniciar grabación nativa — mic del celular (sin comm device)
      await _audioChannel.invokeMethod('startRecording');
      final stream = _micChannel.receiveBroadcastStream().map<List<int>>((event) {
        if (event is Uint8List) return event;
        if (event is List<int>) return event;
        if (event is List) return List<int>.from(event);
        return const <int>[];
      });

      // 4. Restaurar dispositivo de salida una vez que el recorder ya arrancó
      _micSub = stream.listen(
        _onAudioData,
        onError: (e) => _controller?.addError('Mic: $e'),
      );
      _audioChannel.invokeMethod('restoreOutput');
    } catch (e) {
      _controller?.addError('Error al iniciar mic: $e');
    }

    yield* _controller!.stream;
  }

  void _onAudioData(List<int> chunk) {
    if (_stopping) return;
    _buffer.addAll(chunk);

    // Media de valores absolutos: más robusta que pico para detectar silencio
    final mav = _calcMav(chunk);
    final isSpeech = mav > _rmsThreshold;
    final samplesInChunk = chunk.length ~/ 2;

    if (isSpeech) {
      _silenceSamples = 0;
      _hadSpeech = true;
    } else if (_hadSpeech) {
      _silenceSamples += samplesInChunk;
    }

    // ¿500ms de silencio después de hablar?
    final silenceMs = _silenceSamples * 1000 ~/ 16000;
    if (_hadSpeech && silenceMs >= _silenceThresholdMs) {
      _recognizeBatch();
    }
  }

  /// Media de valores absolutos para PCM 16-bit mono.
  double _calcMav(List<int> bytes) {
    var sum = 0;
    for (var i = 0; i < bytes.length - 1; i += 2) {
      final unsigned = ((bytes[i + 1] & 0xFF) << 8) | (bytes[i] & 0xFF);
      final sample = unsigned > 32767 ? unsigned - 65536 : unsigned;
      sum += sample.abs();
    }
    final count = bytes.length ~/ 2;
    return count > 0 ? sum / count : 0.0;
  }

  Future<void> _recognizeBatch() async {
    if (_buffer.isEmpty || _stopping) return;
    final pcmData = List<int>.from(_buffer);
    _buffer.clear();
    _hadSpeech = false;
    _silenceSamples = 0;

    try {
      final base64Audio = base64Encode(pcmData);
      final uri = Uri.parse(ApiConstants.sttEndpoint).replace(
        queryParameters: {'key': _apiKey},
      );

      final response = await _http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'config': {
            'encoding': 'LINEAR16',
            'sampleRateHertz': 16000,
            'languageCode': _mapLanguage(_languageCode),
            'model': 'command_and_search',
            'enableAutomaticPunctuation': true,
          },
          'audio': {'content': base64Audio},
        }),
      );

      if (response.statusCode != 200 || _stopping) {
        if (response.statusCode != 200) {
          _controller?.addError('STT API error ${response.statusCode}: ${response.body}');
        }
        return;
      }

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
    } catch (e) {
      _controller?.addError('STT error: $e');
    }
  }

  @override
  Future<void> stop() async {
    _stopping = true;
    await _micSub?.cancel();
    _micSub = null;
    try {
      await _audioChannel.invokeMethod('stopRecording');
    } catch (_) {}
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
