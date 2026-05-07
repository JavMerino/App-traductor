import 'package:audio_traductor/app.dart';
import 'package:audio_traductor/core/di/injection_container.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // ── Inicializar Hive ──
  await Hive.initFlutter();

  // ── Inicializar dependencias ──
  await InjectionContainer.init();

  // ── Arrancar la app ──
  runApp(
    const ProviderScope(
      child: AudioTraductorApp(),
    ),
  );
}
