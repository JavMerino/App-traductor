import 'dart:convert';
import 'package:audio_traductor/core/constants/api_constants.dart';
import 'package:audio_traductor/core/errors/exceptions.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:http/http.dart' as http;

/// DataSource para Text-to-Speech.
abstract class TtsDatasource {
  Future<TtsResult> synthesize({
    required String text,
    required String voiceName,
    required String languageCode,
  });
}

/// Resultado del TTS.
class TtsResult {
  final String audioBase64;
  final String audioFormat;

  const TtsResult({
    required this.audioBase64,
    required this.audioFormat,
  });
}

/// Implementación con [flutter_tts] nativo del dispositivo.
///
/// GRATIS, offline, sin API key.
/// Usa el motor TTS del sistema (Google TTS Engine en Android,
/// AVSpeechSynthesizer en iOS).
///
/// NOTA: En Android puede requerir descargar datos de voz para
/// cada idioma en: Ajustes → Idioma → Texto a voz → Instalar datos de voz.
class RealTtsDatasource implements TtsDatasource {
  static final RealTtsDatasource instance = RealTtsDatasource._();
  final FlutterTts _tts;

  RealTtsDatasource._() : _tts = FlutterTts();

  @override
  Future<TtsResult> synthesize({
    required String text,
    required String voiceName,
    required String languageCode,
  }) async {
    try {
      await _tts.setLanguage(_mapLanguage(languageCode));
      await _tts.setPitch(1.0);
      await _tts.setSpeechRate(0.5);
      await _tts.setVolume(1.0);
      await _tts.speak(text);
    } catch (_) {}

    // flutter_tts habla directo, no devolvemos audio
    return const TtsResult(audioBase64: '', audioFormat: 'native');
  }

  String _mapLanguage(String code) {
    const map = {
      'es': 'es-ES', 'en': 'en-US', 'pt': 'pt-BR', 'fr': 'fr-FR',
      'de': 'de-DE', 'it': 'it-IT', 'ja': 'ja-JP', 'zh': 'zh-CN',
      'ko': 'ko-KR', 'ru': 'ru-RU', 'ar': 'ar-SA', 'nl': 'nl-NL',
    };
    return map[code] ?? 'en-US';
  }
}

/// Mock para desarrollo.
class MockTtsDatasource implements TtsDatasource {
  @override
  Future<TtsResult> synthesize({
    required String text,
    required String voiceName,
    required String languageCode,
  }) async {
    await Future.delayed(const Duration(milliseconds: 400));
    return const TtsResult(audioBase64: 'MOCK_AUDIO_DATA', audioFormat: 'mp3');
  }
}

/// Implementación con Google Cloud Text-to-Speech API.
class GoogleTtsDatasource implements TtsDatasource {
  final String _apiKey;

  GoogleTtsDatasource() : _apiKey = ApiConstants.ttsApiKey;

  @override
  Future<TtsResult> synthesize({
    required String text,
    required String voiceName,
    required String languageCode,
  }) async {
    final uri = Uri.parse(ApiConstants.ttsEndpoint).replace(
      queryParameters: {'key': _apiKey},
    );

    try {
      final response = await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'input': {'text': text},
          'voice': {
            'languageCode': _mapLanguage(languageCode),
            'name': voiceName,
          },
          'audioConfig': {
            'audioEncoding': 'MP3',
            'speakingRate': 1.0,
          },
        }),
      );

      if (response.statusCode != 200) {
        final body = jsonDecode(response.body);
        final error = body['error']?['message'] ?? 'Error desconocido';
        throw ServerException(
          message: 'Google TTS: $error',
          statusCode: response.statusCode,
        );
      }

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final audioContent = data['audioContent'] as String;

      return TtsResult(
        audioBase64: audioContent,
        audioFormat: 'mp3',
      );
    } on ServerException {
      rethrow;
    } catch (e) {
      throw ServerException(
        message: 'Error de conexión con Google TTS: $e',
      );
    }
  }

  String _mapLanguage(String code) {
    const map = {
      'es': 'es-ES', 'en': 'en-US', 'pt': 'pt-BR', 'fr': 'fr-FR',
      'de': 'de-DE', 'it': 'it-IT', 'ja': 'ja-JP', 'zh': 'zh-CN',
      'ko': 'ko-KR', 'ru': 'ru-RU', 'ar': 'ar-SA', 'nl': 'nl-NL',
    };
    return map[code] ?? 'en-US';
  }
}
