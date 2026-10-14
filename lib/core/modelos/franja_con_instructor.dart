/// Una franja horaria con el instructor asignado, tal como la entrega la
/// función agenda_instructores() de la base (RF7).
///
/// Si la franja no tiene instructor, [instructor] es null y la pantalla
/// dice "Sin instructor asignado" (CU07, flujo 4b).
///
/// No lleva zona: el instructor trabaja por turnos y está a cargo de todo
/// el gimnasio durante su franja.
class FranjaConInstructor {
  const FranjaConInstructor({
    required this.franjaId,
    required this.fecha,
    required this.horaInicio,
    required this.horaFin,
    required this.abierta,
    this.instructor,
    this.especialidad,
  });

  final int franjaId;
  final DateTime fecha;

  /// Como la entrega Postgres: "06:00:00".
  final String horaInicio;
  final String horaFin;

  /// false si el administrador cerró la franja.
  final bool abierta;

  /// Nombre y apellido del instructor, o null si no tiene.
  final String? instructor;
  final String? especialidad;

  bool get tieneInstructor => instructor != null && instructor!.isNotEmpty;
}
