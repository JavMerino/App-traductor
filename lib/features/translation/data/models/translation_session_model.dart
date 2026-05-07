import 'package:audio_traductor/features/translation/domain/entities/translation_session.dart';

/// Modelo de [TranslationSession] para serialización/deserialización.
///
/// Sigue el patrón: Entity → Model ↔ JSON/Hive.
class TranslationSessionModel {
  final String id;
  final String sourceLanguage;
  final String targetLanguage;
  final String originalText;
  final String translatedText;
  final String? audioSourcePath;
  final String? audioOutputPath;
  final DateTime createdAt;
  final int durationMs;

  const TranslationSessionModel({
    required this.id,
    required this.sourceLanguage,
    required this.targetLanguage,
    required this.originalText,
    required this.translatedText,
    this.audioSourcePath,
    this.audioOutputPath,
    required this.createdAt,
    required this.durationMs,
  });

  /// Crea un modelo desde un mapa JSON.
  factory TranslationSessionModel.fromJson(Map<String, dynamic> json) {
    return TranslationSessionModel(
      id: json['id'] as String,
      sourceLanguage: json['sourceLanguage'] as String,
      targetLanguage: json['targetLanguage'] as String,
      originalText: json['originalText'] as String,
      translatedText: json['translatedText'] as String,
      audioSourcePath: json['audioSourcePath'] as String?,
      audioOutputPath: json['audioOutputPath'] as String?,
      createdAt: DateTime.parse(json['createdAt'] as String),
      durationMs: json['durationMs'] as int,
    );
  }

  /// Convierte a mapa JSON.
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'sourceLanguage': sourceLanguage,
      'targetLanguage': targetLanguage,
      'originalText': originalText,
      'translatedText': translatedText,
      'audioSourcePath': audioSourcePath,
      'audioOutputPath': audioOutputPath,
      'createdAt': createdAt.toIso8601String(),
      'durationMs': durationMs,
    };
  }

  /// Convierte a entidad del dominio.
  TranslationSession toEntity() {
    return TranslationSession(
      id: id,
      sourceLanguage: sourceLanguage,
      targetLanguage: targetLanguage,
      originalText: originalText,
      translatedText: translatedText,
      audioSourcePath: audioSourcePath,
      audioOutputPath: audioOutputPath,
      createdAt: createdAt,
      durationMs: durationMs,
    );
  }

  /// Crea un modelo desde una entidad.
  factory TranslationSessionModel.fromEntity(TranslationSession entity) {
    return TranslationSessionModel(
      id: entity.id,
      sourceLanguage: entity.sourceLanguage,
      targetLanguage: entity.targetLanguage,
      originalText: entity.originalText,
      translatedText: entity.translatedText,
      audioSourcePath: entity.audioSourcePath,
      audioOutputPath: entity.audioOutputPath,
      createdAt: entity.createdAt,
      durationMs: entity.durationMs,
    );
  }
}
