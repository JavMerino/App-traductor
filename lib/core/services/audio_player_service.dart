import 'dart:convert';
import 'dart:io';
import 'package:just_audio/just_audio.dart';
import 'package:path_provider/path_provider.dart';

/// Servicio de reproducción de audio sintetizado.
///
/// Recibe audio en base64 desde Google TTS y lo reproduce
/// usando just_audio. El audio sale por el altavoz activo
/// (Bluetooth si está conectado, sino altavoz del teléfono).
class AudioPlayerService {
  final _player = AudioPlayer();

  AudioPlayerService() {
    // Volumen al máximo
    _player.setVolume(1.0);
    // Escuchar cuando termina de reproducir
    _player.playerStateStream.listen((state) {
      // No hacemos nada especial, solo mantener
    });
  }

  /// ¿Se está reproduciendo algo ahora?
  bool get isPlaying => _player.playing;

  /// Reproduce audio desde un string en base64.
  Future<void> playBase64(String base64Audio) async {
    if (base64Audio.isEmpty) return;

    try {
      final bytes = base64Decode(base64Audio);

      // No reproducir si los datos son muy chicos (audio vacío)
      if (bytes.length < 100) return;

      final dir = await getTemporaryDirectory();
      final file = File(
        '${dir.path}/tts_${DateTime.now().millisecondsSinceEpoch}.mp3',
      );
      await file.writeAsBytes(bytes);

      // Forzar volumen al máximo antes de reproducir
      await _player.setVolume(1.0);

      await _player.setAudioSource(
        AudioSource.file(file.path),
        preload: false,
      );
      await _player.play();
    } catch (_) {
      // Si falla la reproducción, no rompemos el flujo de traducción
    }
  }

  /// Detiene la reproducción.
  Future<void> stop() async {
    await _player.stop();
  }

  /// Libera recursos.
  void dispose() {
    _player.dispose();
  }
}
