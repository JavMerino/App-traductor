import 'dart:async';
import 'package:audio_traductor/core/errors/failures.dart';
import 'package:audio_traductor/features/translation/data/datasources/google_stt_datasource.dart';
import 'package:audio_traductor/features/translation/data/datasources/google_translate_datasource.dart';
import 'package:audio_traductor/features/translation/data/datasources/google_tts_datasource.dart';
import 'package:audio_traductor/features/translation/data/datasources/translation_local_datasource.dart';
import 'package:audio_traductor/features/translation/data/models/translation_session_model.dart';
import 'package:audio_traductor/features/translation/domain/entities/translation_paragraph.dart';
import 'package:audio_traductor/features/translation/domain/entities/translation_session.dart';
import 'package:audio_traductor/features/translation/domain/repositories/translation_repository.dart';
import 'package:dartz/dartz.dart';
import 'package:uuid/uuid.dart';
import 'package:intl/intl.dart';

class TranslationRepositoryImpl implements TranslationRepository {
  final SttDatasource _stt;
  final TranslateDatasource _translate;
  final TtsDatasource _tts;
  final TranslationLocalDatasource _local;

  StreamSubscription<SttResult>? _sttSubscription;
  StreamController<TranslationChunk>? _chunkController;
  List<TranslationParagraph> _paragraphs = [];
  final _uuid = const Uuid();
  int _startTimeMs = 0;
  String _sourceLanguage = 'es';
  String _targetLanguage = 'en';
  String _currentSessionId = '';
  String _sessionName = '';
  double _speed = 0.5;
  Future<void>? _ttsQueue; // encadena reproducciones TTS

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
    required double speed,
    String? existingSessionId,
    String? sessionName,
  }) async* {
    _startTimeMs = DateTime.now().millisecondsSinceEpoch;
    _chunkController = StreamController<TranslationChunk>.broadcast();
    _sourceLanguage = sourceLanguage;
    _targetLanguage = targetLanguage;
    _speed = speed;

    // Guardar nombre personalizado
    _sessionName = sessionName ?? 'Sesión ${DateFormat('dd/MM HH:mm').format(DateTime.now())}';

    // Manejar sesión
    if (existingSessionId != null && existingSessionId != '_new_') {
      // Continuar sesión existente
      _currentSessionId = existingSessionId;
      final existing = await _local.getSession(existingSessionId);
      _paragraphs = existing?.toEntity().paragraphs ?? [];
    } else {
      // Nueva sesión
      _currentSessionId = _uuid.v4();
      _paragraphs = [];
    }

    final sttStream = _stt.startStreaming(
      audioStream: const Stream.empty(),
      languageCode: sourceLanguage,
    );

    _sttSubscription = sttStream.listen(
      (sttResult) async {
        if (sttResult.transcript.isEmpty) return;

        try {
          final translateResult = await _translate.translate(
            text: sttResult.transcript,
            sourceLanguage: sourceLanguage,
            targetLanguage: targetLanguage,
          );

          if (sttResult.isFinal) {
            // Encadenar reproducción: esperar a que termine la anterior
            _ttsQueue = (_ttsQueue ?? Future.value()).then((_) {
              return _tts.synthesize(
                text: translateResult.translatedText,
                voiceName: voiceName,
                languageCode: targetLanguage,
                speed: _speed,
              );
            }).catchError((_) => const TtsResult(audioBase64: '', audioFormat: ''));

            _paragraphs.add(TranslationParagraph(
              id: 'p${_paragraphs.length + 1}',
              originalText: sttResult.transcript,
              translatedText: translateResult.translatedText,
              sourceLanguage: sourceLanguage,
              targetLanguage: targetLanguage,
              timestamp: DateTime.now(),
            ));
            _persistCurrentSession();
          }

          _chunkController?.add(TranslationChunk(
            originalText: sttResult.transcript,
            translatedText: translateResult.translatedText,
            isFinal: sttResult.isFinal,
          ));
        } catch (e) {
          _chunkController?.addError(e);
        }
      },
      onError: (e) => _chunkController?.addError(e),
      onDone: () => _chunkController?.close(),
    );

    yield* _chunkController!.stream;
  }

  Future<void> _persistCurrentSession() async {
    final session = TranslationSession(
      id: _currentSessionId,
      name: _sessionName,
      sourceLanguage: _sourceLanguage,
      targetLanguage: _targetLanguage,
      paragraphs: List.from(_paragraphs),
      createdAt: DateTime.now(),
      durationMs: DateTime.now().millisecondsSinceEpoch - _startTimeMs,
    );
    await _local.saveSession(TranslationSessionModel.fromEntity(session));
  }

  @override
  Future<Either<Failure, TranslationSession>> stopTranslation() async {
    try {
      // 1. Detener el micrófono — no más párrafos nuevos
      await _stt.stop();
      await _sttSubscription?.cancel();
      _sttSubscription = null;

      // 2. Esperar a que termine toda la cola de TTS (máx 15s)
      if (_ttsQueue != null) {
        try {
          await _ttsQueue!.timeout(const Duration(seconds: 15));
        } catch (_) {
          // Timeout o error — seguimos igual, no bloqueamos
        }
        _ttsQueue = null;
      }

      final durationMs = DateTime.now().millisecondsSinceEpoch - _startTimeMs;

      final saved = await _local.getSession(_currentSessionId);
      final session = saved?.toEntity() ?? TranslationSession(
        id: _currentSessionId,
        sourceLanguage: _sourceLanguage,
        targetLanguage: _targetLanguage,
        paragraphs: List.from(_paragraphs),
        createdAt: DateTime.now(),
        durationMs: durationMs,
      );

      _paragraphs = [];
      return Right(session);
    } on Exception catch (e) {
      return Left(UnexpectedFailure(message: 'Error al detener', originalError: e));
    }
  }

  @override
  Future<Either<Failure, TranslationSession?>> getSession(String id) async {
    try {
      final model = await _local.getSession(id);
      return Right(model?.toEntity());
    } on Exception catch (e) {
      return Left(StorageFailure(message: 'Error al obtener sesión', originalError: e as Object?));
    }
  }

  @override
  Future<Either<Failure, List<TranslationSession>>> getHistory() async {
    try {
      final models = await _local.getAllSessions();
      return Right(models.map((m) => m.toEntity()).toList());
    } on Exception catch (e) {
      return Left(StorageFailure(message: 'Error al obtener historial', originalError: e as Object?));
    }
  }

  @override
  Future<Either<Failure, void>> deleteSession(String sessionId) async {
    try {
      await _local.deleteSession(sessionId);
      return const Right(null);
    } on Exception catch (e) {
      return Left(StorageFailure(message: 'Error al eliminar', originalError: e as Object?));
    }
  }

  @override
  Future<Either<Failure, void>> clearHistory() async {
    try {
      await _local.clearAll();
      return const Right(null);
    } on Exception catch (e) {
      return Left(StorageFailure(message: 'Error al limpiar', originalError: e as Object?));
    }
  }
}
