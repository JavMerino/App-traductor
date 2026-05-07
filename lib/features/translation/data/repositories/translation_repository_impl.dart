import 'dart:async';
import 'package:audio_traductor/core/errors/failures.dart';
import 'package:audio_traductor/features/translation/data/datasources/google_stt_datasource.dart';
import 'package:audio_traductor/features/translation/data/datasources/google_translate_datasource.dart';
import 'package:audio_traductor/features/translation/data/datasources/google_tts_datasource.dart';
import 'package:audio_traductor/features/translation/data/datasources/translation_local_datasource.dart';
import 'package:audio_traductor/features/translation/data/models/translation_session_model.dart';
import 'package:audio_traductor/features/translation/domain/entities/translation_session.dart';
import 'package:audio_traductor/features/translation/domain/repositories/translation_repository.dart';
import 'package:dartz/dartz.dart';
import 'package:uuid/uuid.dart';

/// Pipeline real: STT (speech_to_text) → Translate (Google) → TTS (flutter_tts)
class TranslationRepositoryImpl implements TranslationRepository {
  final SttDatasource _stt;
  final TranslateDatasource _translate;
  final TtsDatasource _tts;
  final TranslationLocalDatasource _local;

  StreamSubscription<SttResult>? _sttSubscription;
  StreamController<TranslationChunk>? _chunkController;
  final _pendingTexts = <String>[];
  final _uuid = const Uuid();
  int _startTimeMs = 0;
  String _sourceLanguage = 'es';
  String _targetLanguage = 'en';

  TranslationRepositoryImpl({
    required SttDatasource stt,
    required TranslateDatasource translate,
    required TtsDatasource tts,
    required TranslationLocalDatasource local,
  })  : _stt = stt,
        _translate = translate,
        _tts = tts,
        _local = local;

  @override
  Stream<TranslationChunk> startTranslation({
    required String sourceLanguage,
    required String targetLanguage,
    required String voiceName,
  }) async* {
    _startTimeMs = DateTime.now().millisecondsSinceEpoch;
    _chunkController = StreamController<TranslationChunk>.broadcast();
    _sourceLanguage = sourceLanguage;
    _targetLanguage = targetLanguage;

    final sttStream = _stt.startStreaming(
      audioStream: const Stream.empty(),
      languageCode: sourceLanguage,
    );

    _sttSubscription = sttStream.listen(
      (sttResult) async {
        if (sttResult.transcript.isEmpty) return;

        _pendingTexts.add(sttResult.transcript);

        try {
          // 1. Traducir
          final translateResult = await _translate.translate(
            text: sttResult.transcript,
            sourceLanguage: sourceLanguage,
            targetLanguage: targetLanguage,
          );

          // 2. Sintetizar y reproducir voz (solo resultados finales)
          if (sttResult.isFinal) {
            unawaited(_tts.synthesize(
              text: translateResult.translatedText,
              voiceName: voiceName,
              languageCode: targetLanguage,
            ));
          }

          // 3. Emitir chunk a la UI
          _chunkController?.add(TranslationChunk(
            originalText: sttResult.transcript,
            translatedText: translateResult.translatedText,
            isFinal: sttResult.isFinal,
          ));
        } catch (e) {
          _chunkController?.addError(e);
        }
      },
      onError: (error) => _chunkController?.addError(error),
      onDone: () => _chunkController?.close(),
    );

    yield* _chunkController!.stream;
  }

  @override
  Future<Either<Failure, TranslationSession>> stopTranslation() async {
    try {
      await _stt.stop();
      await _sttSubscription?.cancel();
      _sttSubscription = null;

      final durationMs =
          DateTime.now().millisecondsSinceEpoch - _startTimeMs;

      final fullOriginal = _pendingTexts.join(' ');

      final session = TranslationSession(
        id: _uuid.v4(),
        sourceLanguage: _sourceLanguage,
        targetLanguage: _targetLanguage,
        originalText: fullOriginal,
        translatedText: '[Traducción] $fullOriginal',
        createdAt: DateTime.now(),
        durationMs: durationMs,
      );

      final model = TranslationSessionModel.fromEntity(session);
      await _local.saveSession(model);
      _pendingTexts.clear();

      return Right(session);
    } on Exception catch (e) {
      return Left(
        UnexpectedFailure(
          message: 'Error al detener traducción',
          originalError: e,
        ),
      );
    }
  }

  @override
  Future<Either<Failure, List<TranslationSession>>> getHistory() async {
    try {
      final models = await _local.getAllSessions();
      final sessions = models.map((m) => m.toEntity()).toList();
      return Right(sessions);
    } on Exception catch (e) {
      return Left(
        StorageFailure(
          message: 'Error al obtener historial',
          originalError: e as Object?,
        ),
      );
    }
  }

  @override
  Future<Either<Failure, void>> deleteSession(String sessionId) async {
    try {
      await _local.deleteSession(sessionId);
      return const Right(null);
    } on Exception catch (e) {
      return Left(
        StorageFailure(
          message: 'Error al eliminar sesión',
          originalError: e as Object?,
        ),
      );
    }
  }

  @override
  Future<Either<Failure, void>> clearHistory() async {
    try {
      await _local.clearAll();
      return const Right(null);
    } on Exception catch (e) {
      return Left(
        StorageFailure(
          message: 'Error al limpiar historial',
          originalError: e as Object?,
        ),
      );
    }
  }
}
