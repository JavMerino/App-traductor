import 'package:audio_traductor/core/constants/app_constants.dart';
import 'package:audio_traductor/core/services/audio_device_manager.dart';
import 'package:audio_traductor/core/services/bluetooth_provider.dart';
import 'package:audio_traductor/features/translation/domain/entities/language.dart';
import 'package:audio_traductor/features/translation/domain/entities/translation_paragraph.dart';
import 'package:audio_traductor/features/translation/domain/entities/translation_session.dart';
import 'package:audio_traductor/features/translation/presentation/providers/translation_provider.dart';
import 'package:audio_traductor/features/translation/presentation/providers/audio_settings_provider.dart';
import 'package:audio_traductor/features/translation/presentation/screens/history_screen.dart';
import 'package:audio_traductor/features/translation/presentation/widgets/language_selector.dart';
import 'package:audio_traductor/features/translation/presentation/widgets/recording_button.dart';
import 'package:audio_traductor/features/translation/presentation/screens/settings_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(translationProvider);
    final settings = ref.watch(audioSettingsProvider);
    final bt = ref.watch(bluetoothProvider);
    final devices = ref.watch(audioDevicesProvider);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      resizeToAvoidBottomInset: false,
      appBar: AppBar(
        title: const Text(AppConstants.appName),
        actions: [
          // ── Indicador Bluetooth minimalista ──
          Padding(
            padding: const EdgeInsets.only(right: 4),
            child: Tooltip(
              message: bt.isAdapterOn
                  ? (bt.connectedDevice != null ? 'BT: ${bt.connectedDevice!.name}' : 'Bluetooth activado')
                  : 'Bluetooth desactivado',
              child: Icon(
                Icons.bluetooth,
                size: 20,
                color: bt.isAdapterOn
                    ? (bt.connectedDevice != null ? colorScheme.primary : colorScheme.onSurfaceVariant)
                    : colorScheme.onSurfaceVariant.withValues(alpha: 0.25),
              ),
            ),
          ),
          if (bt.connectedDevice != null)
            Container(width: 6, height: 6,
              margin: const EdgeInsets.only(right: 8),
              decoration: BoxDecoration(
                color: Colors.greenAccent, shape: BoxShape.circle,
                boxShadow: [BoxShadow(color: Colors.greenAccent.withValues(alpha: 0.6), blurRadius: 3)],
              ),
            ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // ── Selectores de idioma (bloqueados durante grabación o mic mode) ──
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: IgnorePointer(
                ignoring: state.isStreaming || state.micMode,
                child: AnimatedOpacity(
                  opacity: (state.isStreaming || state.micMode) ? 0.4 : 1.0,
                  duration: const Duration(milliseconds: 200),
                  child: Row(
                    children: [
                      Expanded(child: LanguageSelector(
                        label: 'Idioma de entrada',
                        selectedCode: settings.sourceLanguage,
                        selectedName: settings.sourceLanguageName,
                        excludeCode: settings.targetLanguage,
                        onChanged: (l) => ref.read(audioSettingsProvider.notifier).setSourceLanguage(l.code, l.name),
                      )),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 2),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(8),
                          onTap: (state.isStreaming || state.micMode) ? null : () {
                            final srcCode = settings.sourceLanguage;
                            final srcName = settings.sourceLanguageName;
                            final tgtCode = settings.targetLanguage;
                            final tgtName = settings.targetLanguageName;
                            ref.read(audioSettingsProvider.notifier).setSourceLanguage(tgtCode, tgtName);
                            ref.read(audioSettingsProvider.notifier).setTargetLanguage(srcCode, srcName);
                          },
                          child: Padding(
                            padding: const EdgeInsets.all(6),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.arrow_back, size: 14, color: colorScheme.primary),
                                Icon(Icons.arrow_forward, size: 14, color: colorScheme.primary),
                              ],
                            ),
                          ),
                        ),
                      ),
                      Expanded(child: LanguageSelector(
                        label: 'Idioma de salida',
                        selectedCode: settings.targetLanguage,
                        selectedName: settings.targetLanguageName,
                        excludeCode: settings.sourceLanguage,
                        onChanged: (l) => ref.read(audioSettingsProvider.notifier).setTargetLanguage(l.code, l.name),
                      )),
                    ],
                  ),
                ),
              ),
            ),

            // ── Selector de sesión (bloqueado durante grabación) ──
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: IgnorePointer(
                ignoring: state.isStreaming,
                child: AnimatedOpacity(
                  opacity: state.isStreaming ? 0.4 : 1.0,
                  duration: const Duration(milliseconds: 200),
                  child: InkWell(
                    onTap: () => _showSessionPicker(context, ref),
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                        border: Border.all(color: colorScheme.outlineVariant.withValues(alpha: 0.4)),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.folder_outlined, size: 18, color: colorScheme.primary),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              state.sessionName.isNotEmpty ? state.sessionName : 'Sesión sin nombre',
                              style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w500),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Icon(Icons.arrow_drop_down, color: colorScheme.onSurfaceVariant, size: 22),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),

            // ── Dispositivos de entrada/salida ──
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: IgnorePointer(
                ignoring: state.isStreaming,
                child: AnimatedOpacity(
                  opacity: state.isStreaming ? 0.4 : 1.0,
                  duration: const Duration(milliseconds: 200),
                  child: Row(
                    children: [
                      // Entrada
                      Expanded(
                        child: InkWell(
                          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsScreen())),
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 10),
                        decoration: BoxDecoration(
                          color: colorScheme.surface.withValues(alpha: 0.35),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: colorScheme.outlineVariant.withValues(alpha: 0.25)),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.mic, size: 16, color: colorScheme.primary),
                            const SizedBox(width: 8),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('ENTRADA', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: colorScheme.primary, letterSpacing: 1)),
                                Text(_deviceName(devices, devices.selectedInputId) ?? 'Micrófono del sistema',
                                    style: theme.textTheme.labelSmall?.copyWith(color: colorScheme.onSurfaceVariant), overflow: TextOverflow.ellipsis),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Salida
                  Expanded(
                    child: InkWell(
                      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsScreen())),
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 10),
                        decoration: BoxDecoration(
                          color: colorScheme.surface.withValues(alpha: 0.35),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: colorScheme.outlineVariant.withValues(alpha: 0.25)),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.speaker, size: 16, color: colorScheme.primary),
                            const SizedBox(width: 8),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('SALIDA', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: colorScheme.primary, letterSpacing: 1)),
                                Text(_deviceName(devices, devices.selectedOutputId) ?? 'Altavoces',
                                    style: theme.textTheme.labelSmall?.copyWith(color: colorScheme.onSurfaceVariant), overflow: TextOverflow.ellipsis),
                              ],
                            ),
                          ],
                        ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

            // ── Toggle micrófono (voz directa, sin traducción) ──
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Row(
                children: [
                  Icon(Icons.mic, size: 18, color: state.micMode ? colorScheme.primary : colorScheme.onSurfaceVariant.withValues(alpha: 0.5)),
                  const SizedBox(width: 8),
                  Text(
                    'Micrófono (voz directa)',
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: state.micMode ? colorScheme.primary : colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const Spacer(),
                  SizedBox(
                    height: 28,
                    child: Switch(
                      value: state.micMode,
                      onChanged: state.isStreaming
                          ? null
                          : (v) => ref.read(translationProvider.notifier).setMicMode(v),
                    ),
                  ),
                ],
              ),
            ),

      // ── Botón de grabación ──
            Expanded(
              child: Column(
                children: [
                  if (state.paragraphs.isEmpty) const Spacer(),
                  Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        RecordingButton(
                          isStreaming: state.isStreaming,
                          onStart: () {
                            ref.read(translationProvider.notifier).startTranslation(
                              sourceLanguage: settings.sourceLanguage,
                              targetLanguage: settings.targetLanguage,
                              voiceName: settings.voiceName,
                              speed: settings.speed,
                              existingSessionId: state.currentSessionId,
                              sessionName: state.sessionName,
                            );
                          },
                          onStop: () => ref.read(translationProvider.notifier).stopTranslation(),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          state.micMode && state.isStreaming
                              ? 'Micrófono activo'
                              : switch (state.status) {
                                  TranslationStatus.idle => state.micMode ? 'Micrófono' : 'Toca para empezar',
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
                  if (state.paragraphs.isEmpty) const Spacer(),

                  // ── Párrafos en vivo (últimos 4) ──
                  if (state.paragraphs.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    _LiveParagraphs(
                      paragraphs: state.paragraphs,
                      playingId: state.playingParagraphId,
                      onTap: () => _openLiveSession(context, ref),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _openLiveSession(BuildContext context, WidgetRef ref) {
    final state = ref.read(translationProvider);
    if (state.paragraphs.isEmpty) return;

    final session = TranslationSession(
      id: state.currentSessionId ?? 'live',
      name: state.sessionName.isNotEmpty ? state.sessionName : 'Sesión en vivo',
      sourceLanguage: state.paragraphs.first.sourceLanguage,
      targetLanguage: state.paragraphs.first.targetLanguage,
      paragraphs: state.paragraphs,
      createdAt: DateTime.now(),
      durationMs: 0,
    );

    Navigator.push(context, MaterialPageRoute(
      builder: (_) => SessionDetailScreen(session: session),
    ));
  }

  void _showSessionPicker(BuildContext context, WidgetRef ref) async {
    // Precargar sesiones antes de mostrar el sheet para evitar lag
    final sessions = await ref.read(historyProvider.future);

    if (!context.mounted) return;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => _SessionPickerSheet(ref: ref, sessions: sessions),
    );
  }
}

/// Busca el nombre de un dispositivo por su ID en el estado de dispositivos.
String? _deviceName(AudioDevicesState state, String? id) {
  if (id == null) return null;
  final device = state.devices.where((d) => d.id == id).firstOrNull;
  return device?.name;
}

// ── Session picker bottom sheet ─────────────────────────────────

class _SessionPickerSheet extends ConsumerStatefulWidget {
  final WidgetRef ref;
  final List<TranslationSession> sessions;
  const _SessionPickerSheet({required this.ref, required this.sessions});

  @override
  ConsumerState<_SessionPickerSheet> createState() => _SessionPickerSheetState();
}

class _SessionPickerSheetState extends ConsumerState<_SessionPickerSheet> {
  final _nameController = TextEditingController();
  bool _showNew = false;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return AnimatedPadding(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOutCubic,
      padding: EdgeInsets.fromLTRB(20, 12, 20, 24 + bottomInset),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: colorScheme.onSurfaceVariant.withValues(alpha: 0.4), borderRadius: BorderRadius.circular(2)))),
          const SizedBox(height: 16),

          // ── Nueva sesión ──
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            child: !_showNew
                ? ListTile(
                    key: const ValueKey('new-btn'),
                    leading: Icon(Icons.add_circle_outline, color: colorScheme.primary),
                    title: const Text('Nueva sesión'),
                    subtitle: const Text('Crear una sesión en blanco'),
                    onTap: () => setState(() => _showNew = true),
                  )
                : Column(
                    key: const ValueKey('new-form'),
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextField(
                        controller: _nameController,
                        autofocus: true,
                        decoration: InputDecoration(
                          hintText: 'Nombre de la sesión (opcional)',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: FilledButton(
                              onPressed: () => _createNew(context),
                              child: const Text('Crear'),
                            ),
                          ),
                          const SizedBox(width: 8),
                          TextButton(onPressed: () => setState(() => _showNew = false), child: const Text('Cancelar')),
                        ],
                      ),
                    ],
                  ),
          ),

          // ── Sesiones existentes ──
          if (widget.sessions.isNotEmpty && !_showNew) ...[
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text('Sesiones guardadas', style: theme.textTheme.labelMedium?.copyWith(color: colorScheme.onSurfaceVariant)),
            ),
          ],
          if (widget.sessions.isNotEmpty)
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 250),
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: widget.sessions.length,
                separatorBuilder: (context, index) => const Divider(height: 1),
                itemBuilder: (_, i) {
                  final s = widget.sessions[i];
                  return ListTile(
                    dense: true,
                    leading: Icon(Icons.chat_outlined, color: colorScheme.primary),
                    title: Text(s.name.isNotEmpty ? s.name : 'Sesión', overflow: TextOverflow.ellipsis),
                    subtitle: Text('${s.paragraphCount} párrafos • ${s.formattedDate}', style: const TextStyle(fontSize: 12)),
                    trailing: const Icon(Icons.chevron_right, size: 18),
                    onTap: () {
                      widget.ref.read(translationProvider.notifier).setSessionInfo(s.id, s.name);
                      Navigator.pop(context);
                    },
                  );
                },
              ),
            )
          else if (!_showNew)
            const Padding(
              padding: EdgeInsets.only(top: 16),
              child: Text('No hay sesiones guardadas aún'),
            ),
        ],
      ),
    );
  }

  void _createNew(BuildContext context) {
    final name = _nameController.text.trim();
    // Crear una sesión nueva con solo el nombre (se va a crear en el repo cuando se presione grabar)
    widget.ref.read(translationProvider.notifier).setSessionInfo('_new_', name);
    Navigator.pop(context);
  }
}

