import 'package:audio_traductor/core/errors/failures.dart';
import 'package:audio_traductor/features/translation/domain/entities/translation_session.dart';
import 'package:dartz/dartz.dart';

abstract class TranslationRepository {
  Stream<TranslationChunk> startTranslation({
    required String sourceLanguage,
    required String targetLanguage,
    required String voiceName,
    required double speed,
    String? existingSessionId,
    String? sessionName,
  });

  Future<Either<Failure, TranslationSession>> stopTranslation();

  Future<Either<Failure, List<TranslationSession>>> getHistory();

  Future<Either<Failure, TranslationSession?>> getSession(String id);

  Future<Either<Failure, void>> deleteSession(String sessionId);

  Future<Either<Failure, void>> clearHistory();
}

class TranslationChunk {
  final String originalText;
  final String translatedText;
  final bool isFinal;
  final String? audioBase64;

  const TranslationChunk({
    required this.originalText,
    required this.translatedText,
    this.isFinal = false,
    this.audioBase64,
  });
}
