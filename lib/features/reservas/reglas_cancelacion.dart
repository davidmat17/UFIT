/// Reglas del RF3 (cancelar una reserva) que no dependen de pantallas ni
/// de la base de datos. Por eso se pueden probar solas.
///
/// La que manda es la base (cancelar_reserva() en supabase/schema.sql):
/// estas reglas solo sirven para que la pantalla muestre el botón activo
/// o explique por qué no, antes de que la persona lo intente.
library;

import '../../core/modelos/reserva.dart';
import 'reglas_reservas.dart';

/// Cómo se le presenta a la persona una de sus reservas en "Mis reservas".
enum EstadoDeCancelacion {
  /// Confirmada y faltan al menos las horas de antelación: se puede
  /// cancelar.
  sePuede,

  /// Confirmada, pero faltan menos horas de las permitidas (CU03, 4a).
  fueraDePlazo,

  /// El ingreso ya se registró con el QR (CU03, 4b).
  yaAsistida,
}

/// Cuándo empieza la franja de la reserva, en hora de Colombia. null si la
/// reserva llegó sin la hora de su franja.
DateTime? inicioDeReserva(Reserva r) {
  final String? hora = r.horaInicio;
  if (hora == null) return null;
  final int minutos = minutosDe(hora);
  return DateTime(
    r.fecha.year,
    r.fecha.month,
    r.fecha.day,
    minutos ~/ 60,
    minutos % 60,
  );
}

/// Cuándo termina la franja de la reserva. Sin la hora de la franja se
/// toma el final del día.
DateTime finDeReserva(Reserva r) {
  final String? hora = r.horaFin;
  if (hora == null) {
    return DateTime(r.fecha.year, r.fecha.month, r.fecha.day + 1);
  }
  final int minutos = minutosDe(hora);
  return DateTime(
    r.fecha.year,
    r.fecha.month,
    r.fecha.day,
    minutos ~/ 60,
    minutos % 60,
  );
}

/// El último momento en que se puede cancelar: [horas] antes del inicio.
DateTime? limiteParaCancelar(Reserva r, int horas) =>
    inicioDeReserva(r)?.subtract(Duration(hours: horas));

/// La misma regla que aplica la base: se puede cancelar hasta el límite,
/// incluido el minuto exacto.
EstadoDeCancelacion estadoDeCancelacion(
  Reserva r, {
  required DateTime ahora,
  required int horas,
}) {
  if (r.estado == EstadoReserva.asistida) return EstadoDeCancelacion.yaAsistida;

  final DateTime? limite = limiteParaCancelar(r, horas);
  // Sin la hora de la franja la app no puede saberlo; que decida la base.
  if (limite == null) return EstadoDeCancelacion.sePuede;

  return ahora.isAfter(limite)
      ? EstadoDeCancelacion.fueraDePlazo
      : EstadoDeCancelacion.sePuede;
}

/// Las reservas que se muestran en "Mis reservas": confirmadas o con el
/// ingreso ya registrado, cuya franja todavía no termina. Van de la más
/// próxima a la más lejana.
List<Reserva> reservasActivas(Iterable<Reserva> reservas, DateTime ahora) {
  final List<Reserva> activas = reservas
      .where((Reserva r) =>
          (r.estado == EstadoReserva.confirmada ||
              r.estado == EstadoReserva.asistida) &&
          finDeReserva(r).isAfter(ahora))
      .toList();

  activas.sort((Reserva a, Reserva b) {
    final int porFecha = a.fecha.compareTo(b.fecha);
    if (porFecha != 0) return porFecha;
    return minutosDe(a.horaInicio ?? '0').compareTo(minutosDe(b.horaInicio ?? '0'));
  });
  return activas;
}

// ---------------------------------------------------------------------
// Texto en español
// ---------------------------------------------------------------------

/// "1 hora", "3 horas".
String textoDeHoras(int horas) => horas == 1 ? '1 hora' : '$horas horas';

/// "06:00 – 07:00", o vacío si la reserva llegó sin la hora.
String rangoDeReserva(Reserva r) {
  final String? inicio = r.horaInicio;
  final String? fin = r.horaFin;
  if (inicio == null || fin == null) return '';
  return '${horaCorta(inicio)} – ${horaCorta(fin)}';
}

/// "3:00 a. m.", "12:30 p. m.": como se dice la hora en Colombia.
String horaDelReloj(DateTime d) {
  final int h12 = d.hour % 12 == 0 ? 12 : d.hour % 12;
  final String minutos = d.minute.toString().padLeft(2, '0');
  final String sufijo = d.hour < 12 ? 'a. m.' : 'p. m.';
  return '$h12:$minutos $sufijo';
}

/// La frase que acompaña a cada reserva en "Mis reservas".
String explicacionDeCancelacion(
  Reserva r, {
  required DateTime ahora,
  required int horas,
}) {
  final EstadoDeCancelacion estado =
      estadoDeCancelacion(r, ahora: ahora, horas: horas);

  switch (estado) {
    case EstadoDeCancelacion.yaAsistida:
      return 'Ya registraste el ingreso: esta reserva no se puede cancelar.';
    case EstadoDeCancelacion.fueraDePlazo:
      return 'Ya no se puede cancelar: faltan menos de ${textoDeHoras(horas)} '
          'para que empiece.';
    case EstadoDeCancelacion.sePuede:
      final DateTime? limite = limiteParaCancelar(r, horas);
      if (limite == null) return 'Puedes cancelarla.';
      final String dia = mismoDia(limite, ahora)
          ? 'hoy'
          : 'el ${formatearDiaLargo(limite)}';
      // La hora ya termina en "a. m." o "p. m.": no lleva otro punto.
      return 'Puedes cancelarla hasta $dia a las ${horaDelReloj(limite)}';
  }
}
