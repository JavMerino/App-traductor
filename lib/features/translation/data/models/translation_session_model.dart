import 'package:audio_traductor/features/translation/domain/entities/translation_paragraph.dart';
import 'package:audio_traductor/features/translation/domain/entities/translation_session.dart';

class TranslationSessionModel {
  final String id;
  final String name;
  final String sourceLanguage;
  final String targetLanguage;
  final List<Map<String, dynamic>> paragraphsJson;
  final DateTime createdAt;
  final int durationMs;

  const TranslationSessionModel({
    required this.id,
    this.name = '',
    required this.sourceLanguage,
    required this.targetLanguage,
    required this.paragraphsJson,
    required this.createdAt,
    required this.durationMs,
  });

  factory TranslationSessionModel.fromJson(Map<String, dynamic> json) {
    return TranslationSessionModel(
      id: json['id'] as String,
      name: json['name'] as String? ?? '',
      sourceLanguage: json['sourceLanguage'] as String,
      targetLanguage: json['targetLanguage'] as String,
      paragraphsJson: (json['paragraphs'] as List?)?.cast<Map<String, dynamic>>() ?? [],
      createdAt: DateTime.parse(json['createdAt'] as String),
      durationMs: json['durationMs'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'sourceLanguage': sourceLanguage,
      'targetLanguage': targetLanguage,
      'paragraphs': paragraphsJson,
      'createdAt': createdAt.toIso8601String(),
      'durationMs': durationMs,
    };
  }

  TranslationSession toEntity() {
    return TranslationSession(
      id: id,
      name: name,
      sourceLanguage: sourceLanguage,
      targetLanguage: targetLanguage,
      paragraphs: paragraphsJson.map((p) => TranslationParagraph(
        id: p['id'] as String? ?? '',
        originalText: p['originalText'] as String,
        translatedText: p['translatedText'] as String,
        sourceLanguage: p['sourceLanguage'] as String? ?? '',
        targetLanguage: p['targetLanguage'] as String? ?? '',
        timestamp: DateTime.parse(p['timestamp'] as String),
      )).toList(),
      createdAt: createdAt,
      durationMs: durationMs,
    );
  }

  factory TranslationSessionModel.fromEntity(TranslationSession entity) {
    return TranslationSessionModel(
      id: entity.id,
      name: entity.name,
      sourceLanguage: entity.sourceLanguage,
      targetLanguage: entity.targetLanguage,
      paragraphsJson: entity.paragraphs.map((p) => {
        'id': p.id,
        'originalText': p.originalText,
        'translatedText': p.translatedText,
        'sourceLanguage': p.sourceLanguage,
        'targetLanguage': p.targetLanguage,
        'timestamp': p.timestamp.toIso8601String(),
      }).toList(),
      createdAt: entity.createdAt,
      durationMs: entity.durationMs,
    );
  }
}
