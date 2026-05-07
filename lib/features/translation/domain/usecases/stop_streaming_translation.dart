import 'package:audio_traductor/core/errors/failures.dart';
import 'package:audio_traductor/features/translation/domain/entities/translation_session.dart';
import 'package:audio_traductor/features/translation/domain/repositories/translation_repository.dart';
import 'package:dartz/dartz.dart';

/// Caso de uso: detiene la sesión de traducción activa.
class StopStreamingTranslation {
  final TranslationRepository _repository;

  StopStreamingTranslation(this._repository);

  /// Detiene la traducción y guarda la sesión.
  ///
  /// Devuelve la [TranslationSession] completa o un [Failure].
  Future<Either<Failure, TranslationSession>> call() {
    return _repository.stopTranslation();
  }
}
