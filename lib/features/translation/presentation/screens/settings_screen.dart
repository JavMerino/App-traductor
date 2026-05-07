import 'package:audio_traductor/features/translation/presentation/providers/audio_settings_provider.dart';
import 'package:audio_traductor/features/translation/presentation/providers/theme_provider.dart';
import 'package:audio_traductor/features/translation/presentation/widgets/audio_devices_panel.dart';
import 'package:audio_traductor/features/translation/presentation/widgets/color_selector.dart';
import 'package:audio_traductor/features/translation/presentation/widgets/voice_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Pantalla de configuración de la aplicación.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final settings = ref.watch(audioSettingsProvider);
    final themeMode = ref.watch(themeModeProvider);
    final seedColor = ref.watch(seedColorProvider);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Configuración'),
      ),
      body: ListView(
        children: [
          // ── Apariencia ──
          _SectionHeader(title: 'Apariencia'),
          Card(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: SwitchListTile(
              secondary: Icon(
                isDark ? Icons.dark_mode : Icons.light_mode,
                color: colorScheme.primary,
              ),
              title: const Text('Modo oscuro'),
              subtitle: Text(
                themeMode == ThemeMode.system
                    ? (isDark ? 'Siguiendo al sistema (oscuro)' : 'Siguiendo al sistema (claro)')
                    : (isDark ? 'Activado' : 'Desactivado'),
              ),
              value: isDark,
              onChanged: (value) {
                ref.read(themeModeProvider.notifier).setThemeMode(
                      value ? ThemeMode.dark : ThemeMode.light,
                    );
              },
            ),
          ),
          // ── Selector de color acento ──
          Card(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.palette_outlined, size: 18, color: colorScheme.primary),
                      const SizedBox(width: 8),
                      Text(
                        'Color de acento',
                        style: theme.textTheme.titleSmall,
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  ColorSelector(
                    selectedColor: seedColor,
                    onChanged: (color) {
                      ref.read(seedColorProvider.notifier).setColor(color);
                    },
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // ── Voz de salida ──
          _SectionHeader(title: 'Voz de salida'),
          Card(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Seleccionar voz',
                    style: theme.textTheme.titleSmall,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Voz actual: ${settings.voiceDisplayName}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 12),
                  VoiceSelector(
                    languageCode: settings.targetLanguage,
                    selectedVoiceName: settings.voiceName,
                    onChanged: (voice) {
                      ref.read(audioSettingsProvider.notifier).setVoice(
                            voice.name,
                            voice.displayName,
                          );
                    },
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // ── Audio ──
          _SectionHeader(title: 'Audio'),
          Card(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.volume_up),
                  title: const Text('Volumen'),
                  subtitle: Slider(
                    value: settings.volume,
                    min: 0.0,
                    max: 1.0,
                    divisions: 10,
                    label: '${(settings.volume * 100).round()}%',
                    onChanged: (value) {
                      ref.read(audioSettingsProvider.notifier).setVolume(value);
                    },
                  ),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.speed),
                  title: const Text('Velocidad'),
                  subtitle: Slider(
                    value: settings.speed,
                    min: 0.5,
                    max: 2.0,
                    divisions: 15,
                    label: '${settings.speed}x',
                    onChanged: (value) {
                      ref.read(audioSettingsProvider.notifier).setSpeed(value);
                    },
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // ── Dispositivos de audio ──
          _SectionHeader(title: 'Dispositivos de audio'),
          Card(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.speaker_group, size: 18, color: colorScheme.primary),
                      const SizedBox(width: 8),
                      Text('Entrada y salida', style: theme.textTheme.titleSmall),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const AudioDevicesPanel(),
                ],
              ),
            ),
          ),

          // ── Info ──
          const SizedBox(height: 24),
          Center(
            child: Text(
              'Audio Traductor v1.0.0',
              style: theme.textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;

  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
      child: Text(
        title,
        style: theme.textTheme.titleSmall?.copyWith(
          fontWeight: FontWeight.w600,
          color: theme.colorScheme.primary,
        ),
      ),
    );
  }
}
