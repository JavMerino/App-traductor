import 'package:audio_traductor/core/constants/app_constants.dart';
import 'package:audio_traductor/core/services/bluetooth_provider.dart';
import 'package:audio_traductor/features/translation/presentation/providers/translation_provider.dart';
import 'package:audio_traductor/features/translation/presentation/providers/audio_settings_provider.dart';
import 'package:audio_traductor/features/translation/presentation/widgets/language_selector.dart';
import 'package:audio_traductor/features/translation/presentation/widgets/recording_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(translationProvider);
    final settings = ref.watch(audioSettingsProvider);
    final bt = ref.watch(bluetoothProvider);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text(AppConstants.appName),
        actions: [
          if (bt.connectedDevice != null)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Tooltip(
                message: 'BT: ${bt.connectedDevice!.name}',
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 8, height: 8,
                      decoration: BoxDecoration(
                        color: Colors.greenAccent,
                        shape: BoxShape.circle,
                        boxShadow: [BoxShadow(color: Colors.greenAccent.withValues(alpha: 0.6), blurRadius: 4)],
                      ),
                    ),
                    const SizedBox(width: 6),
                    Icon(Icons.bluetooth_connected, size: 18, color: colorScheme.primary),
                  ],
                ),
              ),
            ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // ── Selectores de idioma ──
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  Expanded(
                    child: LanguageSelector(
                      label: 'Idioma de entrada',
                      selectedCode: settings.sourceLanguage,
                      selectedName: settings.sourceLanguageName,
                      onChanged: (lang) => ref.read(audioSettingsProvider.notifier).setSourceLanguage(lang.code, lang.name),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Icon(Icons.arrow_forward, color: colorScheme.primary),
                  ),
                  Expanded(
                    child: LanguageSelector(
                      label: 'Idioma de salida',
                      selectedCode: settings.targetLanguage,
                      selectedName: settings.targetLanguageName,
                      onChanged: (lang) => ref.read(audioSettingsProvider.notifier).setTargetLanguage(lang.code, lang.name),
                    ),
                  ),
                ],
              ),
            ),

            // ── Botón de grabación ──
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Column(
                children: [
                  RecordingButton(
                    isStreaming: state.isStreaming,
                    onStart: () => ref.read(translationProvider.notifier).startTranslation(
                      sourceLanguage: settings.sourceLanguage,
                      targetLanguage: settings.targetLanguage,
                      voiceName: settings.voiceName,
                    ),
                    onStop: () => ref.read(translationProvider.notifier).stopTranslation(),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    switch (state.status) {
                      TranslationStatus.idle => 'Toca para empezar',
                      TranslationStatus.listening => 'Escuchando...',
                      TranslationStatus.translating => 'Traduciendo...',
                      TranslationStatus.playing => 'Reproduciendo...',
                      TranslationStatus.error => 'Error',
                    },
                    style: theme.textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant),
                  ),
                ],
              ),
            ),

            // ── Párrafos traducidos ──
            if (state.paragraphs.isNotEmpty)
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  itemCount: state.paragraphs.length,
                  itemBuilder: (context, index) {
                    final p = state.paragraphs[index];
                    final isPlaying = state.playingParagraphId == p.id;
                    return _ParagraphCard(
                      paragraph: p,
                      number: index + 1,
                      isPlaying: isPlaying,
                      onPlay: () => ref.read(translationProvider.notifier).playParagraph(p.id),
                    );
                  },
                ),
              ),

            // ── Error ──
            if (state.errorMessage != null)
              Padding(
                padding: const EdgeInsets.all(12),
                child: Card(
                  color: colorScheme.errorContainer,
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      children: [
                        Icon(Icons.error_outline, color: colorScheme.onErrorContainer),
                        const SizedBox(width: 8),
                        Expanded(child: Text(state.errorMessage!, style: TextStyle(color: colorScheme.onErrorContainer))),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Tarjeta de un párrafo: original + traducción + botón play.
class _ParagraphCard extends StatelessWidget {
  final TranslationParagraph paragraph;
  final int number;
  final bool isPlaying;
  final VoidCallback onPlay;

  const _ParagraphCard({
    required this.paragraph,
    required this.number,
    required this.isPlaying,
    required this.onPlay,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Número de párrafo
            Container(
              width: 24, height: 24,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: colorScheme.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text('$number', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: colorScheme.primary)),
            ),
            const SizedBox(width: 10),

            // Textos
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Original (muted, chico)
                  Text(paragraph.originalText,
                    style: theme.textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant),
                    maxLines: 2, overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  // Traducción
                  Text(paragraph.translatedText,
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: colorScheme.primary),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),

            // Botón play
            SizedBox(
              width: 40, height: 40,
              child: IconButton(
                onPressed: onPlay,
                icon: Icon(
                  isPlaying ? Icons.volume_up : Icons.play_arrow_rounded,
                  color: isPlaying ? colorScheme.primary : colorScheme.onSurfaceVariant,
                  size: 24,
                ),
                style: IconButton.styleFrom(
                  backgroundColor: isPlaying ? colorScheme.primaryContainer : null,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
