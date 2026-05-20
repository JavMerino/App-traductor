import 'dart:async';
import 'package:audio_traductor/core/di/injection_container.dart';
import 'package:audio_traductor/core/services/mic_passthrough_service.dart';
import 'package:audio_traductor/features/translation/data/datasources/google_tts_datasource.dart';
import 'package:audio_traductor/features/translation/domain/entities/translation_paragraph.dart';
import 'package:audio_traductor/features/translation/domain/entities/translation_session.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

enum TranslationStatus { idle, listening, translating, playing, error, downloadingModels }

class TranslationState {
  final TranslationStatus status;
  final List<TranslationParagraph> paragraphs;
  final String? errorMessage;
  final bool isStreaming;
  final String? playingParagraphId;
  final String? currentSessionId;
  final String sessionName;
  final bool micMode;
  final double downloadProgress;
  final String? downloadLanguage;

  const TranslationState({
    this.status = TranslationStatus.idle,
    this.paragraphs = const [],
    this.errorMessage,
    this.isStreaming = false,
    this.playingParagraphId,
    this.currentSessionId,
    this.sessionName = '',
    this.micMode = false,
    this.downloadProgress = 0.0,
    this.downloadLanguage,
  });

  TranslationState copyWith({
    TranslationStatus? status,
    List<TranslationParagraph>? paragraphs,
    String? errorMessage,
    bool? isStreaming,
    String? playingParagraphId,
    String? currentSessionId,
    String? sessionName,
    bool? micMode,
    double? downloadProgress,
    String? downloadLanguage,
  }) {
    return TranslationState(
      status: status ?? this.status,
      paragraphs: paragraphs ?? this.paragraphs,
      errorMessage: errorMessage,
      isStreaming: isStreaming ?? this.isStreaming,
      playingParagraphId: playingParagraphId,
      currentSessionId: currentSessionId,
      sessionName: sessionName ?? this.sessionName,
      micMode: micMode ?? this.micMode,
      downloadProgress: downloadProgress ?? this.downloadProgress,
      downloadLanguage: downloadLanguage ?? this.downloadLanguage,
    );
  }
}

class TranslationNotifier extends StateNotifier<TranslationState> {
  TranslationNotifier() : super(const TranslationState());

  StreamSubscription? _subscription;
  int _counter = 0;
  String _currentTargetLanguage = 'en';
  String _currentVoiceName = '';
  double _currentSpeed = 0.5;
  final MicPassthroughService _passthrough = MicPassthroughService();

  @override
  void dispose() {
    _subscription?.cancel();
    _passthrough.dispose();
    super.dispose();
  }

  void setMicMode(bool v) {
    state = state.copyWith(micMode: v);
  }

