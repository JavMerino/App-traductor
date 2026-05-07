import 'package:audio_traductor/core/errors/failures.dart';
import 'package:audio_traductor/features/history_export/presentation/widgets/export_button.dart';
import 'package:audio_traductor/features/translation/domain/entities/translation_session.dart';
import 'package:audio_traductor/features/translation/presentation/providers/translation_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Pantalla de historial de traducciones.
class HistoryScreen extends ConsumerWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final historyAsync = ref.watch(historyProvider);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Historial'),
        actions: [
          // Botón de exportar todo
          ExportButton(
            sessions: historyAsync.valueOrNull ?? [],
          ),
          // Botón de limpiar
          historyAsync.whenOrNull(
                data: (sessions) => sessions.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.delete_sweep_outlined),
                        tooltip: 'Limpiar historial',
                        onPressed: () => _confirmClear(context, ref),
                      )
                    : null,
              ) ??
              const SizedBox.shrink(),
        ],
      ),
      body: historyAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) {
          final message = error is Failure
              ? error.message
              : 'Error al cargar el historial';
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.error_outline, size: 48, color: colorScheme.error),
                const SizedBox(height: 16),
                Text(message, style: theme.textTheme.bodyLarge),
                const SizedBox(height: 16),
                FilledButton.tonal(
                  onPressed: () => ref.invalidate(historyProvider),
                  child: const Text('Reintentar'),
                ),
              ],
            ),
          );
        },
        data: (sessions) {
          if (sessions.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.history,
                    size: 64,
                    color: colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Sin traducciones aún',
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Las traducciones aparecerán aquí',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
                    ),
                  ),
                ],
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(historyProvider);
            },
            child: ListView.builder(
              padding: const EdgeInsets.only(top: 8, bottom: 24),
              itemCount: sessions.length,
              itemBuilder: (context, index) {
                final session = sessions[index];
                return _HistoryCard(
                  session: session,
                  onDelete: () => _deleteSession(context, ref, session.id),
                );
              },
            ),
          );
        },
      ),
    );
  }

  void _confirmClear(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Limpiar historial'),
        content: const Text(
          '¿Estás seguro? Esta acción no se puede deshacer.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              // TODO: implementar clear history
              ref.invalidate(historyProvider);
            },
            child: const Text('Limpiar'),
          ),
        ],
      ),
    );
  }

  void _deleteSession(BuildContext context, WidgetRef ref, String sessionId) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar'),
        content: const Text('¿Eliminar esta traducción del historial?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              // TODO: implementar delete session
              ref.invalidate(historyProvider);
            },
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
  }
}

/// Tarjeta individual del historial.
class _HistoryCard extends StatelessWidget {
  final TranslationSession session;
  final VoidCallback onDelete;

  const _HistoryCard({
    required this.session,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header con fecha e idiomas
            Row(
              children: [
                Icon(Icons.translate, size: 18, color: colorScheme.primary),
                const SizedBox(width: 8),
                Text(
                  '${session.sourceLanguage.toUpperCase()} → ${session.targetLanguage.toUpperCase()}',
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: colorScheme.primary,
                  ),
                ),
                const Spacer(),
                Text(
                  session.formattedDate,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Texto original
            Text(
              session.originalText,
              style: theme.textTheme.bodyMedium,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),

            // Texto traducido
            Text(
              session.translatedText,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colorScheme.primary,
                fontWeight: FontWeight.w500,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 8),

            // Footer con duración y acción eliminar
            Row(
              children: [
                Icon(
                  Icons.timer_outlined,
                  size: 14,
                  color: colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 4),
                Text(
                  session.formattedDuration,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: Icon(
                    Icons.delete_outline,
                    size: 18,
                    color: colorScheme.error,
                  ),
                  onPressed: onDelete,
                  tooltip: 'Eliminar',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
