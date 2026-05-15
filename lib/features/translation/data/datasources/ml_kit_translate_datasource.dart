import 'package:audio_traductor/core/errors/exceptions.dart';
import 'package:audio_traductor/features/translation/data/datasources/google_translate_datasource.dart';
import 'package:google_mlkit_translation/google_mlkit_translation.dart';

/// DataSource de traducción ON-DEVICE usando Google ML Kit.
///
/// No requiere internet después de descargar los modelos de idioma.
/// Los modelos se descargan UNA VEZ por idioma y quedan cacheados.
///
/// IMPORTANTE: usa lazy initialization para no tocar el plugin nativo
/// hasta el primer uso. Esto evita crashes si se crea antes de runApp().
class MlKitTranslateDatasource implements TranslateDatasource {
  OnDeviceTranslator? _translator;
  String? _currentSource;
  String? _currentTarget;
  OnDeviceTranslatorModelManager? _modelManager;

  /// Retorna el model manager creándolo lazy (primera vez que se necesita).
  OnDeviceTranslatorModelManager get _manager {
    _modelManager ??= OnDeviceTranslatorModelManager();
    return _modelManager!;
  }

  @override
  Future<TranslateResult> translate({
    required String text,
    required String sourceLanguage,
    required String targetLanguage,
  }) async {
    await _ensureReady(sourceLanguage, targetLanguage);

    try {
      final translated = await _translator!.translateText(text);
      return TranslateResult(
        translatedText: translated,
        detectedSourceLanguage:
            sourceLanguage, // ML Kit no detecta, usamos el que nos dieron
      );
    } catch (e) {
      throw ServerException(
        message: 'ML Kit Translation: $e',
      );
    }
  }

  /// Verifica si los modelos para source y target ya están descargados.
  Future<bool> areModelsDownloaded(String source, String target) async {
    final sourceLang = _toTranslateLanguage(source);
    final targetLang = _toTranslateLanguage(target);
    if (sourceLang == null || targetLang == null) return false;

    final sourceOk =
        await _manager.isModelDownloaded(sourceLang.bcpCode);
    final targetOk =
        await _manager.isModelDownloaded(targetLang.bcpCode);
    return sourceOk && targetOk;
  }

  /// Descarga los modelos de source y target, reportando progreso.
  ///
  /// El callback [onProgress] recibe (progreso 0.0-1.0, código del idioma actual).
  /// Los pasos son:
  ///   1. Descargar modelo fuente  (0.0 → 0.5)
  ///   2. Descargar modelo destino (0.5 → 1.0)
  ///
  /// Si un modelo ya está descargado, saltea ese paso.
  Future<void> downloadModels({
    required String source,
    required String target,
    required void Function(double progress, String languageCode) onProgress,
  }) async {
    final sourceLang = _toTranslateLanguage(source);
    final targetLang = _toTranslateLanguage(target);
    if (sourceLang == null || targetLang == null) {
      throw ServerException(
        message:
            'ML Kit no soporta este par de idiomas: source=$source, target=$target',
      );
    }

    // Paso 1: fuente
    final sourceNeeded =
        !(await _manager.isModelDownloaded(sourceLang.bcpCode));
    if (sourceNeeded) {
      onProgress(0.0, source);
      await _manager.downloadModel(sourceLang.bcpCode);
    }

    // Paso 2: destino
    final targetNeeded =
        !(await _manager.isModelDownloaded(targetLang.bcpCode));
    if (targetNeeded) {
      onProgress(0.5, target);
      await _manager.downloadModel(targetLang.bcpCode);
    }

    onProgress(1.0, '');
  }

