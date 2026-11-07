/// Reglas del módulo de administración (RF12, RF13) que no dependen de
/// pantallas ni de la base de datos. Por eso se pueden probar solas.
///
/// Los límites son los mismos que las restricciones de la base
/// (migración 016): si la app y la base no coinciden, la base gana.
library;

import '../../core/modelos/administracion.dart';
import '../../core/modelos/estadisticas.dart';

// ---------------------------------------------------------------------
// Fechas y horas (el módulo no importa los de reservas)
// ---------------------------------------------------------------------

const List<String> _meses = <String>[
  'enero', 'febrero', 'marzo', 'abril', 'mayo', 'junio', 'julio',
  'agosto', 'septiembre', 'octubre', 'noviembre', 'diciembre',
];

const List<String> diasLaborales = <String>[
  'Lunes', 'Martes', 'Miércoles', 'Jueves', 'Viernes',
];

/// La hora del reloj en Colombia (UTC-5, sin horario de verano).
DateTime ahoraEnColombia() {
  final DateTime c = DateTime.now().toUtc().subtract(const Duration(hours: 5));
  return DateTime(c.year, c.month, c.day, c.hour, c.minute, c.second);
}

DateTime soloFecha(DateTime d) => DateTime(d.year, d.month, d.day);

/// "9 de noviembre de 2026".
String fechaLarga(DateTime d) => '${d.day} de ${_meses[d.month - 1]} de ${d.year}';

/// "9 nov".
String fechaCorta(DateTime d) => '${d.day} ${_meses[d.month - 1].substring(0, 3)}';

/// "3:05 p. m.".
String horaDelReloj(DateTime d) {
  final int h12 = d.hour % 12 == 0 ? 12 : d.hour % 12;
  final String m = d.minute.toString().padLeft(2, '0');
  return '$h12:$m ${d.hour < 12 ? 'a. m.' : 'p. m.'}';
}

/// "6:00 a. m." para una hora entera.
String horaEntera(int hora) => horaDelReloj(DateTime(2000, 1, 1, hora));

/// El gimnasio abre de 6 a 20: estas son las horas en que empieza una
/// franja.
const int horaApertura = 6;
const int horaCierre = 20;

// ---------------------------------------------------------------------
// Validaciones por campo (CU13, 5c)
// ---------------------------------------------------------------------

String? validarNombre(String? valor) {
  final int n = (valor ?? '').trim().length;
  if (n == 0) return 'Este campo es obligatorio.';
  if (n < 2) return 'Escribe al menos 2 caracteres.';
  if (n > 80) return 'Máximo 80 caracteres.';
  return null;
}

String? validarGrupoMuscular(String? valor) {
  final int n = (valor ?? '').trim().length;
  if (n == 0) return 'Este campo es obligatorio.';
  if (n < 2) return 'Escribe al menos 2 caracteres.';
  if (n > 40) return 'Máximo 40 caracteres.';
  return null;
}

String? validarCantidad(String? valor) {
  final int? n = int.tryParse((valor ?? '').trim());
  if (n == null) return 'Escribe un número entero.';
  if (n < 1 || n > 100) return 'Entre 1 y 100.';
  return null;
}

String? validarTextoLargo(String? valor, {int maximo = 1000}) {
  if ((valor ?? '').length > maximo) return 'Máximo $maximo caracteres.';
  return null;
}

/// La foto se sube al almacenamiento de Supabase y aquí se pega su
/// dirección pública. Debe ser https.
String? validarImagenUrl(String? valor) {
  final String t = (valor ?? '').trim();
  if (t.isEmpty) return null;
  final Uri? uri = Uri.tryParse(t);
  if (uri == null || uri.scheme != 'https' || uri.host.isEmpty) {
    return 'Debe ser una dirección que empiece por https://';
  }
  return null;
}

String? validarTituloNormativa(String? valor) {
  final int n = (valor ?? '').trim().length;
  if (n < 3) return 'Escribe un título de al menos 3 caracteres.';
  if (n > 120) return 'Máximo 120 caracteres.';
  return null;
}

String? validarContenidoNormativa(String? valor) {
  final int n = (valor ?? '').trim().length;
  if (n < 10) return 'Escribe el reglamento (al menos 10 caracteres).';
  if (n > 20000) return 'Máximo 20000 caracteres.';
  return null;
}

/// CU13 para turnos y CU12 3a: la fecha final no puede ser anterior a la
/// inicial, ni el rango más largo que [maximoDias].
String? validarRangoDeFechas(DateTime desde, DateTime hasta,
    {int maximoDias = 366}) {
  final DateTime a = soloFecha(desde);
  final DateTime b = soloFecha(hasta);
  if (a.isAfter(b)) return 'La fecha inicial no puede ser posterior a la final.';
  final int dias = DateTime.utc(b.year, b.month, b.day)
      .difference(DateTime.utc(a.year, a.month, a.day))
      .inDays;
  if (dias > maximoDias) return 'El rango puede tener máximo $maximoDias días.';
  return null;
}

String? validarTurno({
  required Set<int> dias,
  required int horaDesde,
  required int horaHasta,
}) {
  if (dias.isEmpty) return 'Elige al menos un día.';
  if (horaHasta <= horaDesde) {
    return 'La hora final debe ser posterior a la inicial.';
  }
  return null;
}

// ---------------------------------------------------------------------
// Textos de las respuestas
// ---------------------------------------------------------------------

