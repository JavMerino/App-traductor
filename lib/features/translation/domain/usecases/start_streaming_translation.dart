import 'package:audio_traductor/features/translation/domain/repositories/translation_repository.dart';

/// Caso de uso: inicia una sesión de traducción en tiempo real.
class StartStreamingTranslation {
  final TranslationRepository _repository;

  StartStreamingTranslation(this._repository);

  /// Inicia la escucha y traducción.
  ///
  /// Devuelve un [Stream] de [TranslationChunk] con los resultados
  /// parciales y finales.
  Stream<TranslationChunk> call({
    required String sourceLanguage,
    required String targetLanguage,
    required String voiceName,
  }) {
    return _repository.startTranslation(
      sourceLanguage: sourceLanguage,
      targetLanguage: targetLanguage,
      voiceName: voiceName,
    );
  }
}
