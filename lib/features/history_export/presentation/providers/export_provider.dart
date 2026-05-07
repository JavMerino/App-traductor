import 'package:audio_traductor/features/history_export/data/repositories/export_repository_impl.dart';
import 'package:audio_traductor/features/history_export/domain/repositories/export_repository.dart';
import 'package:audio_traductor/features/history_export/domain/usecases/export_history_pdf.dart';
import 'package:audio_traductor/features/translation/domain/entities/translation_session.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Provider del repositorio de exportación.
final exportRepositoryProvider = Provider<ExportRepository>((ref) {
  return ExportRepositoryImpl();
});

/// Provider del caso de uso de exportación.
final exportHistoryPdfProvider = Provider<ExportHistoryToPdf>((ref) {
  return ExportHistoryToPdf(ref.watch(exportRepositoryProvider));
});

/// Estado de la exportación.
enum ExportStatus { idle, exporting, success, error }

/// Provider para exportar sesiones a PDF.
final exportPdfProvider =
    FutureProvider.family<String, List<TranslationSession>>((
  ref,
  sessions,
) async {
  final useCase = ref.watch(exportHistoryPdfProvider);
  final result = await useCase(sessions: sessions);
  return result.fold(
    (failure) => throw failure,
    (path) => path,
  );
});
