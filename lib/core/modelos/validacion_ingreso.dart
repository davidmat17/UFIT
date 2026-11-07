import 'reserva.dart';

/// Qué pasó al validar un ingreso en la entrada del gimnasio (RF4).
///
/// Cada valor corresponde a uno de los textos que devuelven las funciones
/// validar_ingreso() y validar_ingreso_manual() de la base de datos
/// (supabase/migraciones/015_rf4_asistencia_qr.sql).
enum ResultadoValidacion {
  /// Se registró el ingreso ahora.
  valido,

  /// El código ya se había usado (CU04, 4a).
  yaValidado,

  /// Faltan más de 15 minutos para que empiece la franja (CU04, 4b).
  temprano,

  /// La franja ya terminó (CU04, 4b).
  vencido,

  /// La reserva fue cancelada (CU04, 4c).
  cancelada,

  /// El código no corresponde a ninguna reserva (CU04, 4c).
  inexistente,

  /// Un texto que esta versión de la app no conoce.
  desconocido,
}

ResultadoValidacion resultadoValidacionDesdeTexto(String? valor) =>
    switch (valor) {
      'valido' => ResultadoValidacion.valido,
      'ya_validado' => ResultadoValidacion.yaValidado,
      'temprano' => ResultadoValidacion.temprano,
      'vencido' => ResultadoValidacion.vencido,
      'cancelada' => ResultadoValidacion.cancelada,
      'inexistente' => ResultadoValidacion.inexistente,
      // Se trata como rechazo, nunca como ingreso válido.
      _ => ResultadoValidacion.desconocido,
    };

/// La respuesta de la base al validar un ingreso. Lleva los datos que el
/// personal necesita para reconocer a la persona en la entrada.
class RespuestaValidacion {
  const RespuestaValidacion({
    required this.resultado,
    this.reserva,
    this.persona,
    this.documento,
    this.horaInicio,
    this.horaFin,
    this.zona,
    this.registradaEn,
  });

  final ResultadoValidacion resultado;

  /// La reserva tal como quedó. null si el código no existe.
  final Reserva? reserva;

  /// Nombre y apellido de quien reservó.
  final String? persona;
  final String? documento;

  /// Como la entrega Postgres: "06:00:00".
  final String? horaInicio;
  final String? horaFin;

  /// Nombre de la zona reservada.
  final String? zona;

  /// Cuándo se registró el ingreso, en hora de Colombia. Viene cuando el
  /// resultado es [ResultadoValidacion.valido] o
  /// [ResultadoValidacion.yaValidado].
  final DateTime? registradaEn;

  bool get esValido => resultado == ResultadoValidacion.valido;

  /// Título corto para el personal, en la tarjeta del resultado.
  String get titulo => switch (resultado) {
        ResultadoValidacion.valido => 'Ingreso válido',
        ResultadoValidacion.yaValidado => 'Código ya validado',
        ResultadoValidacion.temprano => 'Todavía no es su franja',
        ResultadoValidacion.vencido => 'Código vencido',
        ResultadoValidacion.cancelada => 'Reserva cancelada',
        ResultadoValidacion.inexistente => 'Código no válido',
        ResultadoValidacion.desconocido => 'No se pudo validar',
      };

  /// Explicación para el personal, sin jerga.
  String get mensaje => switch (resultado) {
        ResultadoValidacion.valido =>
          'Se registró la hora de llegada. Puede ingresar.',
        ResultadoValidacion.yaValidado =>
          'Este código ya se usó para ingresar. No permitas un segundo '
              'ingreso con la misma reserva.',
        ResultadoValidacion.temprano =>
          'La reserva es para otra franja. El código sirve desde 15 minutos '
              'antes de que empiece.',
        ResultadoValidacion.vencido =>
          'La franja de esta reserva ya terminó. La persona necesita una '
              'reserva para la franja actual.',
        ResultadoValidacion.cancelada =>
          'La persona canceló esta reserva. Necesita una reserva activa '
              'para ingresar.',
        ResultadoValidacion.inexistente =>
          'El código no corresponde a ninguna reserva de UFIT. Pídele a la '
              'persona que abra su código en la app o búscala por documento.',
        ResultadoValidacion.desconocido =>
          'La respuesta no se pudo interpretar. Inténtalo de nuevo.',
      };
}

/// Una reserva de hoy encontrada por número de documento, para validar a
/// mano cuando la persona no puede mostrar el código (CU04, 3a).
class ReservaDeHoy {
  const ReservaDeHoy({
    required this.reservaId,
    required this.persona,
    required this.documento,
    required this.horaInicio,
    required this.horaFin,
    required this.zona,
    required this.estado,
    required this.validada,
  });

  final int reservaId;
  final String persona;
  final String documento;

  /// Como la entrega Postgres: "06:00:00".
  final String horaInicio;
  final String horaFin;
  final String zona;
  final EstadoReserva estado;

  /// true si el ingreso de esta reserva ya se registró.
  final bool validada;
}
