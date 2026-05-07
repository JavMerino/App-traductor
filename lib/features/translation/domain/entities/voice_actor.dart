import 'package:equatable/equatable.dart';

/// Tipo de voz para la síntesis de audio de salida.
class VoiceActor extends Equatable {
  final String name;
  final String displayName;
  final String languageCode;
  final VoiceGender gender;
  final String? ssmlGender;

  const VoiceActor({
    required this.name,
    required this.displayName,
    required this.languageCode,
    required this.gender,
    this.ssmlGender,
  });

  @override
  List<Object?> get props => [name, displayName, languageCode, gender];

  static List<VoiceActor> forLanguage(String languageCode) {
    return _allVoices.where((v) => v.languageCode == languageCode).toList();
  }

  static const List<VoiceActor> _allVoices = [
    // ── Español ──
    VoiceActor(name: 'es-ES-Standard-A', displayName: 'Estándar (Mujer)', languageCode: 'es', gender: VoiceGender.female, ssmlGender: 'FEMALE'),
    VoiceActor(name: 'es-ES-Standard-B', displayName: 'Estándar (Hombre)', languageCode: 'es', gender: VoiceGender.male, ssmlGender: 'MALE'),
    VoiceActor(name: 'es-ES-Wavenet-B', displayName: 'WaveNet (Hombre)', languageCode: 'es', gender: VoiceGender.male, ssmlGender: 'MALE'),

    // ── Inglés ──
    VoiceActor(name: 'en-US-Standard-C', displayName: 'Estándar (Mujer)', languageCode: 'en', gender: VoiceGender.female, ssmlGender: 'FEMALE'),
    VoiceActor(name: 'en-US-Standard-D', displayName: 'Estándar (Hombre)', languageCode: 'en', gender: VoiceGender.male, ssmlGender: 'MALE'),
    VoiceActor(name: 'en-US-Wavenet-D', displayName: 'WaveNet (Hombre)', languageCode: 'en', gender: VoiceGender.male, ssmlGender: 'MALE'),
    VoiceActor(name: 'en-US-Studio-O', displayName: 'Studio (Mujer)', languageCode: 'en', gender: VoiceGender.female, ssmlGender: 'FEMALE'),

    // ── Portugués ──
    VoiceActor(name: 'pt-BR-Standard-A', displayName: 'Estándar (Mujer)', languageCode: 'pt', gender: VoiceGender.female, ssmlGender: 'FEMALE'),
    VoiceActor(name: 'pt-BR-Wavenet-A', displayName: 'WaveNet (Mujer)', languageCode: 'pt', gender: VoiceGender.female, ssmlGender: 'FEMALE'),

    // ── Francés ──
    VoiceActor(name: 'fr-FR-Standard-A', displayName: 'Estándar (Mujer)', languageCode: 'fr', gender: VoiceGender.female, ssmlGender: 'FEMALE'),
    VoiceActor(name: 'fr-FR-Standard-B', displayName: 'Estándar (Hombre)', languageCode: 'fr', gender: VoiceGender.male, ssmlGender: 'MALE'),

    // ── Alemán ──
    VoiceActor(name: 'de-DE-Standard-A', displayName: 'Estándar (Mujer)', languageCode: 'de', gender: VoiceGender.female, ssmlGender: 'FEMALE'),
    VoiceActor(name: 'de-DE-Wavenet-A', displayName: 'WaveNet (Mujer)', languageCode: 'de', gender: VoiceGender.female, ssmlGender: 'FEMALE'),

    // ── Italiano ──
    VoiceActor(name: 'it-IT-Standard-A', displayName: 'Estándar (Mujer)', languageCode: 'it', gender: VoiceGender.female, ssmlGender: 'FEMALE'),

    // ── Japonés ──
    VoiceActor(name: 'ja-JP-Standard-A', displayName: 'Estándar (Mujer)', languageCode: 'ja', gender: VoiceGender.female, ssmlGender: 'FEMALE'),

    // ── Chino ──
    VoiceActor(name: 'zh-CN-Standard-A', displayName: 'Estándar (Mujer)', languageCode: 'zh', gender: VoiceGender.female, ssmlGender: 'FEMALE'),
    VoiceActor(name: 'zh-CN-Standard-B', displayName: 'Estándar (Hombre)', languageCode: 'zh', gender: VoiceGender.male, ssmlGender: 'MALE'),
    VoiceActor(name: 'zh-CN-Wavenet-A', displayName: 'WaveNet (Mujer)', languageCode: 'zh', gender: VoiceGender.female, ssmlGender: 'FEMALE'),

    // ── Coreano ──
    VoiceActor(name: 'ko-KR-Standard-A', displayName: 'Estándar (Mujer)', languageCode: 'ko', gender: VoiceGender.female, ssmlGender: 'FEMALE'),
    VoiceActor(name: 'ko-KR-Wavenet-A', displayName: 'WaveNet (Mujer)', languageCode: 'ko', gender: VoiceGender.female, ssmlGender: 'FEMALE'),

    // ── Ruso ──
    VoiceActor(name: 'ru-RU-Standard-A', displayName: 'Estándar (Mujer)', languageCode: 'ru', gender: VoiceGender.female, ssmlGender: 'FEMALE'),

    // ── Árabe ──
    VoiceActor(name: 'ar-XA-Standard-A', displayName: 'Estándar (Mujer)', languageCode: 'ar', gender: VoiceGender.female, ssmlGender: 'FEMALE'),
    VoiceActor(name: 'ar-XA-Standard-B', displayName: 'Estándar (Hombre)', languageCode: 'ar', gender: VoiceGender.male, ssmlGender: 'MALE'),

    // ── Neerlandés ──
    VoiceActor(name: 'nl-NL-Standard-A', displayName: 'Estándar (Mujer)', languageCode: 'nl', gender: VoiceGender.female, ssmlGender: 'FEMALE'),
  ];
}

enum VoiceGender { male, female, other }
