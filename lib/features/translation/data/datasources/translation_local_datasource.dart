import 'dart:convert';
import 'package:audio_traductor/core/errors/exceptions.dart';
import 'package:audio_traductor/features/translation/data/models/translation_session_model.dart';
import 'package:hive_flutter/hive_flutter.dart';

/// DataSource local para persistir el historial de traducciones.
///
/// Usa Hive como almacenamiento NoSQL embebido.
class TranslationLocalDatasource {
  static const _boxName = 'translation_history';

  Box<String>? _box;

  Future<Box<String>> get _db async {
    if (_box != null && _box!.isOpen) return _box!;
    _box = await Hive.openBox<String>(_boxName);
    return _box!;
  }

  /// Guarda una sesión de traducción.
  Future<void> saveSession(TranslationSessionModel session) async {
    try {
      final box = await _db;
      await box.put(session.id, jsonEncode(session.toJson()));
    } catch (e) {
      throw CacheException(message: 'Error al guardar sesión: $e');
    }
  }

  /// Obtiene todas las sesiones guardadas.
  Future<List<TranslationSessionModel>> getAllSessions() async {
    try {
      final box = await _db;
      final sessions = <TranslationSessionModel>[];

      for (final value in box.values) {
        try {
          final json = jsonDecode(value) as Map<String, dynamic>;
          sessions.add(TranslationSessionModel.fromJson(json));
        } catch (_) {
          // ignoramos entradas corruptas
        }
      }

      // Ordenar por fecha descendente (más reciente primero)
      sessions.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return sessions;
    } catch (e) {
      throw CacheException(message: 'Error al leer historial: $e');
    }
  }

  /// Elimina una sesión por ID.
  Future<void> deleteSession(String sessionId) async {
    try {
      final box = await _db;
      await box.delete(sessionId);
    } catch (e) {
      throw CacheException(message: 'Error al eliminar sesión: $e');
    }
  }

  /// Limpia todo el historial.
  Future<void> clearAll() async {
    try {
      final box = await _db;
      await box.clear();
    } catch (e) {
      throw CacheException(message: 'Error al limpiar historial: $e');
    }
  }
}
