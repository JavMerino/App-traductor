import 'package:flutter/material.dart';

/// Botón circular animado para iniciar/detener la traducción.
class RecordingButton extends StatefulWidget {
  final bool isStreaming;
  final VoidCallback onStart;
  final VoidCallback onStop;

  const RecordingButton({
    super.key,
    required this.isStreaming,
    required this.onStart,
    required this.onStop,
  });

  @override
  State<RecordingButton> createState() => _RecordingButtonState();
}

class _RecordingButtonState extends State<RecordingButton>
    with SingleTickerProviderStateMixin {
  AnimationController? _animationController;
  Animation<double>? _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.15).animate(
      CurvedAnimation(parent: _animationController!, curve: Curves.easeInOut),
    );
  }

  @override
  void didUpdateWidget(RecordingButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isStreaming && !oldWidget.isStreaming) {
      _animationController?.repeat(reverse: true);
    } else if (!widget.isStreaming && oldWidget.isStreaming) {
      _animationController?.reset();
    }
  }

  @override
  void dispose() {
    _animationController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return GestureDetector(
      onTap: widget.isStreaming ? widget.onStop : widget.onStart,
      child: AnimatedBuilder(
        animation: _pulseAnimation!,
        builder: (context, child) {
          return Transform.scale(
            scale: widget.isStreaming ? _pulseAnimation!.value : 1.0,
            child: Container(
              width: 88,
              height: 88,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: widget.isStreaming ? colorScheme.error : colorScheme.primary,
                boxShadow: [
                  BoxShadow(
                    color: (widget.isStreaming ? colorScheme.error : colorScheme.primary)
                        .withValues(alpha: 0.3),
                    blurRadius: 20,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: Icon(
                widget.isStreaming ? Icons.stop_rounded : Icons.mic_rounded,
                size: 40,
                color: colorScheme.onPrimary,
              ),
            ),
          );
        },
      ),
    );
  }
}
