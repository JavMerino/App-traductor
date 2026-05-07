import 'package:audio_traductor/core/errors/failures.dart';
import 'package:audio_traductor/features/translation/domain/entities/translation_session.dart';
import 'package:dartz/dartz.dart';

/// Contrato del repositorio de traducción.
///
/// El [TranslationRepository] es la frontera entre el dominio
/// y la capa de datos. Los casos de uso dependen de esta interfaz,
/// NO de implementaciones concretas.
abstract class TranslationRepository {
  /// Inicia una sesión de traducción en tiempo real.
  ///
  /// [sourceLanguage]: código del idioma origen (ej: 'es').
  /// [targetLanguage]: código del idioma destino (ej: 'en').
  /// [voiceName]: nombre de la voz TTS a usar.
  ///
  /// Devuelve un stream de fragmentos traducidos.
  Stream<TranslationChunk> startTranslation({
    required String sourceLanguage,
    required String targetLanguage,
    required String voiceName,
  });

  /// Detiene la sesión de traducción activa.
  Future<Either<Failure, TranslationSession>> stopTranslation();

  /// Obtiene el historial de traducciones.
  Future<Either<Failure, List<TranslationSession>>> getHistory();

  /// Elimina una sesión del historial.
  Future<Either<Failure, void>> deleteSession(String sessionId);

  /// Limpia todo el historial.
  Future<Either<Failure, void>> clearHistory();
}

/// Fragmento de una traducción en curso.
class TranslationChunk {
  final String originalText;
  final String translatedText;
  final bool isFinal; // true = chunk definitivo, false = parcial
  final String? audioBase64; // audio TTS en base64 (opcional)

  const TranslationChunk({
    required this.originalText,
    required this.translatedText,
    this.isFinal = false,
    this.audioBase64,
  });
}
