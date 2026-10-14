/// Reglas del RF2 (reservas de cupos en franjas horarias) que no dependen
/// de pantallas ni de la base de datos. Por eso se pueden probar solas.
library;

import '../../core/modelos/franja_disponible.dart';
import '../../core/modelos/reserva.dart';
import '../../core/modelos/resultado_reserva.dart';

// ---------------------------------------------------------------------
// Fechas y horas
// ---------------------------------------------------------------------

/// La hora de Colombia (UTC-5, sin horario de verano), sin depender de la
/// zona horaria del celular: las franjas están en hora de Bucaramanga.
///
/// Devuelve una fecha "de reloj de pared": sus campos son los que marca el
/// reloj allá, sin conversión de zona. Todas las comparaciones de este
/// archivo usan fechas así.
DateTime ahoraEnColombia() {
  final DateTime c = DateTime.now().toUtc().subtract(const Duration(hours: 5));
  return DateTime(c.year, c.month, c.day, c.hour, c.minute, c.second);
}

DateTime soloFecha(DateTime d) => DateTime(d.year, d.month, d.day);

bool mismoDia(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

/// "2026-10-12": como lo escribe Postgres. También sirve de llave para
/// agrupar por día sin tropezar con horas ni zonas horarias.
String fechaIso(DateTime d) => '${d.year.toString().padLeft(4, '0')}-'
    '${d.month.toString().padLeft(2, '0')}-'
    '${d.day.toString().padLeft(2, '0')}';

/// Días de calendario entre dos fechas (negativo si [hasta] es anterior).
/// Se calcula en UTC para que un cambio de horario no corra el resultado.
int diasEntre(DateTime desde, DateTime hasta) =>
    DateTime.utc(hasta.year, hasta.month, hasta.day)
        .difference(DateTime.utc(desde.year, desde.month, desde.day))
        .inDays;

/// El lunes de la semana de [d]. La semana va de lunes a domingo.
DateTime lunesDeLaSemana(DateTime d) =>
    DateTime(d.year, d.month, d.day - (d.weekday - 1));

/// Los siete días de la semana que empieza en [lunes].
List<DateTime> semanaDesde(DateTime lunes) => <DateTime>[
      for (int i = 0; i < 7; i++)
        DateTime(lunes.year, lunes.month, lunes.day + i),
    ];

/// Cuántas semanas hacia adelante se puede mirar el calendario.
const int horizonteEnSemanas = 8;

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

/// "lun" para 1, "dom" para 7 (como DateTime.weekday).
String nombreCortoDelDia(int diaDeLaSemana) => _diasCortos[diaDeLaSemana - 1];

/// "lunes" para 1, "domingo" para 7 (como DateTime.weekday).
String nombreLargoDelDia(int diaDeLaSemana) => _diasLargos[diaDeLaSemana - 1];

String capitalizar(String texto) =>
    texto.isEmpty ? texto : texto[0].toUpperCase() + texto.substring(1);

/// "lunes 12 de octubre".
String formatearDiaLargo(DateTime f) =>
    '${_diasLargos[f.weekday - 1]} ${f.day} de ${_meses[f.month - 1]}';

/// "lunes 12 de octubre de 2026".
String formatearDiaCompleto(DateTime f) =>
    '${formatearDiaLargo(f)} de ${f.year}';

/// "lun 12 oct", para fichas y listas.
String formatearDiaCorto(DateTime f) => '${_diasCortos[f.weekday - 1]} '
    '${f.day} ${_meses[f.month - 1].substring(0, 3)}';

/// "12 – 18 de octubre de 2026", o con los dos meses si la semana cruza.
String formatearSemana(DateTime lunes) {
  final DateTime domingo = DateTime(lunes.year, lunes.month, lunes.day + 6);
  final String m1 = _meses[lunes.month - 1];
  final String m2 = _meses[domingo.month - 1];

  if (lunes.year != domingo.year) {
    return '${lunes.day} de $m1 de ${lunes.year} – '
        '${domingo.day} de $m2 de ${domingo.year}';
  }
  if (lunes.month != domingo.month) {
    return '${lunes.day} de $m1 – ${domingo.day} de $m2 de ${domingo.year}';
  }
  return '${lunes.day} – ${domingo.day} de $m1 de ${domingo.year}';
}

/// Minutos desde la medianoche de una hora como la entrega Postgres
/// ("06:00:00") o escrita a mano ("6:00").
int minutosDe(String hora) {
  final List<String> partes = hora.split(':');
  final int h = int.tryParse(partes.first) ?? 0;
  final int m = partes.length > 1 ? (int.tryParse(partes[1]) ?? 0) : 0;
  return h * 60 + m;
}

/// "06:00:00" → "06:00".
String horaCorta(String hora) {
  final int minutos = minutosDe(hora);
  return '${(minutos ~/ 60).toString().padLeft(2, '0')}:'
      '${(minutos % 60).toString().padLeft(2, '0')}';
}

/// "06:00 – 07:00".
String formatearRango(FranjaDisponible f) =>
    '${horaCorta(f.horaInicio)} – ${horaCorta(f.horaFin)}';

/// "Quedan 58 cupos", "Queda 1 cupo" o "Sin cupos".
String textoDeCupos(FranjaDisponible f) {
  final int libres = f.cuposDisponibles;
  if (libres <= 0) return 'Sin cupos';
  return libres == 1 ? 'Queda 1 cupo' : 'Quedan $libres cupos';
}

/// Los primeros 8 caracteres del código de la reserva, en mayúsculas:
/// "682325EF". Es lo que se le muestra a la persona; el QR lleva el
/// código completo.
String codigoCorto(String codigoQr) {
  final String limpio = codigoQr.replaceAll('-', '');
  final String ocho = limpio.length <= 8 ? limpio : limpio.substring(0, 8);
  return ocho.toUpperCase();
}

// ---------------------------------------------------------------------
// Estado de una franja y de un día
// ---------------------------------------------------------------------

DateTime _enFecha(DateTime fecha, String hora) {
  final int minutos = minutosDe(hora);
  return DateTime(fecha.year, fecha.month, fecha.day, minutos ~/ 60, minutos % 60);
}

DateTime inicioDe(FranjaDisponible f) => _enFecha(f.fecha, f.horaInicio);

DateTime finDe(FranjaDisponible f) => _enFecha(f.fecha, f.horaFin);

/// La franja ya terminó. Es la misma regla que aplica la base de datos:
/// una franja que está en curso todavía se puede reservar.
bool franjaTermino(FranjaDisponible f, DateTime ahora) =>
    !finDe(f).isAfter(ahora);

bool franjaEnCurso(FranjaDisponible f, DateTime ahora) =>
    !inicioDe(f).isAfter(ahora) && finDe(f).isAfter(ahora);

/// Cómo se le presenta una franja a quien está reservando.
enum EstadoDeFranja {
  /// Abierta, con cupo y sin otra reserva ese día: se puede reservar.
  disponible,

  /// Abierta pero con el aforo completo.
  llena,

  /// El administrador la cerró.
  cerrada,

  /// Ya terminó.
  pasada,

  /// Es la franja que la persona ya reservó ese día.
  tuya,

  /// La persona ya tiene otra franja reservada ese día (máximo una).
  conOtraReserva,
}

/// [reservaDelDia] es la reserva viva de la persona ese día, si tiene.
EstadoDeFranja estadoDeFranja(
  FranjaDisponible franja, {
  required DateTime ahora,
  Reserva? reservaDelDia,
}) {
  if (reservaDelDia != null && reservaDelDia.franjaId == franja.franjaId) {
    return EstadoDeFranja.tuya;
  }
  if (franjaTermino(franja, ahora)) return EstadoDeFranja.pasada;
  if (!franja.abierta) return EstadoDeFranja.cerrada;
  if (franja.cuposDisponibles <= 0) return EstadoDeFranja.llena;
  if (reservaDelDia != null) return EstadoDeFranja.conOtraReserva;
  return EstadoDeFranja.disponible;
}

/// La marca que lleva cada día en la tira de la semana.
enum EstadoDelDia { conCupo, sinCupo, conReserva, pasado, sinFranjas }

EstadoDelDia estadoDelDia({
  required List<FranjaDisponible> franjasDelDia,
  required DateTime ahora,
  Reserva? reservaDelDia,
}) {
  if (franjasDelDia.isEmpty) return EstadoDelDia.sinFranjas;

  final List<EstadoDeFranja> estados = <EstadoDeFranja>[
    for (final FranjaDisponible f in franjasDelDia)
      estadoDeFranja(f, ahora: ahora, reservaDelDia: reservaDelDia),
  ];

  if (estados.contains(EstadoDeFranja.tuya)) return EstadoDelDia.conReserva;
  if (estados.contains(EstadoDeFranja.disponible)) return EstadoDelDia.conCupo;
  if (estados.every((EstadoDeFranja e) => e == EstadoDeFranja.pasada)) {
    return EstadoDelDia.pasado;
  }
  return EstadoDelDia.sinCupo;
}

/// Las reservas vivas (confirmadas o asistidas) por día, con la fecha en
/// formato AAAA-MM-DD. La base solo permite una viva por persona y día.
Map<String, Reserva> reservasVivasPorDia(Iterable<Reserva> reservas) {
  final Map<String, Reserva> porDia = <String, Reserva>{};
  for (final Reserva r in reservas) {
    if (r.estaViva) porDia[fechaIso(r.fecha)] = r;
  }
  return porDia;
}

// ---------------------------------------------------------------------
// Franjas alternativas
// ---------------------------------------------------------------------

/// Cuando una franja está llena: las franjas más cercanas del mismo día
/// en las que sí se puede reservar, de la más cercana a la más lejana. A
/// igual distancia va primero la más temprana.
List<FranjaDisponible> sugerirAlternativas(
  FranjaDisponible llena,
  List<FranjaDisponible> delDia, {
  required DateTime ahora,
  Reserva? reservaDelDia,
  int maximo = 3,
}) {
  final int base = minutosDe(llena.horaInicio);

  final List<FranjaDisponible> candidatas = delDia
      .where((FranjaDisponible f) =>
          f.franjaId != llena.franjaId &&
          estadoDeFranja(f, ahora: ahora, reservaDelDia: reservaDelDia) ==
              EstadoDeFranja.disponible)
      .toList();

  candidatas.sort((FranjaDisponible a, FranjaDisponible b) {
    final int minutosA = minutosDe(a.horaInicio);
    final int minutosB = minutosDe(b.horaInicio);
    final int distanciaA = (minutosA - base).abs();
    final int distanciaB = (minutosB - base).abs();
    if (distanciaA != distanciaB) return distanciaA.compareTo(distanciaB);
    return minutosA.compareTo(minutosB);
  });

  return candidatas.take(maximo).toList();
}

// ---------------------------------------------------------------------
// Reservas recurrentes
//
// Una reserva recurrente son varias reservas normales, una por fecha: la
// app calcula las fechas, busca la franja de la misma hora en cada una y
// se las pide todas juntas a la base (reservar_cupos), que decide franja
// por franja. No hay una tabla de recurrencias.
// ---------------------------------------------------------------------

/// Máximo de semanas que se puede repetir una reserva.
const int maximoDeSemanas = 8;

/// Máximo de reservas por persona en una semana, de lunes a domingo
/// (regla 8 de la normativa). Lo hace cumplir la base; la app lo usa para
/// no dejar marcar más días de los que se pueden reservar.
const int maximoReservasPorSemana = 3;

/// Los días en que abre el gimnasio: de lunes (1) a viernes (5). Son los
/// únicos que se ofrecen para repetir una reserva.
const List<int> diasDeServicio = <int>[1, 2, 3, 4, 5];

/// Semanas que propone la pantalla al activar la repetición.
const int semanasPorDefecto = 4;

/// Las fechas de una reserva recurrente: desde [inicio], durante
/// [semanas] semanas, en los días de la semana de [diasSemana]
/// (1 = lunes … 7 = domingo). Salen en orden y [inicio] cuenta si su día
/// de la semana está en el conjunto.
///
/// Con inicio un lunes 12, lunes y miércoles, 2 semanas:
/// lun 12, mié 14, lun 19, mié 21.
List<DateTime> fechasDeRepeticion({
  required DateTime inicio,
  required Set<int> diasSemana,
  required int semanas,
}) {
  final int cantidad = semanas < 1
      ? 1
      : (semanas > maximoDeSemanas ? maximoDeSemanas : semanas);
  final DateTime desde = soloFecha(inicio);

  final List<DateTime> fechas = <DateTime>[];
  for (int i = 0; i < cantidad * 7; i++) {
    final DateTime dia = DateTime(desde.year, desde.month, desde.day + i);
    if (diasSemana.contains(dia.weekday)) fechas.add(dia);
  }
  return fechas;
}

/// Una fecha de la serie y la franja que le corresponde, si existe.
class ItemDeRepeticion {
  const ItemDeRepeticion({required this.fecha, this.franja});

  final DateTime fecha;

  /// null: ese día no hay una franja publicada a esa hora.
  final FranjaDisponible? franja;
}

/// Busca, para cada fecha, la franja que empieza a la misma hora.
List<ItemDeRepeticion> armarRepeticion({
  required List<DateTime> fechas,
  required String horaInicio,
  required Iterable<FranjaDisponible> franjas,
}) {
  final int minutos = minutosDe(horaInicio);

  // Si hay dos franjas con la misma llave, gana la última.
  final Map<String, FranjaDisponible> porLlave = <String, FranjaDisponible>{
    for (final FranjaDisponible f in franjas)
      '${fechaIso(f.fecha)}|${minutosDe(f.horaInicio)}': f,
  };

  return <ItemDeRepeticion>[
    for (final DateTime fecha in fechas)
      ItemDeRepeticion(
        fecha: fecha,
        franja: porLlave['${fechaIso(fecha)}|$minutos'],
      ),
  ];
}

/// Qué pasó con una de las fechas pedidas.
class LineaDeResultado {
  const LineaDeResultado({
    required this.fecha,
    this.horaInicio,
    this.resultado,
  });

  final DateTime fecha;

  /// Hora de la franja pedida; null si ese día no había franja.
  final String? horaInicio;

  /// La respuesta de la base; null si ese día no había franja y por eso
  /// ni siquiera se pidió.
  final ResultadoReserva? resultado;

  bool get exitoso => resultado?.fueExitoso ?? false;
}

/// Junta cada fecha de la serie con lo que respondió la base.
List<LineaDeResultado> unirResultados(
  List<ItemDeRepeticion> items,
  List<ResultadoPorFranja> resultados,
) {
  final Map<int, ResultadoPorFranja> porFranja = <int, ResultadoPorFranja>{
    for (final ResultadoPorFranja r in resultados) r.franjaId: r,
  };

  return <LineaDeResultado>[
    for (final ItemDeRepeticion item in items)
      LineaDeResultado(
        fecha: item.fecha,
        horaInicio: item.franja?.horaInicio,
        resultado:
            item.franja == null ? null : porFranja[item.franja!.franjaId]?.resultado,
      ),
  ];
}

/// "Se confirmaron 3 de 4 fechas."
String resumenDeResultados(List<LineaDeResultado> lineas) {
  final int total = lineas.length;
  final int confirmadas = lineas.where((LineaDeResultado l) => l.exitoso).length;

  if (confirmadas == total) return 'Quedaron confirmadas las $total reservas.';
  if (confirmadas == 0) {
    return 'No se pudo confirmar ninguna de las $total fechas.';
  }
  return 'Se confirmaron $confirmadas de $total fechas.';
}

/// Una frase corta para cada fecha de la serie.
String etiquetaDeLinea(LineaDeResultado linea) {
  final ResultadoReserva? resultado = linea.resultado;
  if (resultado == null) return 'No hay franja publicada a esa hora';

  return switch (resultado) {
    ResultadoReserva.creada => 'Reservada',
    ResultadoReserva.yaReservada => 'Ya la tenías reservada',
    ResultadoReserva.otraReservaEseDia => 'Ya tenías otra reserva ese día',
    ResultadoReserva.limiteSemanal => 'Ya tenías 3 reservas esa semana',
    ResultadoReserva.sinCupo => 'Sin cupos',
    ResultadoReserva.franjaCerrada => 'Franja cerrada',
    ResultadoReserva.franjaPasada => 'La franja ya terminó',
    ResultadoReserva.franjaInexistente => 'La franja ya no existe',
    ResultadoReserva.desconocido => 'No se pudo reservar',
  };
}
