/// Utilidades para manejo de audio y formatos.
class AudioUtils {
  AudioUtils._();

  /// Convierten milisegundos a un formato legible mm:ss.
  static String formatDuration(int milliseconds) {
    final seconds = (milliseconds / 1000).floor();
    final min = (seconds / 60).floor();
    final sec = seconds % 60;
    return '${min.toString().padLeft(2, '0')}:${sec.toString().padLeft(2, '0')}';
  }

  /// Tamaño estimado de un chunk de audio en bytes.
  static int estimateChunkSize({
    required int durationMs,
    required int sampleRate,
    int bytesPerSample = 2, // 16-bit
    int channels = 1,
  }) {
    return (sampleRate * bytesPerSample * channels * durationMs) ~/ 1000;
  }
}
