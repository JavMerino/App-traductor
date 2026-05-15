/// Contrato abstracto para la traducción de texto.
///
/// Implementaciones:
/// - [MockTranslateDatasource] — para testing
/// - [MlKitTranslateDatasource] — on-device con ML Kit (producción)
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

/// Mock para desarrollo (sin API key ni modelo).
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
