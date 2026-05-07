import 'package:audio_traductor/core/errors/failures.dart';
import 'package:audio_traductor/features/translation/domain/entities/translation_session.dart';
import 'package:audio_traductor/features/translation/domain/repositories/translation_repository.dart';
import 'package:dartz/dartz.dart';

/// Caso de uso: obtiene el historial de traducciones.
class GetTranslationHistory {
  final TranslationRepository _repository;

  GetTranslationHistory(this._repository);

  /// Devuelve la lista de sesiones anteriores o un [Failure].
  Future<Either<Failure, List<TranslationSession>>> call() {
    return _repository.getHistory();
  }
}

/// Caso de uso: elimina una sesión del historial.
class DeleteTranslationSession {
  final TranslationRepository _repository;

  DeleteTranslationSession(this._repository);

  Future<Either<Failure, void>> call(String sessionId) {
    return _repository.deleteSession(sessionId);
  }
}

/// Caso de uso: limpia todo el historial.
class ClearTranslationHistory {
  final TranslationRepository _repository;

  ClearTranslationHistory(this._repository);

  Future<Either<Failure, void>> call() {
    return _repository.clearHistory();
  }
}
