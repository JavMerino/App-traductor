import 'package:equatable/equatable.dart';

/// Representa un idioma soportado por la app.
class Language extends Equatable {
  final String code; // ej: 'es', 'en', 'pt'
  final String name; // ej: 'Español', 'Inglés', 'Portugués'
  final String flag; // emoji bandera, ej: '🇪🇸'

  const Language({
    required this.code,
    required this.name,
    required this.flag,
  });

  @override
  List<Object?> get props => [code, name, flag];

  /// Lista de idiomas predeterminados para la app.
  static const List<Language> supported = [
    Language(code: 'es', name: 'Español', flag: '🇪🇸'),
    Language(code: 'en', name: 'Inglés', flag: '🇺🇸'),
    Language(code: 'pt', name: 'Portugués', flag: '🇧🇷'),
    Language(code: 'fr', name: 'Francés', flag: '🇫🇷'),
    Language(code: 'de', name: 'Alemán', flag: '🇩🇪'),
    Language(code: 'it', name: 'Italiano', flag: '🇮🇹'),
    Language(code: 'ja', name: 'Japonés', flag: '🇯🇵'),
    Language(code: 'zh', name: 'Chino', flag: '🇨🇳'),
    Language(code: 'ko', name: 'Coreano', flag: '🇰🇷'),
    Language(code: 'ru', name: 'Ruso', flag: '🇷🇺'),
    Language(code: 'ar', name: 'Árabe', flag: '🇸🇦'),
    Language(code: 'nl', name: 'Neerlandés', flag: '🇳🇱'),
  ];
}
