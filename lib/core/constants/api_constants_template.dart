// Copiá este archivo como api_constants.dart y completá las keys
// api_constants.dart está en .gitignore — NO se sube al repo

class ApiConstants {
  ApiConstants._();

  static const String projectId = 'TU_PROJECT_ID';

  static const String ttsApiKey = 'INGRESA_TU_TTS_API_KEY';
  static const String sttApiKey = 'INGRESA_TU_STT_API_KEY';

  static const String sttEndpoint =
      'https://speech.googleapis.com/v1/speech:recognize';

  static const String ttsEndpoint =
      'https://texttospeech.googleapis.com/v1/text:synthesize';
}
