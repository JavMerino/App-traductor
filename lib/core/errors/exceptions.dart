/// Excepciones técnicas que ocurren en la capa de datos.
///
/// NO deben filtrarse a la capa de presentación. Los repositorios
/// las capturan y las convierten en [Failure] del dominio.
class ServerException implements Exception {
  final String message;
  final int? statusCode;
  final dynamic response;

  const ServerException({
    required this.message,
    this.statusCode,
    this.response,
  });

  @override
  String toString() => 'ServerException: $message (status: $statusCode)';
}

class AudioException implements Exception {
  final String message;
  final String? details;

  const AudioException({required this.message, this.details});

  @override
  String toString() => 'AudioException: $message';
}

class CacheException implements Exception {
  final String message;

  const CacheException({required this.message});

  @override
  String toString() => 'CacheException: $message';
}

class BluetoothException implements Exception {
  final String message;

  const BluetoothException({required this.message});

  @override
  String toString() => 'BluetoothException: $message';
}
