import 'package:flutter/material.dart';
import 'light_theme.dart';
import 'dark_theme.dart';

/// Fábrica de temas. Centraliza la creación de temas claro/oscuro
/// aceptando un color semilla dinámico.
class AppTheme {
  AppTheme._();

  static ThemeData light(Color seed) => AppLightTheme.withSeed(seed);
  static ThemeData dark(Color seed) => AppDarkTheme.withSeed(seed);

  /// Colores del degradado claro (gris azulado).
  static List<Color> get lightGradient => AppLightTheme.gradientColors;

  /// Colores del degradado oscuro (azul oscuro).
  static List<Color> get darkGradient => AppDarkTheme.gradientColors;
}
