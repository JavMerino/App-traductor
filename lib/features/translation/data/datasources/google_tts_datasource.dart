import 'dart:async';
import 'dart:convert';
import 'package:audio_traductor/core/constants/api_constants.dart';
import 'package:audio_traductor/core/errors/exceptions.dart';
import 'package:audio_traductor/features/translation/domain/entities/voice_actor.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:http/http.dart' as http;

/// DataSource para Text-to-Speech.
abstract class TtsDatasource {
  Future<TtsResult> synthesize({
    required String text,
    required String voiceName,
    required String languageCode,
    required double speed,
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
  List<Map<String, String>>? _availableVoices;

  RealTtsDatasource._() : _tts = FlutterTts();

  /// Pre-calienta el motor TTS para un idioma (reduce latencia del primer síntesis).
  Future<void> warmup(String languageCode, String voiceName) async {
    try {
      await _tts.setLanguage(_mapLanguage(languageCode));
      if (voiceName.isNotEmpty) {
        await _selectVoice(voiceName, languageCode);
      }
      // Decir algo corto para cargar la voz (silencioso)
      await _tts.setVolume(0);
      await _tts.speak('');
      await Future.delayed(const Duration(milliseconds: 200));
      await _tts.setVolume(1);
      await _tts.stop();
    } catch (_) {}
  }

  /// Detiene la reproducción TTS en curso.
  Future<void> stop() async {
    try {
      await _tts.stop();
    } catch (_) {}
  }

  /// Busca voces reales del dispositivo y matchea por idioma + género.
  /// Usa [VoiceActor.forLanguage] para saber si la voz seleccionada
  /// es masculina o femenina, y busca una voz del dispositivo que coincida.
  Future<void> _selectVoice(String voiceName, String languageCode) async {
    if (voiceName.isEmpty) return;

    try {
      // Cargar voces disponibles (cacheado)
      _availableVoices ??= (await _tts.getVoices)
          .map<Map<String, String>>((v) => Map<String, String>.from(v))
          .toList();

      final voices = _availableVoices;
      if (voices == null || voices.isEmpty) return;

      final lang = languageCode.split('-').first; // 'en' de 'es'/'en'
      final locale = _mapLanguage(languageCode);

      // Filtrar voces del dispositivo que matchean el idioma
      final matching = voices.where((v) {
        final vLocale = (v['locale'] ?? v['language'] ?? '').toLowerCase();
        return vLocale.contains(lang);
      }).toList();

      if (matching.isEmpty) return;

      // Buscar el VoiceActor para saber el género deseado
      final actors = VoiceActor.forLanguage(languageCode);
      VoiceActor? actor;
      for (final a in actors) {
        if (a.name == voiceName) { actor = a; break; }
      }
      final wantsMale = actor?.gender == VoiceGender.male;
      final wantsFemale = actor?.gender == VoiceGender.female;

      // Intentar matchear por género usando patrones conocidos de Android TTS
      if (wantsMale || wantsFemale) {
        for (final v in matching) {
          final name = (v['name'] ?? '').toLowerCase();

          // Patrones comunes en Google TTS para Android:
          // tpd / -d / male → masculino
          // tpf / -f / female → femenino
          final isMale = name.contains('tpd') ||
              name.contains('-d-') ||
              name.contains('male') ||
              name.contains('hombre');
          final isFemale = name.contains('tpf') ||
              name.contains('-f-') ||
              name.contains('female') ||
              name.contains('fem') ||
              name.contains('mujer');

          if (wantsMale && isMale && !isFemale) {
            await _tts.setVoice({'name': v['name'] ?? '', 'locale': locale});
            return;
          }
          if (wantsFemale && isFemale && !isMale) {
            await _tts.setVoice({'name': v['name'] ?? '', 'locale': locale});
            return;
          }
        }
      }

      // Fallback: primera voz del idioma
      final picked = matching.first['name'];
      if (picked != null) {
        await _tts.setVoice({'name': picked, 'locale': locale});
      }
    } catch (_) {
      // Si falla, el motor usa la voz default del sistema
    }
  }

  @override
  Future<TtsResult> synthesize({
    required String text,
    required String voiceName,
    required String languageCode,
    required double speed,
  }) async {
    try {
      // Completer que se resuelve cuando el TTS TERMINA de hablar
      // (no cuando apenas empieza, que era el bug)
      final completer = Completer<void>();

      _tts.setCompletionHandler(() {
        if (!completer.isCompleted) completer.complete();
      });
      _tts.setCancelHandler(() {
        if (!completer.isCompleted) completer.complete();
      });
      _tts.setErrorHandler((message) {
        if (!completer.isCompleted) completer.complete();
      });

      final mappedLocale = _mapLanguage(languageCode);

      await _tts.setLanguage(mappedLocale);

      // Buscar voz real del dispositivo que matchee idioma + género
      await _selectVoice(voiceName, languageCode);

      await _tts.setPitch(1.0);
      await _tts.setSpeechRate(speed);
      await _tts.setVolume(1.0);
      await _tts.speak(text);

      // Esperar a que el motor TTS realmente termine de hablar
      await completer.future;
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
    required double speed,
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
    required double speed,
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
            'speakingRate': speed,
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