String mensajeDeEliminacion(RespuestaEliminacion r, {required String que}) =>
    switch (r.resultado) {
      ResultadoEliminacion.eliminado => '$que se eliminó del catálogo.',
      ResultadoEliminacion.enUso =>
        'No se puede eliminar: lo ${r.rutinas == 1 ? 'usa 1 rutina' : 'usan ${r.rutinas} rutinas'} '
            'de usuarios.',
      ResultadoEliminacion.inexistente =>
        'Ya no existía. Actualizamos la lista.',
      ResultadoEliminacion.desconocido =>
        'No se pudo eliminar. Inténtalo de nuevo.',
    };

String mensajeDePersona(ResultadoPersona r) => switch (r) {
      ResultadoPersona.actualizada => 'Cambios guardados.',
      ResultadoPersona.propia =>
        'No puedes quitarte el rol de administrador ni desactivar tu propia '
            'cuenta.',
      ResultadoPersona.inexistente => 'Esa persona ya no existe.',
      ResultadoPersona.desconocido =>
        'No se pudo guardar. Inténtalo de nuevo.',
    };

/// "Asignar turno" en la bitácora → texto para leer.
String accionLegible(EntradaBitacora e) {
  final String que = switch (e.entidad) {
    'maquinas' => 'máquina',
    'ejercicios' => 'ejercicio',
    'ejercicio_maquina' => 'máquina de un ejercicio',
    'normativa' => 'normativa',
    'asignaciones_instructor' => 'turno de instructor',
    'configuracion' => 'configuración',
    'perfiles' => 'persona',
    'estadisticas_uso' => 'estadísticas',
    _ => e.entidad,
  };
  return switch (e.accion) {
    'crear' => 'Creó $que',
    'editar' => 'Editó $que',
    'eliminar' => 'Eliminó $que',
    'publicar' => 'Publicó una versión de la normativa',
    'asignar_turno' => 'Asignó un turno de instructor',
    'quitar_turno' => 'Quitó un turno de instructor',
    'acceso_denegado' => 'Intento sin permiso: $que',
    _ => '${e.accion} $que',
  };
}

// ---------------------------------------------------------------------
// Estadísticas (RF12)
// ---------------------------------------------------------------------

/// "42,5 %".
String porcentaje(double? valor) {
  if (valor == null) return '—';
  final String t = valor.toStringAsFixed(1).replaceAll('.', ',');
  return '${t.endsWith(',0') ? t.substring(0, t.length - 2) : t} %';
}

/// Las horas con más y con menos ocupación (CU12, paso 5). Solo cuentan
/// las que tuvieron franjas. null si no hay ninguna.
({UsoPorGrupo mayor, UsoPorGrupo menor})? extremosDeOcupacion(
    List<UsoPorGrupo> porHora) {
  final List<UsoPorGrupo> con =
      porHora.where((UsoPorGrupo g) => g.franjas > 0 && g.ocupacion != null).toList();
  if (con.isEmpty) return null;
  UsoPorGrupo mayor = con.first;
  UsoPorGrupo menor = con.first;
  for (final UsoPorGrupo g in con) {
    if (g.ocupacion! > mayor.ocupacion!) mayor = g;
    if (g.ocupacion! < menor.ocupacion!) menor = g;
  }
  return (mayor: mayor, menor: menor);
}

/// El reporte en CSV, para copiar y pegar en una hoja de cálculo (CU12,
/// 4a). Separado por punto y coma, que es lo que espera Excel en
/// español.
String reporteCsv(EstadisticasDeUso e) {
  final ResumenDeUso r = e.resumen;
  final StringBuffer b = StringBuffer()
    ..writeln('Reporte UFIT;${fechaLarga(e.desde)};${fechaLarga(e.hasta)}')
    ..writeln()
    ..writeln('Indicador;Valor')
    ..writeln('Franjas;${r.franjas}')
    ..writeln('Reservas hechas;${r.reservas}')
    ..writeln('Asistidas;${r.asistidas}')
    ..writeln('No asistidas;${r.noAsistidas}')
    ..writeln('Pendientes;${r.pendientes}')
    ..writeln('Canceladas;${r.canceladas}')
    ..writeln('Asistencia efectiva;${porcentaje(r.asistenciaEfectiva)}')
    ..writeln('Ocupación promedio;${porcentaje(r.ocupacionPromedio)}')
    ..writeln()
    ..writeln('Hora;Franjas;Reservas;Asistidas;Ocupación');
  for (final UsoPorGrupo g in e.porHora) {
    b.writeln('${g.etiqueta};${g.franjas};${g.reservas};${g.asistidas};'
        '${porcentaje(g.ocupacion)}');
  }
  b
    ..writeln()
    ..writeln('Día;Franjas;Reservas;Asistidas;Ocupación');
  for (final UsoPorGrupo g in e.porDia) {
    b.writeln('${g.etiqueta};${g.franjas};${g.reservas};${g.asistidas};'
        '${porcentaje(g.ocupacion)}');
  }
  b
    ..writeln()
    ..writeln('Zona;Reservas;Asistidas;No asistidas;Canceladas');
  for (final UsoPorGrupo g in e.porZona) {
    b.writeln('${g.etiqueta};${g.reservas};${g.asistidas};${g.noAsistidas};'
        '${g.canceladas}');
  }
  return b.toString();
}
