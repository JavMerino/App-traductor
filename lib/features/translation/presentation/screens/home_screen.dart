import 'package:audio_traductor/core/constants/app_constants.dart';
import 'package:audio_traductor/core/services/audio_device_manager.dart';
import 'package:audio_traductor/core/services/bluetooth_provider.dart';
import 'package:audio_traductor/features/translation/domain/entities/translation_session.dart';
import 'package:audio_traductor/features/translation/presentation/providers/translation_provider.dart';
import 'package:audio_traductor/features/translation/presentation/providers/audio_settings_provider.dart';
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
          if (bt.connectedDevice != null)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Tooltip(
                message: 'BT: ${bt.connectedDevice!.name}',
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(width: 8, height: 8,
                      decoration: BoxDecoration(
                        color: Colors.greenAccent, shape: BoxShape.circle,
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
            // ── Selectores de idioma (bloqueados durante grabación) ──
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: IgnorePointer(
                ignoring: state.isStreaming,
                child: AnimatedOpacity(
                  opacity: state.isStreaming ? 0.4 : 1.0,
                  duration: const Duration(milliseconds: 200),
                  child: Row(
                    children: [
                      Expanded(child: LanguageSelector(
                        label: 'Idioma de entrada',
                        selectedCode: settings.sourceLanguage,
                        selectedName: settings.sourceLanguageName,
                        onChanged: (l) => ref.read(audioSettingsProvider.notifier).setSourceLanguage(l.code, l.name),
                      )),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        child: Icon(Icons.arrow_forward, color: colorScheme.primary),
                      ),
                      Expanded(child: LanguageSelector(
                        label: 'Idioma de salida',
                        selectedCode: settings.targetLanguage,
                        selectedName: settings.targetLanguageName,
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

            // ── Botón de grabación ──
            Expanded(
              child: Center(
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
                      switch (state.status) {
                        TranslationStatus.idle => 'Toca para empezar',
                        TranslationStatus.listening => 'Escuchando...',
                        TranslationStatus.translating => 'Traduciendo...',
                        TranslationStatus.playing => 'Reproduciendo...',
                        TranslationStatus.error => 'Error',
                      },
                      style: theme.textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant),
                    ),
                    // Párrafos en vivo
                    if (state.paragraphs.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 16),
                        child: Text('${state.paragraphs.length} párrafo(s)', style: theme.textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant)),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
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
