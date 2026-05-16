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
  Future<void>? _showQueue; // cola A: traduce → muestra (orden estricto)
  Future<void>? _ttsQueue; // cola B: audio (orden estricto, independiente de A)
  bool _stopped = false;
  int _nextSequence = 0;
  int _nextToFlush = 0;
  final Map<int, _QueuedParagraph> _readyParagraphs = {};

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
    // Resetear estado por si venimos de una sesión anterior
    _stopped = false;
    _showQueue = null;
    _ttsQueue = null;
    _sttSubscription = null;
    _chunkController = null;
    _paragraphs = [];
    _nextSequence = 0;
    _nextToFlush = 0;
    _readyParagraphs.clear();

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
      (sttResult) {
        if (sttResult.transcript.isEmpty || _stopped) return;

        // Solo traducir cuando el STT confirma que es final.
        if (!sttResult.isFinal) {
          _chunkController?.add(TranslationChunk(
            originalText: sttResult.transcript,
            translatedText: '',
            isFinal: false,
          ));
          return;
        }

        final sequence = _nextSequence++;

        // La traducción puede correr en paralelo, PERO el mostrado y el audio
        // se respetan por orden de secuencia. Si el 3 termina antes que el 2,
        // se guarda y espera a que el 2 esté listo.
        unawaited(_translate.translate(
          text: sttResult.transcript,
          sourceLanguage: sourceLanguage,
          targetLanguage: targetLanguage,
        ).then((translateResult) {
          if (_stopped) return;

          _readyParagraphs[sequence] = _QueuedParagraph(
            originalText: sttResult.transcript,
            translatedText: translateResult.translatedText,
            sourceLanguage: sourceLanguage,
            targetLanguage: targetLanguage,
            timestamp: DateTime.now(),
          );

          _showQueue = (_showQueue ?? Future.value()).then((_) async {
            while (!_stopped && _readyParagraphs.containsKey(_nextToFlush)) {
              final item = _readyParagraphs.remove(_nextToFlush)!;

              _paragraphs.add(TranslationParagraph(
                id: 'p${_paragraphs.length + 1}',
                originalText: item.originalText,
                translatedText: item.translatedText,
                sourceLanguage: item.sourceLanguage,
                targetLanguage: item.targetLanguage,
                timestamp: item.timestamp,
              ));
              await _persistCurrentSession();

              _chunkController?.add(TranslationChunk(
                originalText: item.originalText,
                translatedText: item.translatedText,
                isFinal: true,
              ));

              _ttsQueue = (_ttsQueue ?? Future.value()).then((_) async {
                if (_stopped) return;
                await _tts.synthesize(
                  text: item.translatedText,
                  voiceName: voiceName,
                  languageCode: targetLanguage,
                  speed: _speed,
                );
              }).catchError((_) {});

              _nextToFlush++;
            }
          }).catchError((_) {});
        }).catchError((_) {}));
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
      // Marcar como detenido ANTES de cancelar, así los callbacks
      // async pendientes ven la bandera y no procesan nada más.
      _stopped = true;

      // 1. Detener el micrófono — no más párrafos nuevos
      await _stt.stop();
      await _sttSubscription?.cancel();
      _sttSubscription = null;

      // 2. Cerrar el controller del chunk stream para que nadie más escuche
      await _chunkController?.close();
      _chunkController = null;

      // 3. Cortar TTS en curso y limpiar colas
      _tts.stop();
      _showQueue = null;
      _ttsQueue = null;
      _readyParagraphs.clear();
      _nextSequence = 0;
      _nextToFlush = 0;

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

class _QueuedParagraph {
  final String originalText;
  final String translatedText;
  final String sourceLanguage;
  final String targetLanguage;
  final DateTime timestamp;

  const _QueuedParagraph({
    required this.originalText,
    required this.translatedText,
    required this.sourceLanguage,
    required this.targetLanguage,
    required this.timestamp,
  });
}
