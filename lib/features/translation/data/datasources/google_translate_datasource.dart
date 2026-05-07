import 'dart:convert';
import 'package:audio_traductor/core/constants/api_constants.dart';
import 'package:audio_traductor/core/errors/exceptions.dart';
import 'package:http/http.dart' as http;

/// DataSource para Google Cloud Translation API.
abstract class TranslateDatasource {
  Future<TranslateResult> translate({
    required String text,
    required String sourceLanguage,
    required String targetLanguage,
  });
}

/// Resultado de la traducción.
class TranslateResult {
  final String translatedText;
  final String detectedSourceLanguage;

  const TranslateResult({
    required this.translatedText,
    required this.detectedSourceLanguage,
  });
}

/// Mock para desarrollo (sin API key).
class MockTranslateDatasource implements TranslateDatasource {
  @override
  Future<TranslateResult> translate({
    required String text,
    required String sourceLanguage,
    required String targetLanguage,
  }) async {
    await Future.delayed(const Duration(milliseconds: 300));
    return TranslateResult(
      translatedText: '[$targetLanguage] $text',
      detectedSourceLanguage: sourceLanguage,
    );
  }
}

/// Implementación REAL con Google Cloud Translation API v2.
///
/// Usa HTTP POST directo. Solo necesita la API key como query param.
class GoogleTranslateDatasource implements TranslateDatasource {
  final String _apiKey;

  GoogleTranslateDatasource() : _apiKey = ApiConstants.translateApiKey;

  @override
  Future<TranslateResult> translate({
    required String text,
    required String sourceLanguage,
    required String targetLanguage,
  }) async {
    final uri = Uri.parse(ApiConstants.translateEndpoint).replace(
      queryParameters: {'key': _apiKey},
    );

    try {
      final response = await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'q': text,
          'source': sourceLanguage,
          'target': targetLanguage,
          'format': 'text',
        }),
      );

      if (response.statusCode != 200) {
        final body = jsonDecode(response.body);
        final error = body['error']?['message'] ?? 'Error desconocido';
        throw ServerException(
          message: 'Google Translate: $error',
          statusCode: response.statusCode,
        );
      }

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final translation = data['data']['translations'][0];

      return TranslateResult(
        translatedText: translation['translatedText'] as String,
        detectedSourceLanguage:
            translation['detectedSourceLanguage'] as String? ?? sourceLanguage,
      );
    } on ServerException {
      rethrow;
    } catch (e) {
      throw ServerException(
        message: 'Error de conexión con Google Translate: $e',
      );
    }
  }
}
