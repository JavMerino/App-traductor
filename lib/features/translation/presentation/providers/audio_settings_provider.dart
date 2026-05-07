import 'package:audio_traductor/features/translation/domain/entities/voice_actor.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Configuración de audio seleccionada por el usuario.
class AudioSettings {
  final String sourceLanguage;
  final String sourceLanguageName;
  final String targetLanguage;
  final String targetLanguageName;
  final String voiceName;
  final String voiceDisplayName;
  final double volume;
  final double speed;

  const AudioSettings({
    this.sourceLanguage = 'es',
    this.sourceLanguageName = 'Español',
    this.targetLanguage = 'en',
    this.targetLanguageName = 'Inglés',
    this.voiceName = 'en-US-Wavenet-D',
    this.voiceDisplayName = 'WaveNet (Hombre)',
    this.volume = 1.0,
    this.speed = 1.0,
  });

  AudioSettings copyWith({
    String? sourceLanguage,
    String? sourceLanguageName,
    String? targetLanguage,
    String? targetLanguageName,
    String? voiceName,
    String? voiceDisplayName,
    double? volume,
    double? speed,
  }) {
    return AudioSettings(
      sourceLanguage: sourceLanguage ?? this.sourceLanguage,
      sourceLanguageName: sourceLanguageName ?? this.sourceLanguageName,
      targetLanguage: targetLanguage ?? this.targetLanguage,
      targetLanguageName: targetLanguageName ?? this.targetLanguageName,
      voiceName: voiceName ?? this.voiceName,
      voiceDisplayName: voiceDisplayName ?? this.voiceDisplayName,
      volume: volume ?? this.volume,
      speed: speed ?? this.speed,
    );
  }
}

/// Provider de la configuración de audio.
class AudioSettingsNotifier extends StateNotifier<AudioSettings> {
  AudioSettingsNotifier() : super(const AudioSettings());

  void setSourceLanguage(String code, String name) {
    state = state.copyWith(sourceLanguage: code, sourceLanguageName: name);
  }

  void setTargetLanguage(String code, String name) {
    // Auto-seleccionar una voz para el nuevo idioma
    final voices = VoiceActor.forLanguage(code);
    String voiceName;
    String voiceDisplayName;

    if (voices.isNotEmpty) {
      voiceName = voices.first.name;
      voiceDisplayName = voices.first.displayName;
    } else {
      voiceName = '$code-Standard-A';
      voiceDisplayName = 'Estándar';
    }

    state = state.copyWith(
      targetLanguage: code,
      targetLanguageName: name,
      voiceName: voiceName,
      voiceDisplayName: voiceDisplayName,
    );
  }

  void setVoice(String name, String displayName) {
    state = state.copyWith(voiceName: name, voiceDisplayName: displayName);
  }

  void setVolume(double volume) {
    state = state.copyWith(volume: volume.clamp(0.0, 1.0));
  }

  void setSpeed(double speed) {
    state = state.copyWith(speed: speed.clamp(0.5, 2.0));
  }
}

final audioSettingsProvider =
    StateNotifierProvider<AudioSettingsNotifier, AudioSettings>((ref) {
  return AudioSettingsNotifier();
});
