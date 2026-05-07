import 'package:audio_traductor/features/translation/data/datasources/google_stt_datasource.dart';
import 'package:audio_traductor/features/translation/data/datasources/google_translate_datasource.dart';
import 'package:audio_traductor/features/translation/data/datasources/google_tts_datasource.dart';
import 'package:audio_traductor/features/translation/data/datasources/translation_local_datasource.dart';
import 'package:audio_traductor/features/translation/data/repositories/translation_repository_impl.dart';
import 'package:audio_traductor/features/translation/domain/repositories/translation_repository.dart';
import 'package:audio_traductor/features/translation/domain/usecases/get_translation_history.dart';
import 'package:audio_traductor/features/translation/domain/usecases/start_streaming_translation.dart';
import 'package:audio_traductor/features/translation/domain/usecases/stop_streaming_translation.dart';

class InjectionContainer {
  // ── DataSources ──
  static final SttDatasource _stt = RealSttDatasource();
  static final TranslateDatasource _translate = GoogleTranslateDatasource();
  static final TtsDatasource _tts = RealTtsDatasource.instance;
  static final _local = TranslationLocalDatasource();

  // ── Repository ──
  static final TranslationRepository _repository = TranslationRepositoryImpl(
    stt: _stt,
    translate: _translate,
    tts: _tts,
    local: _local,
  );

  // ── Use Cases ──
  static final StartStreamingTranslation startTranslation =
      StartStreamingTranslation(_repository);
  static final StopStreamingTranslation stopTranslation =
      StopStreamingTranslation(_repository);
  static final GetTranslationHistory getHistory =
      GetTranslationHistory(_repository);
  static final DeleteTranslationSession deleteSession =
      DeleteTranslationSession(_repository);
  static final ClearTranslationHistory clearHistory =
      ClearTranslationHistory(_repository);

  static Future<void> init() async {
    await _local.getAllSessions();
  }
}
