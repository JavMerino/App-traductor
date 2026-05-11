import 'package:audio_traductor/features/translation/domain/repositories/translation_repository.dart';

class StartStreamingTranslation {
  final TranslationRepository _repository;

  StartStreamingTranslation(this._repository);

  Stream<TranslationChunk> call({
    required String sourceLanguage,
    required String targetLanguage,
    required String voiceName,
    required double speed,
    String? existingSessionId,
    String? sessionName,
  }) {
    return _repository.startTranslation(
      sourceLanguage: sourceLanguage,
      targetLanguage: targetLanguage,
      voiceName: voiceName,
      speed: speed,
      existingSessionId: existingSessionId,
      sessionName: sessionName,
    );
  }
}
