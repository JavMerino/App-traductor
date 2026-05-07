import 'package:equatable/equatable.dart';
import 'package:intl/intl.dart';

/// Una sesión completa de traducción.
///
/// Contiene el texto original, la traducción y metadatos.
/// Se persiste en el historial.
class TranslationSession extends Equatable {
  final String id;
  final String sourceLanguage;
  final String targetLanguage;
  final String originalText;
  final String translatedText;
  final String? audioSourcePath;
  final String? audioOutputPath;
  final DateTime createdAt;
  final int durationMs;

  const TranslationSession({
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

  @override
  List<Object?> get props => [
        id,
        sourceLanguage,
        targetLanguage,
        originalText,
        translatedText,
        audioSourcePath,
        audioOutputPath,
        createdAt,
        durationMs,
      ];

  /// Fecha formateada para mostrar en UI.
  String get formattedDate {
    final formatter = DateFormat('dd/MM/yyyy HH:mm');
    return formatter.format(createdAt);
  }

  /// Duración formateada.
  String get formattedDuration {
    final seconds = (durationMs / 1000).floor();
    final min = (seconds / 60).floor();
    final sec = seconds % 60;
    return '${min}m ${sec}s';
  }
}
