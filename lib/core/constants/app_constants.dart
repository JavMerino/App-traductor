/// Constantes globales de la aplicación.
class AppConstants {
  AppConstants._();

  /// Nombre comercial.
  static const String appName = 'Audio Traductor';

  /// Descripción corta.
  static const String appDescription =
      'Traducción de voz en tiempo real para conferencias';

  /// Versión.
  static const String appVersion = '1.0.0';

  // ── idiomas predeterminados ──
  static const String defaultSourceLanguage = 'es';
  static const String defaultTargetLanguage = 'en';
  static const String defaultSourceLanguageName = 'Español';
  static const String defaultTargetLanguageName = 'Inglés';

  // ── audio ──
  static const String defaultVoiceName = 'es-ES-Standard-A';
  static const int defaultSampleRate = 16000;
  static const int audioChunkSizeMs = 300; // chunks de 300ms para streaming

  // ── almacenamiento ──
  static const String historyBoxName = 'translation_history';

  // ── Bluetooth ──
  static const Duration btScanDuration = Duration(seconds: 10);

  // ── límites ──
  static const int maxHistoryItems = 500;
  static const int maxTextLength = 5000;
}
