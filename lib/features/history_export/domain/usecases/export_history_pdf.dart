import 'package:audio_traductor/core/errors/failures.dart';
import 'package:audio_traductor/features/history_export/domain/repositories/export_repository.dart';
import 'package:audio_traductor/features/translation/domain/entities/translation_session.dart';
import 'package:dartz/dartz.dart';

/// Caso de uso: exporta el historial a PDF.
class ExportHistoryToPdf {
  final ExportRepository _repository;

  ExportHistoryToPdf(this._repository);

  Future<Either<Failure, String>> call({
    required List<TranslationSession> sessions,
    String? fileName,
  }) {
    final name = fileName ?? 'historial_traducciones_${DateTime.now().millisecondsSinceEpoch}';
    return _repository.exportToPdf(sessions: sessions, fileName: name);
  }
}