  Future<void> startTranslation({
    required String sourceLanguage,
    required String targetLanguage,
    required String voiceName,
    required double speed,
    String? existingSessionId,
    String? sessionName,
  }) async {
    if (state.isStreaming) return;

    // Asegurar que no quede ningún subscription colgado
    await _subscription?.cancel();
    _subscription = null;

    _counter = 0;
    _currentTargetLanguage = targetLanguage;
    _currentVoiceName = voiceName;
    _currentSpeed = speed;

    // Modo micrófono: passthrough directo (sin traducción)
    if (state.micMode) {
      state = state.copyWith(
        status: TranslationStatus.listening,
        isStreaming: true,
        errorMessage: null,
      );
      await _passthrough.start();
      return;
    }

    // ── Verificar / descargar modelos de ML Kit ──
    final modelsReady = await InjectionContainer.areModelsDownloaded(
      sourceLanguage,
      targetLanguage,
    );

    if (!modelsReady) {
      state = state.copyWith(
        status: TranslationStatus.downloadingModels,
        isStreaming: false,
        downloadProgress: 0.0,
        downloadLanguage: null,
        paragraphs: [],
        errorMessage: null,
      );

      await InjectionContainer.downloadModels(
        source: sourceLanguage,
        target: targetLanguage,
        onProgress: (progress, lang) {
          state = state.copyWith(
            downloadProgress: progress,
            downloadLanguage: lang.isEmpty ? state.downloadLanguage : lang,
          );
        },
      );
    }

    state = state.copyWith(
      status: TranslationStatus.listening,
      isStreaming: true,
      downloadProgress: 0.0,
      downloadLanguage: null,
      paragraphs: [],
      errorMessage: null,
    );

    try {
      final stream = InjectionContainer.startTranslation(
        sourceLanguage: sourceLanguage,
        targetLanguage: targetLanguage,
        voiceName: voiceName,
        speed: speed,
        existingSessionId: existingSessionId,
        sessionName: sessionName,
      );

      _subscription = stream.listen(
        (chunk) {
          if (!chunk.isFinal) {
            state = state.copyWith(status: TranslationStatus.translating);
            return;
          }
          _counter++;
          state = state.copyWith(
            status: TranslationStatus.listening,
            paragraphs: [
              ...state.paragraphs,
              TranslationParagraph(
                id: 'p$_counter',
                originalText: chunk.originalText,
                translatedText: chunk.translatedText,
                sourceLanguage: sourceLanguage,
                targetLanguage: targetLanguage,
                timestamp: DateTime.now(),
              ),
            ],
          );
        },
        onError: (error) {
          state = state.copyWith(
            status: TranslationStatus.error,
            errorMessage: 'Error: $error',
            isStreaming: false,
          );
        },
      );
    } catch (e) {
      state = state.copyWith(
        status: TranslationStatus.error,
        errorMessage: 'Error al iniciar: $e',
        isStreaming: false,
      );
    }
  }

  void setSessionInfo(String id, String name) {
    state = state.copyWith(currentSessionId: id, sessionName: name);
  }

  void clearVisibleParagraphs() {
    if (state.paragraphs.isEmpty) return;
    state = state.copyWith(paragraphs: [], playingParagraphId: null);
  }

  Future<void> playParagraph(String paragraphId) async {
    final p = state.paragraphs.firstWhere((p) => p.id == paragraphId);
    state = state.copyWith(status: TranslationStatus.playing, playingParagraphId: paragraphId);

    unawaited(RealTtsDatasource.instance.synthesize(
      text: p.translatedText,
      voiceName: _currentVoiceName,
      languageCode: _currentTargetLanguage,
      speed: _currentSpeed,
    ).then((_) => _afterPlay()).catchError((_) => _afterPlay()));
  }

  void _afterPlay() {
    state = state.copyWith(
      status: state.isStreaming ? TranslationStatus.listening : TranslationStatus.idle,
      playingParagraphId: null,
    );
  }

  Future<void> stopTranslation() async {
    // 1. Cortar audio inmediatamente
    RealTtsDatasource.instance.stop();

    // 2. Cancelar listener del stream de chunks ANTES de tocar el estado
    // (si un chunk llega entre el idle y la cancelación, revierte el estado)
    await _subscription?.cancel();
    _subscription = null;

    // 3. Pasar a idle
    state = state.copyWith(
      status: TranslationStatus.idle,
      isStreaming: false,
      downloadProgress: 0.0,
      downloadLanguage: null,
    );

    // Modo micrófono: solo detener passthrough
    if (state.micMode) {
      await _passthrough.stop();
      return;
    }

    // Detener el repo (STT, TTS queue, persistir sesión)
    final result = await InjectionContainer.stopTranslation();
    result.fold(
      (failure) => state = state.copyWith(errorMessage: failure.message),
      (session) => state = state.copyWith(
        currentSessionId: session.id,
        sessionName: session.name,
      ),
    );
  }
}

final translationProvider = StateNotifierProvider<TranslationNotifier, TranslationState>((ref) {
  return TranslationNotifier();
});

final historyProvider = FutureProvider<List<TranslationSession>>((ref) async {
  final result = await InjectionContainer.getHistory();
  return result.fold((failure) => throw failure, (s) => s);
});

final deleteSessionProvider = FutureProvider.family<void, String>((ref, id) async {
  await InjectionContainer.deleteSession(id);
});
