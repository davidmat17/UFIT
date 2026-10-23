/// Estado de una reserva a lo largo de su vida.
enum EstadoReserva { confirmada, cancelada, asistida, noAsistida }

EstadoReserva estadoReservaDesdeTexto(String? valor) => switch (valor) {
      'cancelada' => EstadoReserva.cancelada,
      'asistida' => EstadoReserva.asistida,
      'no_asistida' => EstadoReserva.noAsistida,
      _ => EstadoReserva.confirmada,
    };

/// Una reserva de cupo en una franja (RF2, RF3, RF4).
class Reserva {
  const Reserva({
    required this.id,
    required this.perfilId,
    required this.franjaId,
    required this.fecha,
    required this.zonaId,
    required this.estado,
    required this.codigoQr,
    this.horaInicio,
    this.horaFin,
  });

  final int id;
  final String perfilId;
  final int franjaId;
  final DateTime fecha;
  final int zonaId;
  final EstadoReserva estado;

  /// Lo que se codifica en el QR de ingreso.
  final String codigoQr;

  /// Hora de la franja como la entrega Postgres ("06:00:00"). Solo viene
  /// cuando la consulta la trae junto con la reserva (misReservas); el
  /// RF3 la necesita para saber hasta cuándo se puede cancelar.
  final String? horaInicio;
  final String? horaFin;

  bool get estaViva =>
      estado == EstadoReserva.confirmada || estado == EstadoReserva.asistida;
}
