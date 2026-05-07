import 'dart:io';
import 'dart:typed_data';
import 'package:audio_traductor/core/errors/failures.dart';
import 'package:audio_traductor/features/history_export/domain/repositories/export_repository.dart';
import 'package:audio_traductor/features/translation/domain/entities/translation_session.dart';
import 'package:dartz/dartz.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:intl/intl.dart';

/// Implementación concreta de [ExportRepository] usando
/// el paquete `pdf` para generar documentos y `share_plus` para compartir.
class ExportRepositoryImpl implements ExportRepository {
  @override
  Future<Either<Failure, String>> exportToPdf({
    required List<TranslationSession> sessions,
    required String fileName,
  }) async {
    try {
      final pdf = await _generatePdf(sessions);
      final path = await _savePdf(pdf, fileName);
      return Right(path);
    } on Exception catch (e) {
      return Left(
        ExportFailure(
          message: 'Error al generar PDF: $e',
        ),
      );
    }
  }

  @override
  Future<Either<Failure, void>> shareFile(String filePath) async {
    try {
      await Share.shareXFiles([XFile(filePath)]);
      return const Right(null);
    } on Exception catch (e) {
      return Left(
        ExportFailure(
          message: 'Error al compartir: $e',
        ),
      );
    }
  }

  Future<Uint8List> _generatePdf(List<TranslationSession> sessions) async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        header: (pw.Context context) => pw.Header(
          level: 0,
          child: pw.Text(
            'Audio Traductor - Historial de Traducciones',
            style: pw.TextStyle(
              fontSize: 18,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
        ),
        footer: (pw.Context context) => pw.Container(
          alignment: pw.Alignment.centerRight,
          margin: const pw.EdgeInsets.only(top: 16),
          child: pw.Text(
            'Página ${context.pageNumber}',
            style: pw.TextStyle(
              fontSize: 10,
              color: PdfColors.grey,
            ),
          ),
        ),
        build: (pw.Context context) => [
          pw.Paragraph(
            text:
                'Total de traducciones: ${sessions.length}\n'
                'Generado el: ${DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now())}',
            style: pw.TextStyle(fontSize: 11, color: PdfColors.grey),
          ),
          pw.SizedBox(height: 20),
          ...sessions.map((session) => _buildSessionSection(session)),
        ],
      ),
    );

    return pdf.save();
  }

  pw.Widget _buildSessionSection(TranslationSession session) {
    final items = <pw.Widget>[];

    // Header
    items.add(pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Text(
          '${session.sourceLanguage.toUpperCase()} → ${session.targetLanguage.toUpperCase()}',
          style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: PdfColors.blue700),
        ),
        pw.Text(session.formattedDate, style: pw.TextStyle(fontSize: 10, color: PdfColors.grey)),
      ],
    ));
    items.add(pw.SizedBox(height: 8));

    // Párrafos
    for (int i = 0; i < session.paragraphs.length; i++) {
      final p = session.paragraphs[i];
      items.add(pw.Text('Párrafo ${i + 1}', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: PdfColors.grey)));
      items.add(pw.SizedBox(height: 4));
      items.add(pw.Text(p.originalText, style: const pw.TextStyle(fontSize: 11)));
      items.add(pw.SizedBox(height: 4));
      items.add(pw.Text(p.translatedText, style: pw.TextStyle(fontSize: 11, color: PdfColors.blue900)));
      items.add(pw.SizedBox(height: 10));
    }

    items.add(pw.Divider());

    return pw.Container(
      margin: const pw.EdgeInsets.only(bottom: 16),
      padding: const pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey300),
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
      ),
      child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: items),
    );
  }

  Future<String> _savePdf(Uint8List data, String fileName) async {
    final directory = await getApplicationDocumentsDirectory();
    final filePath = '${directory.path}/$fileName.pdf';
    final file = File(filePath);
    await file.writeAsBytes(data);
    return filePath;
  }
}
