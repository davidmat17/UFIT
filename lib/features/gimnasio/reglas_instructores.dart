/// Reglas de la consulta de instructores (RF7) que no dependen de
/// pantallas ni de la base de datos. Por eso se pueden probar solas.
///
/// Algunas funciones de fechas se parecen a las de reservas, pero cada
/// módulo tiene las suyas: un módulo no importa a otro (ver
/// test/arquitectura_test.dart).
library;

import '../../core/modelos/franja_con_instructor.dart';

/// Lo que se muestra cuando una franja no tiene instructor (CU07, 4b).
const String textoSinInstructor = 'Sin instructor asignado';

/// Cuántas semanas hacia adelante se puede consultar.
const int horizonteEnSemanas = 8;

// ---------------------------------------------------------------------
// Fechas
// ---------------------------------------------------------------------

/// La hora de Colombia (UTC-5, sin horario de verano), sin depender de la
/// zona horaria del celular: las franjas están en hora de Bucaramanga.
DateTime ahoraEnColombia() {
  final DateTime c = DateTime.now().toUtc().subtract(const Duration(hours: 5));
  return DateTime(c.year, c.month, c.day, c.hour, c.minute, c.second);
}

DateTime soloFecha(DateTime d) => DateTime(d.year, d.month, d.day);

bool mismoDia(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

/// El lunes de la semana de [d].
DateTime lunesDeLaSemana(DateTime d) =>
    DateTime(d.year, d.month, d.day - (d.weekday - 1));

/// De lunes a viernes de la semana que empieza en [lunes]: los días en
/// que abre el gimnasio.
List<DateTime> diasDeServicio(DateTime lunes) => <DateTime>[
      for (int i = 0; i < 5; i++) DateTime(lunes.year, lunes.month, lunes.day + i),
    ];

/// El día que se muestra al abrir la pantalla: hoy si es de lunes a
/// viernes; el sábado y el domingo, el lunes siguiente.
DateTime primerDiaAMostrar(DateTime hoy) {
  final DateTime d = soloFecha(hoy);
  if (d.weekday <= DateTime.friday) return d;
  return DateTime(d.year, d.month, d.day + (8 - d.weekday));
}

/// Minutos desde la medianoche de una hora como "06:00:00" o "6:00".
int minutosDe(String hora) {
  final List<String> partes = hora.split(':');
  final int h = int.tryParse(partes.first) ?? 0;
  final int m = partes.length > 1 ? (int.tryParse(partes[1]) ?? 0) : 0;
  return h * 60 + m;
}

/// La franja ya terminó, en hora de Colombia.
bool franjaTermino(FranjaConInstructor f, DateTime ahora) {
  final int fin = minutosDe(f.horaFin);
  final DateTime termina =
      DateTime(f.fecha.year, f.fecha.month, f.fecha.day, fin ~/ 60, fin % 60);
  return !termina.isAfter(ahora);
}

// ---------------------------------------------------------------------
// La agenda de un día
// ---------------------------------------------------------------------

/// Las franjas de [dia], de la más temprana a la más tarde.
List<FranjaConInstructor> agendaDelDia(
  Iterable<FranjaConInstructor> agenda,
  DateTime dia,
) {
  final List<FranjaConInstructor> delDia = agenda
      .where((FranjaConInstructor f) => mismoDia(f.fecha, dia))
      .toList()
    ..sort((FranjaConInstructor a, FranjaConInstructor b) =>
        minutosDe(a.horaInicio).compareTo(minutosDe(b.horaInicio)));
  return delDia;
}

/// "Instructor en 10 de 14 franjas", "Sin instructores asignados este día".
String resumenDelDia(List<FranjaConInstructor> delDia) {
  final int con =
      delDia.where((FranjaConInstructor f) => f.tieneInstructor).length;
  if (con == 0) return 'Sin instructores asignados este día';
  if (con == delDia.length) return 'Hay instructor en todas las franjas';
  return 'Instructor en $con de ${delDia.length} franjas';
}

/// El nombre del instructor o "Sin instructor asignado", nunca vacío.
String textoDelInstructor(FranjaConInstructor f) =>
    f.tieneInstructor ? f.instructor! : textoSinInstructor;

/// La especialidad del instructor de la franja. Null si la franja no
/// tiene instructor o si no se registró la especialidad.
String? detalleDelInstructor(FranjaConInstructor f) =>
    f.tieneInstructor ? f.especialidad : null;

// ---------------------------------------------------------------------
// Texto en español
// ---------------------------------------------------------------------

const List<String> _meses = <String>[
  'enero', 'febrero', 'marzo', 'abril', 'mayo', 'junio', 'julio',
  'agosto', 'septiembre', 'octubre', 'noviembre', 'diciembre',
];

const List<String> _diasLargos = <String>[
  'lunes', 'martes', 'miércoles', 'jueves', 'viernes', 'sábado', 'domingo',
];

const List<String> _diasCortos = <String>[
  'lun', 'mar', 'mié', 'jue', 'vie', 'sáb', 'dom',
];

/// "lun" para un lunes.
String diaCorto(DateTime f) => _diasCortos[f.weekday - 1];

/// "Lunes 19 de octubre".
String diaLargo(DateTime f) {
  final String texto =
      '${_diasLargos[f.weekday - 1]} ${f.day} de ${_meses[f.month - 1]}';
  return texto[0].toUpperCase() + texto.substring(1);
}

/// "19 – 23 de octubre de 2026" (de lunes a viernes), con los dos meses o
/// años si la semana cruza.
String semanaDeServicio(DateTime lunes) {
  final DateTime viernes = DateTime(lunes.year, lunes.month, lunes.day + 4);
  final String m1 = _meses[lunes.month - 1];
  final String m2 = _meses[viernes.month - 1];

  if (lunes.year != viernes.year) {
    return '${lunes.day} de $m1 de ${lunes.year} – '
        '${viernes.day} de $m2 de ${viernes.year}';
  }
  if (lunes.month != viernes.month) {
    return '${lunes.day} de $m1 – ${viernes.day} de $m2 de ${viernes.year}';
  }
  return '${lunes.day} – ${viernes.day} de $m1 de ${viernes.year}';
}

/// "06:00:00" → "06:00".
String horaCorta(String hora) {
  final int minutos = minutosDe(hora);
  return '${(minutos ~/ 60).toString().padLeft(2, '0')}:'
      '${(minutos % 60).toString().padLeft(2, '0')}';
}

/// "06:00 – 07:00".
String rangoDe(FranjaConInstructor f) =>
    '${horaCorta(f.horaInicio)} – ${horaCorta(f.horaFin)}';
