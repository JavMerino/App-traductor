import 'package:audio_traductor/app.dart';
import 'package:audio_traductor/core/di/injection_container.dart';
import 'package:audio_traductor/features/translation/data/datasources/google_tts_datasource.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:record/record.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // ── Inicializar Hive ──
  await Hive.initFlutter();

  // ── Inicializar dependencias ──
  await InjectionContainer.init();

  // ── Solicitar permisos al iniciar ──
  final recorder = AudioRecorder();
  final hasPerm = await recorder.hasPermission();
  if (!hasPerm) {
    try {
      final stream = await recorder.startStream(
        const RecordConfig(encoder: AudioEncoder.pcm16bits, numChannels: 1, sampleRate: 16000),
      );
      stream.listen(null)?.cancel();
      await recorder.stop();
    } catch (_) {}
  }

  // ── Pre-calentar TTS ──
  RealTtsDatasource.instance.warmup('en', 'en-US-Wavenet-D');

  // ── Arrancar la app ──
  runApp(
    const ProviderScope(
      child: AudioTraductorApp(),
    ),
  );
}
