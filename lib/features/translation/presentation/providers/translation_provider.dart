import 'dart:async';
import 'package:audio_traductor/core/di/injection_container.dart';
import 'package:audio_traductor/features/translation/data/datasources/google_tts_datasource.dart';
import 'package:audio_traductor/features/translation/domain/entities/translation_paragraph.dart';
import 'package:audio_traductor/features/translation/domain/entities/translation_session.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

enum TranslationStatus { idle, listening, translating, playing, error }

class TranslationState {
  final TranslationStatus status;
  final List<TranslationParagraph> paragraphs;
  final String? errorMessage;
  final bool isStreaming;
  final String? playingParagraphId;
  final String? currentSessionId;
  final String sessionName;

  const TranslationState({
    this.status = TranslationStatus.idle,
    this.paragraphs = const [],
    this.errorMessage,
    this.isStreaming = false,
    this.playingParagraphId,
    this.currentSessionId,
    this.sessionName = '',
  });

  TranslationState copyWith({
    TranslationStatus? status,
    List<TranslationParagraph>? paragraphs,
    String? errorMessage,
    bool? isStreaming,
    String? playingParagraphId,
    String? currentSessionId,
    String? sessionName,
  }) {
    return TranslationState(
      status: status ?? this.status,
      paragraphs: paragraphs ?? this.paragraphs,
      errorMessage: errorMessage,
      isStreaming: isStreaming ?? this.isStreaming,
      playingParagraphId: playingParagraphId,
      currentSessionId: currentSessionId,
      sessionName: sessionName ?? this.sessionName,
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

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
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

    _counter = 0;
    _currentTargetLanguage = targetLanguage;
    _currentVoiceName = voiceName;
    _currentSpeed = speed;
    state = state.copyWith(
      status: TranslationStatus.listening,
      isStreaming: true,
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
    await _subscription?.cancel();
    _subscription = null;
    final result = await InjectionContainer.stopTranslation();
    result.fold(
      (failure) => state = state.copyWith(status: TranslationStatus.error, errorMessage: failure.message, isStreaming: false),
      (session) => state = state.copyWith(
        status: TranslationStatus.idle,
        isStreaming: false,
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
