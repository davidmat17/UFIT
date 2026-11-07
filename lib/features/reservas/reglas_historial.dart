/// Reglas del RF9 (historial de reservas y asistencia) que no dependen de
/// pantallas ni de la base de datos. Por eso se pueden probar solas.
library;

import '../../core/modelos/reserva.dart';
import '../../core/modelos/rutina.dart';
import 'reglas_cancelacion.dart';
import 'reglas_reservas.dart';

/// Cómo quedó cada reserva en el historial (CU09, paso 4).
enum EstadoEnHistorial {
  /// Se registró el ingreso con el QR o a mano.
  asistida,

  /// La franja terminó sin ingreso.
  noAsistida,

  /// La persona la canceló.
  cancelada,

  /// Todavía no llega o está en curso.
  proxima,
}

EstadoEnHistorial estadoEnHistorial(Reserva r, DateTime ahora) {
  if (r.estado == EstadoReserva.cancelada) return EstadoEnHistorial.cancelada;
  if (r.estado == EstadoReserva.asistida || r.ingresoEn != null) {
    return EstadoEnHistorial.asistida;
  }
  if (r.estado == EstadoReserva.noAsistida) return EstadoEnHistorial.noAsistida;
  return finDeReserva(r).isAfter(ahora)
      ? EstadoEnHistorial.proxima
      : EstadoEnHistorial.noAsistida;
}

String nombreDeEstado(EstadoEnHistorial e) => switch (e) {
      EstadoEnHistorial.asistida => 'Asistida',
      EstadoEnHistorial.noAsistida => 'No asistida',
      EstadoEnHistorial.cancelada => 'Cancelada',
      EstadoEnHistorial.proxima => 'Próxima',
    };

/// Un rango de fechas, ambas incluidas.
class RangoDeFechas {
  const RangoDeFechas(this.desde, this.hasta);

  final DateTime desde;
  final DateTime hasta;

  /// El mes completo de [fecha].
  factory RangoDeFechas.mes(DateTime fecha) => RangoDeFechas(
        DateTime(fecha.year, fecha.month),
        DateTime(fecha.year, fecha.month + 1, 0),
      );

  /// true si va del primero al último día de un mismo mes.
  bool get esUnMes =>
      desde.day == 1 &&
      desde.year == hasta.year &&
      desde.month == hasta.month &&
      DateTime(hasta.year, hasta.month, hasta.day + 1).day == 1;

  RangoDeFechas mesAnterior() =>
      RangoDeFechas.mes(DateTime(desde.year, desde.month - 1));

  RangoDeFechas mesSiguiente() =>
      RangoDeFechas.mes(DateTime(desde.year, desde.month + 1));

  /// "Noviembre de 2026" o "2 – 15 de noviembre de 2026".
  String get titulo {
    if (esUnMes) {
      return '${capitalizar(nombreDelMes(desde.month))} de ${desde.year}';
    }
    final String fin =
        '${hasta.day} de ${nombreDelMes(hasta.month)} de ${hasta.year}';
    if (desde.year == hasta.year && desde.month == hasta.month) {
      return '${desde.day} – $fin';
    }
    if (desde.year == hasta.year) {
      return '${desde.day} de ${nombreDelMes(desde.month)} – $fin';
    }
    return '${desde.day} de ${nombreDelMes(desde.month)} de ${desde.year} – '
        '$fin';
  }
}

/// CU09, 3a: el rango es inválido si la fecha inicial es posterior a la
/// final. Devuelve el mensaje o null si está bien.
String? validarRango(DateTime desde, DateTime hasta) {
  if (soloFecha(desde).isAfter(soloFecha(hasta))) {
    return 'La fecha inicial no puede ser posterior a la final.';
  }
  if (diasEntre(desde, hasta) > 370) {
    return 'Consulta como máximo un año a la vez.';
  }
  return null;
}

/// Las reservas de la más reciente a la más antigua, como se leen en un
/// historial.
List<Reserva> ordenarParaHistorial(Iterable<Reserva> reservas) {
  final List<Reserva> lista = reservas.toList();
  lista.sort((Reserva a, Reserva b) {
    final int porFecha = b.fecha.compareTo(a.fecha);
    if (porFecha != 0) return porFecha;
    return minutosDe(b.horaInicio ?? '0').compareTo(minutosDe(a.horaInicio ?? '0'));
  });
  return lista;
}

/// Los totales del resumen de arriba.
class ResumenDeHistorial {
  const ResumenDeHistorial({
    required this.asistidas,
    required this.noAsistidas,
    required this.canceladas,
    required this.proximas,
  });

  final int asistidas;
  final int noAsistidas;
  final int canceladas;
  final int proximas;

  int get total => asistidas + noAsistidas + canceladas + proximas;

  /// Las que ya pasaron y no se cancelaron: sobre esas se mide la
  /// asistencia.
  int get cumplidasOPerdidas => asistidas + noAsistidas;

  /// Porcentaje de asistencia, de 0 a 100, o null si todavía no hay
  /// reservas pasadas.
  int? get porcentajeDeAsistencia => cumplidasOPerdidas == 0
      ? null
      : (asistidas * 100 / cumplidasOPerdidas).round();
}

ResumenDeHistorial resumir(Iterable<Reserva> reservas, DateTime ahora) {
  int asistidas = 0, noAsistidas = 0, canceladas = 0, proximas = 0;
  for (final Reserva r in reservas) {
    switch (estadoEnHistorial(r, ahora)) {
      case EstadoEnHistorial.asistida:
        asistidas++;
      case EstadoEnHistorial.noAsistida:
        noAsistidas++;
      case EstadoEnHistorial.cancelada:
        canceladas++;
      case EstadoEnHistorial.proxima:
        proximas++;
    }
  }
  return ResumenDeHistorial(
    asistidas: asistidas,
    noAsistidas: noAsistidas,
    canceladas: canceladas,
    proximas: proximas,
  );
}

/// Las rutinas que tocaban el día de la reserva: las que tienen al menos
/// un ejercicio ese día de la semana (RF9, "rutinas asociadas a cada
/// sesión"). Una reserva cancelada no tiene rutina asociada.
List<String> rutinasDelDia(Reserva r, Iterable<Rutina> rutinas) {
  if (r.estado == EstadoReserva.cancelada) return const <String>[];
  final int dia = r.fecha.weekday;
  return <String>[
    for (final Rutina rutina in rutinas)
      if (rutina.ejercicios
          .any((EjercicioDeRutina e) => e.dias.contains(dia)))
        rutina.nombre,
  ];
}
