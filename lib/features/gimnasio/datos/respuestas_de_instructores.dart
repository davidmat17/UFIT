/// Traduce lo que entrega agenda_instructores() (RF7) al modelo del
/// proyecto.
///
/// Vive aparte del adaptador para poder probarse sin red: las pruebas le
/// pasan el JSON tal como lo devuelve la base.
library;

import '../../../core/modelos/franja_con_instructor.dart';

/// Una fila por franja. Las filas con forma inesperada se saltan en vez
/// de tumbar toda la agenda.
List<FranjaConInstructor> agendaDesdeRespuesta(Object? datos) {
  if (datos is! List) return <FranjaConInstructor>[];

  final List<FranjaConInstructor> agenda = <FranjaConInstructor>[];
  for (final Object? fila in datos) {
    if (fila is! Map) continue;
    try {
      agenda.add(FranjaConInstructor(
        franjaId: (fila['franja_id'] as num).toInt(),
        fecha: DateTime.parse(fila['fecha'] as String),
        horaInicio: fila['hora_inicio'] as String,
        horaFin: fila['hora_fin'] as String,
        abierta: (fila['abierta'] as bool?) ?? true,
        instructor: _textoONulo(fila['instructor']),
        especialidad: _textoONulo(fila['especialidad']),
      ));
    } catch (_) {
      continue;
    }
  }
  return agenda;
}

/// Un texto vacío o con solo espacios cuenta como que no hay dato.
String? _textoONulo(Object? valor) {
  if (valor is! String) return null;
  final String limpio = valor.trim();
  return limpio.isEmpty ? null : limpio;
}
