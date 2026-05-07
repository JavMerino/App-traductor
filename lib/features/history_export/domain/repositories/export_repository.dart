import 'package:audio_traductor/core/errors/failures.dart';
import 'package:audio_traductor/features/translation/domain/entities/translation_session.dart';
import 'package:dartz/dartz.dart';

/// Contrato para la exportación del historial.
abstract class ExportRepository {
  /// Exporta una o varias sesiones a PDF.
  ///
  /// Devuelve la ruta del archivo generado.
  Future<Either<Failure, String>> exportToPdf({
    required List<TranslationSession> sessions,
    required String fileName,
  });

  /// Comparte el archivo exportado.
  Future<Either<Failure, void>> shareFile(String filePath);
}
