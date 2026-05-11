import 'package:audio_traductor/core/errors/failures.dart';
import 'package:audio_traductor/core/di/injection_container.dart';
import 'package:audio_traductor/core/utils/language_utils.dart';
import 'package:audio_traductor/features/history_export/data/repositories/export_repository_impl.dart';
import 'package:audio_traductor/features/translation/domain/entities/translation_session.dart';
import 'package:audio_traductor/features/translation/presentation/providers/translation_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Historial de sesiones con eliminación múltiple.
class HistoryScreen extends ConsumerStatefulWidget {
  const HistoryScreen({super.key});

  @override
  ConsumerState<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends ConsumerState<HistoryScreen> {
  bool _selectionMode = false;
  final Set<String> _selectedIds = {};

  void _toggleSelection(String id) {
    setState(() {
      if (_selectedIds.contains(id)) {
        _selectedIds.remove(id);
      } else {
        _selectedIds.add(id);
      }
    });
  }

  void _selectAll(List<TranslationSession> sessions) {
    setState(() {
      if (_selectedIds.length == sessions.length) {
        _selectedIds.clear();
      } else {
        _selectedIds.addAll(sessions.map((s) => s.id));
      }
    });
  }

  void _enterSelectionMode() => setState(() => _selectionMode = true);
  void _exitSelectionMode() {
    setState(() {
      _selectionMode = false;
      _selectedIds.clear();
    });
  }

  Future<void> _deleteSelected() async {
    if (_selectedIds.isEmpty) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar sesiones'),
        content: Text('¿Eliminar ${_selectedIds.length} sesión(es)? Esta acción no se puede deshacer.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    var errors = 0;
    for (final id in _selectedIds.toList()) {
      final result = await InjectionContainer.deleteSession(id);
      result.fold((f) => errors++, (_) {});
    }

    ref.invalidate(historyProvider);
    _exitSelectionMode();

    if (errors > 0 && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$errors sesión(es) no se pudieron eliminar')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final historyAsync = ref.watch(historyProvider);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(_selectionMode ? '${_selectedIds.length} seleccionada(s)' : 'Historial'),
        leading: _selectionMode
            ? IconButton(
                icon: const Icon(Icons.close),
                onPressed: _exitSelectionMode,
              )
            : null,
        actions: [
          if (_selectionMode) ...[
            IconButton(
              icon: const Icon(Icons.delete_forever),
              tooltip: 'Eliminar seleccionadas',
              onPressed: _selectedIds.isNotEmpty ? _deleteSelected : null,
            ),
          ] else ...[
            IconButton(
              icon: const Icon(Icons.delete_outline, size: 20),
              tooltip: 'Eliminar sesiones',
              onPressed: _enterSelectionMode,
            ),
          ],
        ],
      ),
      body: historyAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, size: 48, color: colorScheme.error),
              const SizedBox(height: 16),
              Text(e is Failure ? e.message : 'Error al cargar', style: theme.textTheme.bodyLarge),
              const SizedBox(height: 12),
              FilledButton.tonal(onPressed: () => ref.invalidate(historyProvider), child: const Text('Reintentar')),
            ],
          ),
        ),
        data: (sessions) => sessions.isEmpty
            ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.history, size: 64, color: colorScheme.onSurfaceVariant.withValues(alpha: 0.4)),
                    const SizedBox(height: 16),
                    Text('Sin sesiones aún', style: theme.textTheme.titleMedium?.copyWith(color: colorScheme.onSurfaceVariant)),
                  ],
                ),
              )
            : Column(
                children: [
                  // Botón "Seleccionar todas" en modo selección
                  if (_selectionMode)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: Row(
                        children: [
                          TextButton.icon(
                            onPressed: () => _selectAll(sessions),
                            icon: Icon(
                              _selectedIds.length == sessions.length
                                  ? Icons.deselect
                                  : Icons.select_all,
                              size: 18,
                            ),
                            label: Text(
                              _selectedIds.length == sessions.length
                                  ? 'Deseleccionar todas'
                                  : 'Seleccionar todas',
                            ),
                          ),
                        ],
                      ),
                    ),
                  Expanded(
                    child: ListView.builder(
                      padding: const EdgeInsets.only(top: 8, bottom: 24),
                      itemCount: sessions.length,
                      itemBuilder: (_, i) => _SessionCard(
                        session: sessions[i],
                        colorScheme: colorScheme,
                        theme: theme,
                        selectionMode: _selectionMode,
                        isSelected: _selectedIds.contains(sessions[i].id),
                        onToggleSelect: () => _toggleSelection(sessions[i].id),
                      ),
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

class _SessionCard extends StatelessWidget {
  final TranslationSession session;
  final ColorScheme colorScheme;
  final ThemeData theme;
  final bool selectionMode;
  final bool isSelected;
  final VoidCallback? onToggleSelect;

  const _SessionCard({
    required this.session,
    required this.colorScheme,
    required this.theme,
    this.selectionMode = false,
    this.isSelected = false,
    this.onToggleSelect,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: selectionMode ? onToggleSelect : () => _openSession(context),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              // Checkbox en modo selección
              if (selectionMode)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: Icon(
                    isSelected ? Icons.check_circle : Icons.radio_button_unchecked,
                    color: isSelected ? colorScheme.primary : colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
                  ),
                ),
              // Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.translate, size: 16, color: colorScheme.primary),
                        const SizedBox(width: 6),
                        Text('${session.sourceLanguage.toUpperCase()} → ${session.targetLanguage.toUpperCase()}',
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: colorScheme.primary)),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(session.name.isNotEmpty ? session.name : 'Sesión sin nombre',
                        style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
                        maxLines: 1, overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Icon(Icons.timer_outlined, size: 14, color: colorScheme.onSurfaceVariant),
                        const SizedBox(width: 4),
                        Text(session.formattedDuration, style: TextStyle(fontSize: 11, color: colorScheme.onSurfaceVariant)),
                        const SizedBox(width: 12),
                        Icon(Icons.chat_bubble_outline, size: 14, color: colorScheme.onSurfaceVariant),
                        const SizedBox(width: 4),
                        Text('${session.paragraphCount} párrafos', style: TextStyle(fontSize: 11, color: colorScheme.onSurfaceVariant)),
                      ],
                    ),
                  ],
                ),
              ),
              if (!selectionMode) ...[
                const SizedBox(width: 8),
                Icon(Icons.chevron_right, color: colorScheme.onSurfaceVariant),
              ],
            ],
          ),
        ),
      ),
    );
  }

  void _openSession(BuildContext context) {
    Navigator.push(context, MaterialPageRoute(
      builder: (_) => SessionDetailScreen(session: session),
    ));
  }
}

