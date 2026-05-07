import 'package:audio_traductor/features/history_export/data/repositories/export_repository_impl.dart';
import 'package:audio_traductor/features/translation/domain/entities/translation_session.dart';
import 'package:flutter/material.dart';

/// Botón para exportar el historial a PDF y compartirlo.
class ExportButton extends StatelessWidget {
  final List<TranslationSession> sessions;

  const ExportButton({super.key, required this.sessions});

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.picture_as_pdf_outlined),
      tooltip: 'Exportar a PDF',
      onPressed: sessions.isEmpty
          ? null
          : () => _export(context),
    );
  }

  Future<void> _export(BuildContext context) async {
    if (sessions.isEmpty) return;

    final repo = ExportRepositoryImpl();
    final result = await repo.exportToPdf(
      sessions: sessions,
      fileName: 'historial_traducciones',
    );

    result.fold(
      (failure) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: ${failure.message}')),
          );
        }
      },
      (filePath) async {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('PDF generado: $filePath'),
              action: SnackBarAction(
                label: 'Compartir',
                onPressed: () => repo.shareFile(filePath),
              ),
            ),
          );
        }
      },
    );
  }
}
