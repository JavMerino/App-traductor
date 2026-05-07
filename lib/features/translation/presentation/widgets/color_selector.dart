import 'package:audio_traductor/features/translation/presentation/providers/theme_provider.dart';
import 'package:flutter/material.dart';

/// Selector de color acento con círculos de colores en una fila.
class ColorSelector extends StatelessWidget {
  final Color selectedColor;
  final ValueChanged<Color> onChanged;

  const ColorSelector({
    super.key,
    required this.selectedColor,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final surface = Theme.of(context).colorScheme.onSurface;

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: seedColorOptions.map((option) {
          final isSelected =
              option.color.toARGB32() == selectedColor.toARGB32();
          return Padding(
            padding: const EdgeInsets.only(right: 10),
            child: GestureDetector(
              onTap: () => onChanged(option.color),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: option.color,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isSelected ? surface : Colors.transparent,
                    width: isSelected ? 2.5 : 1.5,
                  ),
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                            color: option.color.withValues(alpha: 0.5),
                            blurRadius: 6,
                            spreadRadius: 0.5,
                          ),
                        ]
                      : null,
                ),
                child: isSelected
                    ? Icon(
                        Icons.check,
                        color: option.color.computeLuminance() > 0.5
                            ? Colors.black87
                            : Colors.white,
                        size: 16,
                      )
                    : null,
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}
