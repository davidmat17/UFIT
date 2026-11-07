/// Reglas del RF4 (ingreso con QR) que no dependen de pantallas ni de la
/// base de datos. Por eso se pueden probar solas.
///
/// La que manda es la base (validar_ingreso() en
/// supabase/migraciones/015_rf4_asistencia_qr.sql): estas reglas solo
/// sirven para que la persona sepa desde cuándo y hasta cuándo le sirve
/// su código, antes de llegar a la entrada.
library;

import '../../core/modelos/reserva.dart';
import 'reglas_cancelacion.dart';
import 'reglas_reservas.dart';

/// Minutos antes de la franja desde los que el código ya sirve. Es el
/// mismo margen que aplica la base.
const int minutosDeAnticipacion = 15;

/// Cómo está el código de una reserva en este momento.
enum EstadoDelCodigo {
  /// Se puede usar ahora mismo en la entrada.
  vigente,

  /// La franja todavía no llega (faltan más de 15 minutos).
  proximo,

  /// El ingreso ya se registró: el código no sirve otra vez.
  usado,

  /// La franja terminó sin que se registrara el ingreso.
  vencido,

  /// La reserva fue cancelada.
  cancelado,
}

/// Desde cuándo sirve el código: 15 minutos antes del inicio de la
/// franja. null si la reserva llegó sin la hora de su franja.
DateTime? aperturaDelCodigo(Reserva r) => inicioDeReserva(r)
    ?.subtract(const Duration(minutes: minutosDeAnticipacion));

EstadoDelCodigo estadoDelCodigo(Reserva r, DateTime ahora) {
  if (r.estado == EstadoReserva.cancelada) return EstadoDelCodigo.cancelado;
  if (r.estado == EstadoReserva.asistida || r.ingresoEn != null) {
    return EstadoDelCodigo.usado;
  }
  if (!ahora.isBefore(finDeReserva(r))) return EstadoDelCodigo.vencido;

  final DateTime? apertura = aperturaDelCodigo(r);
  if (apertura != null && ahora.isBefore(apertura)) {
    return EstadoDelCodigo.proximo;
  }
  return EstadoDelCodigo.vigente;
}

/// La reserva cuyo código se muestra primero en "Mi código de ingreso":
/// la de hoy si todavía no termina (aunque ya se haya usado, para que la
/// persona vea la confirmación); si no, la próxima confirmada. null si no
/// tiene ninguna.
Reserva? reservaParaElCodigo(Iterable<Reserva> reservas, DateTime ahora) {
  final List<Reserva> activas = reservasActivas(reservas, ahora);
  if (activas.isEmpty) return null;

  for (final Reserva r in activas) {
    if (mismoDia(r.fecha, ahora)) return r;
  }
  for (final Reserva r in activas) {
    if (r.estado == EstadoReserva.confirmada) return r;
  }
  return null;
}

/// La frase debajo del QR.
String explicacionDelCodigo(Reserva r, DateTime ahora) {
  final DateTime? apertura = aperturaDelCodigo(r);
  final DateTime fin = finDeReserva(r);

  switch (estadoDelCodigo(r, ahora)) {
    case EstadoDelCodigo.vigente:
      return 'Muéstralo en la entrada. Sirve una sola vez, hasta las '
          '${horaDelReloj(fin)}';
    case EstadoDelCodigo.proximo:
      if (apertura == null) return 'Tu código todavía no está activo.';
      final String dia = mismoDia(apertura, ahora)
          ? 'hoy'
          : 'el ${formatearDiaLargo(apertura)}';
      return 'Se activa $dia a las ${horaDelReloj(apertura)}, 15 minutos '
          'antes de tu franja.';
    case EstadoDelCodigo.usado:
      final DateTime? ingreso = r.ingresoEn;
      return ingreso == null
          ? 'Ya registraste el ingreso con esta reserva.'
          : 'Ingreso registrado a las ${horaDelReloj(ingreso)}';
    case EstadoDelCodigo.vencido:
      return 'La franja ya terminó y el código venció.';
    case EstadoDelCodigo.cancelado:
      return 'Cancelaste esta reserva, así que el código ya no sirve.';
  }
}

/// Un número de documento razonable para buscar: solo dígitos (y quizá
/// letras, en pasaportes), entre 5 y 15 caracteres. Devuelve el mensaje
/// para el campo o null si está bien.
String? validarDocumentoDeBusqueda(String? valor) {
  final String limpio = (valor ?? '').trim();
  if (limpio.isEmpty) return 'Escribe el número de documento.';
  if (!RegExp(r'^[0-9A-Za-z]{5,15}$').hasMatch(limpio)) {
    return 'Escribe solo el número, sin puntos ni espacios.';
  }
  return null;
}
