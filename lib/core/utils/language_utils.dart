/// Utilidades para idiomas: mapas de código → bandera y código → nombre.
class LangUtils {
  LangUtils._();

  static const _flags = {
    'es': '🇪🇸', 'en': '🇺🇸', 'pt': '🇧🇷', 'fr': '🇫🇷',
    'de': '🇩🇪', 'it': '🇮🇹', 'ja': '🇯🇵', 'zh': '🇨🇳',
    'ko': '🇰🇷', 'ru': '🇷🇺', 'ar': '🇸🇦', 'nl': '🇳🇱',
  };

  static const _names = {
    'es': 'Español', 'en': 'Inglés', 'pt': 'Portugués', 'fr': 'Francés',
    'de': 'Alemán', 'it': 'Italiano', 'ja': 'Japonés', 'zh': 'Chino',
    'ko': 'Coreano', 'ru': 'Ruso', 'ar': 'Árabe', 'nl': 'Neerlandés',
  };

  static String flag(String code) => _flags[code] ?? '🌐';
  static String name(String code) => _names[code] ?? code.toUpperCase();
}