/// Vista conversación: derecha = original, izquierda = traducción.
class SessionDetailScreen extends StatefulWidget {
  final TranslationSession session;
  const SessionDetailScreen({super.key, required this.session});

  @override
  State<SessionDetailScreen> createState() => _SessionDetailScreenState();
}

class _SessionDetailScreenState extends State<SessionDetailScreen> {
  bool _exporting = false;

  Future<void> _exportPdf() async {
    setState(() => _exporting = true);
    final repo = ExportRepositoryImpl();
    final result = await repo.exportToPdf(
      sessions: [widget.session],
      fileName: '${widget.session.name}_${DateTime.now().millisecondsSinceEpoch}'.replaceAll(' ', '_'),
    );
    setState(() => _exporting = false);
    result.fold(
      (failure) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: ${failure.message}'))),
      (path) async {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('PDF generado — abriendo para compartir...')));
        }
        await repo.shareFile(path);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: AppBar(
        title: Text(widget.session.name.isNotEmpty ? widget.session.name : 'Sesión'),
        actions: [
          _exporting
              ? const SizedBox(width: 24, height: 24, child: Padding(
                  padding: EdgeInsets.all(12),
                  child: CircularProgressIndicator(strokeWidth: 2),
                ))
              : IconButton(icon: const Icon(Icons.picture_as_pdf_outlined), tooltip: 'Exportar PDF', onPressed: _exportPdf),
        ],
      ),
      body: widget.session.paragraphs.isEmpty
          ? const Center(child: Text('Esta sesión está vacía'))
          : ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              itemCount: widget.session.paragraphs.length,
              itemBuilder: (_, i) {
                final p = widget.session.paragraphs[i];
                final srcFlag = LangUtils.flag(p.sourceLanguage);
                final tgtFlag = LangUtils.flag(p.targetLanguage);
                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Column(
                    children: [
                      // Original → derecha (color primario)
                      Bubble(
                        text: p.originalText,
                        flag: srcFlag,
                        color: colorScheme.primaryContainer,
                        textColor: colorScheme.onPrimaryContainer,
                        isRight: true,
                      ),
                      const SizedBox(height: 4),
                      // Traducción → izquierda (color secundario)
                      Bubble(
                        text: p.translatedText,
                        flag: tgtFlag,
                        color: colorScheme.secondaryContainer,
                        textColor: colorScheme.onSecondaryContainer,
                        isRight: false,
                      ),
                    ],
                  ),
                );
              },
            ),
    );
  }
}

class Bubble extends StatelessWidget {
  final String text;
  final String flag;
  final Color color;
  final Color textColor;
  final bool isRight;

  const Bubble({
    required this.text,
    required this.flag,
    required this.color,
    required this.textColor,
    required this.isRight,
  });

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: isRight ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(isRight ? 16 : 4),
            bottomRight: Radius.circular(isRight ? 4 : 16),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (!isRight) ...[
              Text(flag, style: const TextStyle(fontSize: 16)),
              const SizedBox(width: 8),
            ],
            Flexible(
              child: Text(text, style: TextStyle(fontSize: 14, color: textColor)),
            ),
            if (isRight) ...[
              const SizedBox(width: 8),
              Text(flag, style: const TextStyle(fontSize: 16)),
            ],
          ],
        ),
      ),
    );
  }
}
