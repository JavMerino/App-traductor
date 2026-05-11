import 'package:audio_traductor/core/theme/app_theme.dart';
import 'package:audio_traductor/features/translation/presentation/providers/theme_provider.dart';
import 'package:audio_traductor/features/translation/presentation/providers/translation_provider.dart';
import 'package:audio_traductor/features/translation/presentation/screens/home_screen.dart';
import 'package:audio_traductor/features/translation/presentation/screens/history_screen.dart';
import 'package:audio_traductor/features/translation/presentation/screens/settings_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Widget raíz de la aplicación.
class AudioTraductorApp extends ConsumerWidget {
  const AudioTraductorApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);
    final seedColor = ref.watch(seedColorProvider);

    return MaterialApp(
      title: 'Audio Traductor',
      debugShowCheckedModeBanner: false,

      // ── Temas dinámicos (seed color vivo) ──
      theme: AppTheme.light(seedColor),
      darkTheme: AppTheme.dark(seedColor),
      themeMode: themeMode,

      // ── Home con BottomNavigation ──
      home: const MainShell(),
    );
  }
}

/// Shell principal con BottomNavigationBar y fondo degradado.
///
/// Usa [Theme.of(context).brightness] para elegir el degradado correcto
/// en vez de mirar el provider. Esto evita:
///   1. Color incorrecto en primer inicio con modo sistema
///   2. Rebuild duplicado que ralentiza el cambio de tema
///
/// Al cambiar a la pestaña Historial, invalida el provider para
/// traer siempre los datos más frescos (sesiones recién grabadas).
class MainShell extends ConsumerStatefulWidget {
  const MainShell({super.key});

  @override
  ConsumerState<MainShell> createState() => _MainShellState();
}

class _MainShellState extends ConsumerState<MainShell> {
  int _currentIndex = 0;

  final _screens = const <Widget>[
    HomeScreen(),
    HistoryScreen(),
    SettingsScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final gradientColors = brightness == Brightness.dark
        ? AppTheme.darkGradient
        : AppTheme.lightGradient;

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: gradientColors,
        ),
      ),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: IndexedStack(
          index: _currentIndex,
          children: _screens,
        ),
        bottomNavigationBar: NavigationBar(
          selectedIndex: _currentIndex,
          onDestinationSelected: (index) {
            setState(() => _currentIndex = index);
            // Refrescar historial cada vez que se entra a la pestaña
            if (index == 1) {
              ref.invalidate(historyProvider);
            }
          },
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.translate_outlined),
              selectedIcon: Icon(Icons.translate),
              label: 'Traductor',
            ),
            NavigationDestination(
              icon: Icon(Icons.history_outlined),
              selectedIcon: Icon(Icons.history),
              label: 'Historial',
            ),
            NavigationDestination(
              icon: Icon(Icons.settings_outlined),
              selectedIcon: Icon(Icons.settings),
              label: 'Ajustes',
            ),
          ],
        ),
      ),
    );
  }
}
