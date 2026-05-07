import 'package:equatable/equatable.dart';

class TranslationParagraph extends Equatable {
  final String id;
  final String originalText;
  final String translatedText;
  final String sourceLanguage;
  final String targetLanguage;
  final DateTime timestamp;

  const TranslationParagraph({
    required this.id,
    required this.originalText,
    required this.translatedText,
    required this.sourceLanguage,
    required this.targetLanguage,
    required this.timestamp,
  });

  @override
  List<Object?> get props => [id, originalText, translatedText, sourceLanguage, targetLanguage, timestamp];
}