  /// Asegura que el translator esté listo para el par de idiomas.
  Future<void> _ensureReady(String source, String target) async {
    if (_translator != null &&
        _currentSource == source &&
        _currentTarget == target) {
      return;
    }

    _translator?.close();

    final sourceLang = _toTranslateLanguage(source);
    final targetLang = _toTranslateLanguage(target);

    if (sourceLang == null || targetLang == null) {
      throw ServerException(
        message:
            'ML Kit no soporta este par de idiomas: source=$source, target=$target',
      );
    }

    await _manager.downloadModel(sourceLang.bcpCode);
    await _manager.downloadModel(targetLang.bcpCode);

    _translator = OnDeviceTranslator(
      sourceLanguage: sourceLang,
      targetLanguage: targetLang,
    );
    _currentSource = source;
    _currentTarget = target;
  }

  /// Mapea códigos ISO 639-1 a TranslateLanguage de ML Kit.
  static TranslateLanguage? _toTranslateLanguage(String code) {
    switch (code) {
      case 'af': return TranslateLanguage.afrikaans;
      case 'ar': return TranslateLanguage.arabic;
      case 'be': return TranslateLanguage.belarusian;
      case 'bg': return TranslateLanguage.bulgarian;
      case 'bn': return TranslateLanguage.bengali;
      case 'ca': return TranslateLanguage.catalan;
      case 'cs': return TranslateLanguage.czech;
      case 'cy': return TranslateLanguage.welsh;
      case 'da': return TranslateLanguage.danish;
      case 'de': return TranslateLanguage.german;
      case 'el': return TranslateLanguage.greek;
      case 'en': return TranslateLanguage.english;
      case 'eo': return TranslateLanguage.esperanto;
      case 'es': return TranslateLanguage.spanish;
      case 'et': return TranslateLanguage.estonian;
      case 'fa': return TranslateLanguage.persian;
      case 'fi': return TranslateLanguage.finnish;
      case 'fr': return TranslateLanguage.french;
      case 'ga': return TranslateLanguage.irish;
      case 'gl': return TranslateLanguage.galician;
      case 'gu': return TranslateLanguage.gujarati;
      case 'he': return TranslateLanguage.hebrew;
      case 'hi': return TranslateLanguage.hindi;
      case 'hr': return TranslateLanguage.croatian;
      case 'ht': return TranslateLanguage.haitian;
      case 'hu': return TranslateLanguage.hungarian;
      case 'id': return TranslateLanguage.indonesian;
      case 'is': return TranslateLanguage.icelandic;
      case 'it': return TranslateLanguage.italian;
      case 'ja': return TranslateLanguage.japanese;
      case 'ka': return TranslateLanguage.georgian;
      case 'kn': return TranslateLanguage.kannada;
      case 'ko': return TranslateLanguage.korean;
      case 'lt': return TranslateLanguage.lithuanian;
      case 'lv': return TranslateLanguage.latvian;
      case 'mk': return TranslateLanguage.macedonian;
      case 'mr': return TranslateLanguage.marathi;
      case 'ms': return TranslateLanguage.malay;
      case 'mt': return TranslateLanguage.maltese;
      case 'nl': return TranslateLanguage.dutch;
      case 'no': return TranslateLanguage.norwegian;
      case 'pl': return TranslateLanguage.polish;
      case 'pt': return TranslateLanguage.portuguese;
      case 'ro': return TranslateLanguage.romanian;
      case 'ru': return TranslateLanguage.russian;
      case 'sk': return TranslateLanguage.slovak;
      case 'sl': return TranslateLanguage.slovenian;
      case 'sq': return TranslateLanguage.albanian;
      case 'sv': return TranslateLanguage.swedish;
      case 'sw': return TranslateLanguage.swahili;
      case 'ta': return TranslateLanguage.tamil;
      case 'te': return TranslateLanguage.telugu;
      case 'th': return TranslateLanguage.thai;
      case 'tl': return TranslateLanguage.tagalog;
      case 'tr': return TranslateLanguage.turkish;
      case 'uk': return TranslateLanguage.ukrainian;
      case 'ur': return TranslateLanguage.urdu;
      case 'vi': return TranslateLanguage.vietnamese;
      case 'zh': return TranslateLanguage.chinese;
      default: return null;
    }
  }
}
