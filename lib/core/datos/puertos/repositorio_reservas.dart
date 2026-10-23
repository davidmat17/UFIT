import '../../modelos/franja_disponible.dart';
import '../../modelos/reserva.dart';
import '../../modelos/resultado_cancelacion.dart';
import '../../modelos/resultado_reserva.dart';

/// Puerto de reservas y asistencia (RF2, RF3, RF4, RF9).
abstract class RepositorioReservas {
  /// Las franjas de una semana con su ocupación, para el calendario.
  Future<List<FranjaDisponible>> disponibilidad({
    required DateTime desde,
    required DateTime hasta,
  });

  /// Reserva una franja (RF2). Falla con un ErrorDeDatos, con el motivo
  /// en español, si la franja no se puede reservar. Reintentar una
  /// reserva que ya existe devuelve esa misma reserva.
  Future<Reserva> reservar({required int franjaId, required int zonaId});

  /// Reserva varias franjas de una vez, en una sola transacción (RF2).
  ///
  /// Es la vía de las reservas recurrentes: la app calcula las franjas y
  /// la base decide franja por franja, así que algunas pueden quedar
  /// reservadas y otras no. Devuelve una respuesta por cada franja pedida,
  /// en el mismo orden y sin repetidas.
  Future<List<ResultadoPorFranja>> reservarFranjas({
    required List<int> franjaIds,
    required int zonaId,
  });

  /// Cancela una reserva propia (RF3). La base revisa el plazo y el
  /// estado y responde qué pasó; cancelar dos veces es seguro (la segunda
  /// responde [ResultadoCancelacion.yaCancelada]). Falla con un
  /// ErrorDeDatos solo cuando no hay sesión o no hay conexión.
  Future<RespuestaCancelacion> cancelar(int reservaId);

  /// Cuántas horas antes de la franja se puede cancelar (RF3). Lo
  /// configura el administrador; por defecto, 3.
  Future<int> horasAntelacionCancelar();

  /// Las reservas de quien tiene la sesión abierta, con la hora de su
  /// franja.
  Future<List<Reserva>> misReservas({DateTime? desde, DateTime? hasta});

  /// Registra el ingreso a partir del código del QR (RF4).
  Future<Reserva> registrarAsistencia(String codigoQr);
}
