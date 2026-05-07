import 'dart:convert';
import 'package:audio_traductor/core/errors/exceptions.dart';
import 'package:audio_traductor/features/translation/data/models/translation_session_model.dart';
import 'package:hive_flutter/hive_flutter.dart';

/// DataSource local para persistir sesiones con párrafos.
class TranslationLocalDatasource {
  static const _boxName = 'translation_history';

  Box<String>? _box;

  Future<Box<String>> get _db async {
    if (_box != null && _box!.isOpen) return _box!;
    _box = await Hive.openBox<String>(_boxName);
    return _box!;
  }

  /// Guarda o actualiza una sesión.
  Future<void> saveSession(TranslationSessionModel session) async {
    try {
      final box = await _db;
      await box.put(session.id, jsonEncode(session.toJson()));
    } catch (e) {
      throw CacheException(message: 'Error al guardar sesión: $e');
    }
  }

  /// Obtiene todas las sesiones (filtra vacías).
  Future<List<TranslationSessionModel>> getAllSessions() async {
    try {
      final box = await _db;
      final sessions = <TranslationSessionModel>[];

      for (final value in box.values) {
        try {
          final json = jsonDecode(value) as Map<String, dynamic>;
          final model = TranslationSessionModel.fromJson(json);
          // Omitir sesiones vacías (sin párrafos)
          if (model.paragraphsJson.isNotEmpty) {
            sessions.add(model);
          }
        } catch (_) {}
      }

      sessions.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return sessions;
    } catch (e) {
      throw CacheException(message: 'Error al leer historial: $e');
    }
  }

  /// Obtiene una sesión por ID.
  Future<TranslationSessionModel?> getSession(String id) async {
    try {
      final box = await _db;
      final value = box.get(id);
      if (value == null) return null;
      return TranslationSessionModel.fromJson(jsonDecode(value));
    } catch (e) {
      throw CacheException(message: 'Error al leer sesión: $e');
    }
  }

  Future<void> deleteSession(String sessionId) async {
    try {
      final box = await _db;
      await box.delete(sessionId);
    } catch (e) {
      throw CacheException(message: 'Error al eliminar sesión: $e');
    }
  }

  Future<void> clearAll() async {
    try {
      final box = await _db;
      await box.clear();
    } catch (e) {
      throw CacheException(message: 'Error al limpiar historial: $e');
    }
  }
}
