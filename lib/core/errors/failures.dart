import 'package:equatable/equatable.dart';

/// Clase base para todos los errores del dominio.
///
/// En Clean Architecture separamos failures (errores del dominio)
/// de exceptions (errores técnicos). Los failures son lo que los
/// casos de uso devuelven a la capa de presentación.
abstract class Failure extends Equatable {
  final String message;
  final int? statusCode;

  const Failure({required this.message, this.statusCode});

  @override
  List<Object?> get props => [message, statusCode];
}

/// Error de conexión a internet o a servicios externos.
class NetworkFailure extends Failure {
  const NetworkFailure({super.message = 'Sin conexión a internet', super.statusCode});
}

/// Error al consumir APIs de Google Cloud.
class ApiFailure extends Failure {
  const ApiFailure({super.message = 'Error del servicio de traducción', super.statusCode});
}

/// Error de audio (micrófono, reproducción).
class AudioFailure extends Failure {
  const AudioFailure({super.message = 'Error de audio', super.statusCode});
}

/// Error de Bluetooth.
class BluetoothFailure extends Failure {
  const BluetoothFailure({super.message = 'Error de Bluetooth', super.statusCode});
}

/// Error al exportar (PDF, etc).
class ExportFailure extends Failure {
  const ExportFailure({super.message = 'Error al exportar', super.statusCode});
}

/// Error de almacenamiento local.
class StorageFailure extends Failure {
  final Object? originalError;

  const StorageFailure({
    super.message = 'Error de almacenamiento',
    super.statusCode,
    this.originalError,
  });

  @override
  List<Object?> get props => [...super.props, originalError];
}

/// Error genérico / inesperado.
class UnexpectedFailure extends Failure {
  const UnexpectedFailure({
    super.message = 'Ocurrió un error inesperado',
    super.statusCode,
    this.originalError,
  });

  final Object? originalError;

  @override
  List<Object?> get props => [...super.props, originalError];
}
