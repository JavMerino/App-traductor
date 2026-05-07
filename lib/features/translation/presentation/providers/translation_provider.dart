import 'dart:async';
import 'package:audio_traductor/core/di/injection_container.dart';
import 'package:audio_traductor/features/translation/data/datasources/google_tts_datasource.dart';
import 'package:audio_traductor/features/translation/domain/entities/translation_session.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Estado de la traducción en la UI.
enum TranslationStatus { idle, listening, translating, playing, error }

/// Un párrafo individual: lo que dijiste + su traducción.
class TranslationParagraph {
  final String id;
  final String originalText;
  final String translatedText;

  const TranslationParagraph({
    required this.id,
    required this.originalText,
    required this.translatedText,
  });
}

/// Estado completo de la pantalla de traducción.
class TranslationState {
  final TranslationStatus status;
  final List<TranslationParagraph> paragraphs;
  final String? errorMessage;
  final bool isStreaming;
  final String? playingParagraphId;

  const TranslationState({
    this.status = TranslationStatus.idle,
    this.paragraphs = const [],
    this.errorMessage,
    this.isStreaming = false,
    this.playingParagraphId,
  });

  TranslationState copyWith({
    TranslationStatus? status,
    List<TranslationParagraph>? paragraphs,
    String? errorMessage,
    bool? isStreaming,
    String? playingParagraphId,
  }) {
    return TranslationState(
      status: status ?? this.status,
      paragraphs: paragraphs ?? this.paragraphs,
      errorMessage: errorMessage,
      isStreaming: isStreaming ?? this.isStreaming,
      playingParagraphId: playingParagraphId,
    );
  }
}

/// Provider principal de la traducción.
class TranslationNotifier extends StateNotifier<TranslationState> {
  TranslationNotifier() : super(const TranslationState());

  StreamSubscription? _subscription;
  int _paragraphCounter = 0;

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  /// Inicia la escucha.
  Future<void> startTranslation({
    required String sourceLanguage,
    required String targetLanguage,
    required String voiceName,
  }) async {
    if (state.isStreaming) return;

    _paragraphCounter = 0;

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
      );

      _subscription = stream.listen(
        (chunk) {
          if (!chunk.isFinal) {
            // Resultado parcial — mostramos que está traduciendo
            state = state.copyWith(status: TranslationStatus.translating);
            return;
          }

          // Resultado final (pausa detectada) → agregar párrafo
          _paragraphCounter++;
          final paragraph = TranslationParagraph(
            id: 'p$_paragraphCounter',
            originalText: chunk.originalText,
            translatedText: chunk.translatedText,
          );

          state = state.copyWith(
            status: TranslationStatus.listening,
            paragraphs: [...state.paragraphs, paragraph],
          );
        },
        onError: (error) {
          state = state.copyWith(
            status: TranslationStatus.error,
            errorMessage: 'Error en la traducción: $error',
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

  /// Reproduce la traducción de un párrafo específico.
  Future<void> playParagraph(String paragraphId) async {
    final paragraph =
        state.paragraphs.firstWhere((p) => p.id == paragraphId);

    state = state.copyWith(
      status: TranslationStatus.playing,
      playingParagraphId: paragraphId,
    );

    // Fire & forget — no bloquea el pipeline
    unawaited(RealTtsDatasource.instance.synthesize(
      text: paragraph.translatedText,
      voiceName: '',
      languageCode: 'en',
    ).then((_) {
      // Volver al estado anterior cuando termina de hablar
      state = state.copyWith(
        status: state.isStreaming
            ? TranslationStatus.listening
            : TranslationStatus.idle,
        playingParagraphId: null,
      );
    }).catchError((_) {
      state = state.copyWith(
        status: state.isStreaming
            ? TranslationStatus.listening
            : TranslationStatus.idle,
        playingParagraphId: null,
      );
    }));
  }

  /// Detiene la escucha y guarda la sesión.
  Future<void> stopTranslation() async {
    await _subscription?.cancel();
    _subscription = null;

    final result = await InjectionContainer.stopTranslation();
    result.fold(
      (failure) {
        state = state.copyWith(
          status: TranslationStatus.error,
          errorMessage: failure.message,
          isStreaming: false,
        );
      },
      (session) {
        state = state.copyWith(
          status: TranslationStatus.idle,
          isStreaming: false,
        );
      },
    );
  }
}

final translationProvider =
    StateNotifierProvider<TranslationNotifier, TranslationState>((ref) {
  return TranslationNotifier();
});

final historyProvider = FutureProvider<List<TranslationSession>>((ref) async {
  final result = await InjectionContainer.getHistory();
  return result.fold(
    (failure) => throw failure,
    (sessions) => sessions,
  );
});

final deleteSessionProvider =
    FutureProvider.family<void, String>((ref, sessionId) async {
  final result = await InjectionContainer.deleteSession(sessionId);
  result.fold(
    (failure) => throw failure,
    (_) => null,
  );
});
