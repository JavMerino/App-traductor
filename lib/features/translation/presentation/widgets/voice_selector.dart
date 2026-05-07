import 'package:audio_traductor/features/translation/domain/entities/voice_actor.dart';
import 'package:flutter/material.dart';

/// Selector de voz para la síntesis de audio.
class VoiceSelector extends StatelessWidget {
  final String languageCode;
  final String selectedVoiceName;
  final ValueChanged<VoiceActor> onChanged;

  const VoiceSelector({
    super.key,
    required this.languageCode,
    required this.selectedVoiceName,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final voices = VoiceActor.forLanguage(languageCode);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    if (voices.isEmpty) {
      return Text(
        'No hay voces disponibles para este idioma',
        style: theme.textTheme.bodySmall?.copyWith(
          color: colorScheme.onSurfaceVariant,
        ),
      );
    }

    return Column(
      children: voices.map((voice) {
        final selected = voices.firstWhere(
          (v) => v.name == selectedVoiceName,
          orElse: () => voices.first,
        );
        return RadioListTile<VoiceActor>(
          title: Text(voice.displayName),
          subtitle: Text(voice.gender == VoiceGender.female ? 'Voz femenina' : 'Voz masculina'),
          value: voice,
          groupValue: selected,
          onChanged: (v) {
            if (v != null) onChanged(v);
          },
          dense: true,
          contentPadding: EdgeInsets.zero,
          toggleable: false,
        );
      }).toList(),
    );
  }
}
