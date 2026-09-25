/// Una franja horaria con su ocupación, tal como la entrega la
/// vista_disponibilidad. Es lo que pinta el calendario del RF2 en verde
/// o en rojo.
class FranjaDisponible {
  const FranjaDisponible({
    required this.franjaId,
    required this.fecha,
    required this.horaInicio,
    required this.horaFin,
    required this.cupoTotal,
    required this.cuposOcupados,
    required this.abierta,
  });

  final int franjaId;
  final DateTime fecha;
  final String horaInicio;
  final String horaFin;
  final int cupoTotal;
  final int cuposOcupados;
  final bool abierta;

  int get cuposDisponibles => cupoTotal - cuposOcupados;

  /// La regla que decide el color en el calendario.
  bool get hayCupo => abierta && cuposDisponibles > 0;
}