// ── Tarjeta de párrafo en vivo ──────────────────────────────────

/// Lista de los últimos 4 párrafos ocupando el espacio disponible.
class _LiveParagraphs extends StatelessWidget {
  final List<TranslationParagraph> paragraphs;
  final String? playingId;
  final VoidCallback onTap;

  const _LiveParagraphs({
    required this.paragraphs,
    required this.playingId,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final recent = paragraphs.length > 4
        ? paragraphs.sublist(paragraphs.length - 4)
        : paragraphs;

    return Expanded(
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: recent.length,
        itemBuilder: (_, i) {
          final p = recent[i];
          return _ParagraphCard(
            paragraph: p,
            isPlaying: playingId == p.id,
            onTap: onTap,
          );
        },
      ),
    );
  }
}

class _ParagraphCard extends StatelessWidget {
  final TranslationParagraph paragraph;
  final bool isPlaying;
  final VoidCallback onTap;

  const _ParagraphCard({
    required this.paragraph,
    required this.isPlaying,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Original ──
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.mic, size: 14, color: colorScheme.onSurfaceVariant.withValues(alpha: 0.6)),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      paragraph.originalText,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                        height: 1.3,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              // ── Traducción ──
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    isPlaying ? Icons.volume_up : Icons.translate,
                    size: 14,
                    color: isPlaying ? colorScheme.primary : colorScheme.primary.withValues(alpha: 0.6),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      paragraph.translatedText,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: isPlaying ? colorScheme.primary : colorScheme.onSurface,
                        fontWeight: isPlaying ? FontWeight.w600 : FontWeight.normal,
                        height: 1.3,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (isPlaying)
                    Padding(
                      padding: const EdgeInsets.only(left: 4),
                      child: SizedBox(
                        width: 12,
                        height: 12,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: colorScheme.primary,
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
