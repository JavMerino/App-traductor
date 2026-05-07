import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// ── Paleta de colores disponibles ──────────────────────────────

/// Un color disponible para elegir como acento de la app.
class SeedColorOption {
  final Color color;
  final String name;

  const SeedColorOption({required this.color, required this.name});
}

/// Colores semilla predefinidos para el selector de acento.
const List<SeedColorOption> seedColorOptions = [
  SeedColorOption(color: Color(0xFF00897B), name: 'Teal'),
  SeedColorOption(color: Color(0xFF1565C0), name: 'Azul'),
  SeedColorOption(color: Color(0xFF303F9F), name: 'Índigo'),
  SeedColorOption(color: Color(0xFF7B1FA2), name: 'Púrpura'),
  SeedColorOption(color: Color(0xFFC2185B), name: 'Rosa'),
  SeedColorOption(color: Color(0xFFD32F2F), name: 'Rojo'),
  SeedColorOption(color: Color(0xFFE65100), name: 'Naranja'),
  SeedColorOption(color: Color(0xFF388E3C), name: 'Verde'),
  SeedColorOption(color: Color(0xFF455A64), name: 'Gris'),
];

const _defaultSeed = Color(0xFF00897B);

// ── Providers ──────────────────────────────────────────────────

/// Provider para el modo de tema (claro/oscuro/sistema).
class ThemeModeNotifier extends StateNotifier<ThemeMode> {
  ThemeModeNotifier() : super(ThemeMode.system);

  void setThemeMode(ThemeMode mode) {
    state = mode;
  }

  void toggle() {
    state = state == ThemeMode.light ? ThemeMode.dark : ThemeMode.light;
  }
}

final themeModeProvider =
    StateNotifierProvider<ThemeModeNotifier, ThemeMode>((ref) {
  return ThemeModeNotifier();
});

/// Provider para el color semilla del tema.
///
/// Cambiarlo regenera toda la paleta de colores de la app
/// (bordes, barras, botones, cards, etc).
class SeedColorNotifier extends StateNotifier<Color> {
  SeedColorNotifier() : super(_defaultSeed);

  void setColor(Color color) {
    state = color;
  }
}

final seedColorProvider =
    StateNotifierProvider<SeedColorNotifier, Color>((ref) {
  return SeedColorNotifier();
});
