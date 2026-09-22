import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/datos/puertos/repositorio_reservas.dart';
import '../../../core/modelos/franja_disponible.dart';
import '../../../core/modelos/reserva.dart';
import '../../../core/supabase/supabase_config.dart';
import '../../../core/supabase/traductor_errores.dart';

/// Adaptador del puerto de reservas contra Supabase (RF2, RF3, RF4, RF9).
///
/// Responsable: David. La disponibilidad ya está implementada porque es
/// lo que necesita el calendario; el resto se completa al trabajar cada
/// requerimiento.
class RepositorioReservasSupabase implements RepositorioReservas {
  const RepositorioReservasSupabase();

  SupabaseClient get _bd => SupabaseConfig.cliente;

  @override
  Future<List<FranjaDisponible>> disponibilidad({
    required DateTime desde,
    required DateTime hasta,
  }) async {
    String soloFecha(DateTime d) =>
        '${d.year.toString().padLeft(4, '0')}-'
        '${d.month.toString().padLeft(2, '0')}-'
        '${d.day.toString().padLeft(2, '0')}';

    try {
      final List<Map<String, dynamic>> filas = await _bd
          .from('vista_disponibilidad')
          .select('franja_id, fecha, hora_inicio, hora_fin, cupo_total, cupos_ocupados, estado')
          .gte('fecha', soloFecha(desde))
          .lte('fecha', soloFecha(hasta))
          .order('fecha')
          .order('hora_inicio');

      return filas
          .map((Map<String, dynamic> f) => FranjaDisponible(
                franjaId: f['franja_id'] as int,
                fecha: DateTime.parse(f['fecha'] as String),
                horaInicio: f['hora_inicio'] as String,
                horaFin: f['hora_fin'] as String,
                cupoTotal: f['cupo_total'] as int,
                cuposOcupados: (f['cupos_ocupados'] as num).toInt(),
                abierta: (f['estado'] as String?) == 'abierta',
              ))
          .toList();
    } catch (e) {
      throw traducirError(e, 'No se pudo consultar la disponibilidad');
    }
  }

  @override
  Future<Reserva> reservar({required int franjaId, required int zonaId}) {
    throw UnimplementedError('Pendiente: RF2, responsable David');
  }

  @override
  Future<void> cancelar(int reservaId) {
    throw UnimplementedError('Pendiente: RF3, responsable David');
  }

  @override
  Future<List<Reserva>> misReservas({DateTime? desde, DateTime? hasta}) {
    throw UnimplementedError('Pendiente: RF9, responsable David');
  }

  @override
  Future<Reserva> registrarAsistencia(String codigoQr) {
    throw UnimplementedError('Pendiente: RF4, responsable David');
  }
}
