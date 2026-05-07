import 'package:audio_traductor/features/translation/domain/entities/translation_paragraph.dart';
import 'package:equatable/equatable.dart';
import 'package:intl/intl.dart';

class TranslationSession extends Equatable {
  final String id;
  final String name;
  final String sourceLanguage;
  final String targetLanguage;
  final List<TranslationParagraph> paragraphs;
  final DateTime createdAt;
  final int durationMs;

  const TranslationSession({
    required this.id,
    this.name = '',
    required this.sourceLanguage,
    required this.targetLanguage,
    this.paragraphs = const [],
    required this.createdAt,
    this.durationMs = 0,
  });

  @override
  List<Object?> get props => [id, name, sourceLanguage, targetLanguage, paragraphs, createdAt, durationMs];

  String get formattedDate => DateFormat('dd/MM/yyyy HH:mm').format(createdAt);

  String get formattedDuration {
    final s = (durationMs / 1000).floor();
    return '${(s / 60).floor()}m ${s % 60}s';
  }

  int get paragraphCount => paragraphs.length;

  /// Todo el texto original concatenado.
  String get fullOriginal => paragraphs.map((p) => p.originalText).join(' ');

  /// Toda la traducción concatenada.
  String get fullTranslated => paragraphs.map((p) => p.translatedText).join(' ');
}
