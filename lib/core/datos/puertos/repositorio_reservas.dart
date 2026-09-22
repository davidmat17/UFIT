import '../../modelos/franja_disponible.dart';
import '../../modelos/reserva.dart';

/// Puerto de reservas y asistencia (RF2, RF3, RF4, RF9).
abstract class RepositorioReservas {
  /// Las franjas de una semana con su ocupación, para el calendario.
  Future<List<FranjaDisponible>> disponibilidad({
    required DateTime desde,
    required DateTime hasta,
  });

  Future<Reserva> reservar({required int franjaId, required int zonaId});

  Future<void> cancelar(int reservaId);

  Future<List<Reserva>> misReservas({DateTime? desde, DateTime? hasta});

  /// Registra el ingreso a partir del código del QR (RF4).
  Future<Reserva> registrarAsistencia(String codigoQr);
}
