import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/datos/errores.dart';
import '../../../core/datos/puertos/repositorio_reservas.dart';
import '../../../core/modelos/franja_disponible.dart';
import '../../../core/modelos/reserva.dart';
import '../../../core/modelos/resultado_cancelacion.dart';
import '../../../core/modelos/resultado_reserva.dart';
import '../../../core/supabase/supabase_config.dart';
import '../../../core/supabase/traductor_errores.dart';
import '../reglas_reservas.dart' show fechaIso;
import 'respuestas_de_reservas.dart';

/// Adaptador del puerto de reservas contra Supabase (RF2, RF3, RF4, RF9).
///
/// Aquí están completos el RF2 (la disponibilidad, reservar una franja y
/// reservar varias a la vez) y el RF3 (cancelar). El registro de
/// asistencia (RF4) y el historial (RF9) se completan al trabajar cada
/// requerimiento.
///
/// Las reservas no se insertan ni se modifican desde la app: pasan por
/// las funciones reservar_cupos() y cancelar_reserva() de la base, que
/// garantizan el aforo y el plazo para cancelar (supabase/schema.sql).
class RepositorioReservasSupabase implements RepositorioReservas {
  const RepositorioReservasSupabase();

  SupabaseClient get _bd => SupabaseConfig.cliente;

  @override
  Future<List<FranjaDisponible>> disponibilidad({
    required DateTime desde,
    required DateTime hasta,
  }) async {
    try {
      final List<Map<String, dynamic>> filas = await _bd
          .from('vista_disponibilidad')
          .select('franja_id, fecha, hora_inicio, hora_fin, cupo_total, cupos_ocupados, estado')
          .gte('fecha', fechaIso(desde))
          .lte('fecha', fechaIso(hasta))
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
  Future<Reserva> reservar({required int franjaId, required int zonaId}) async {
    final List<ResultadoPorFranja> respuesta =
        await reservarFranjas(franjaIds: <int>[franjaId], zonaId: zonaId);
    final ResultadoPorFranja r = respuesta.first;

    if (!r.exitoso) {
      throw ErrorDeDatos(TipoDeError.reglaDeNegocio, r.resultado.mensaje);
    }

    final Reserva? reserva = r.reserva;
    if (reserva == null) {
      throw const ErrorDeDatos(
        TipoDeError.desconocido,
        'La reserva quedó registrada, pero no se pudo leer la respuesta. '
        'Revisa tus reservas.',
      );
    }
    return reserva;
  }

  @override
  Future<List<ResultadoPorFranja>> reservarFranjas({
    required List<int> franjaIds,
    required int zonaId,
  }) async {
    // Sin repetidas y en el mismo orden en que se pidieron.
    final List<int> pedidas = franjaIds.toSet().toList();
    if (pedidas.isEmpty) return <ResultadoPorFranja>[];

    try {
      final Object? datos = await _bd.rpc(
        'reservar_cupos',
        params: <String, dynamic>{
          'p_franjas': pedidas,
          'p_zona_id': zonaId,
        },
      );
      return resultadosDesdeRespuesta(datos, pedidas);
    } catch (e) {
      // Lo que no depende de una franja (sin sesión, cuenta inactiva, zona
      // inválida) llega como una excepción con el mensaje listo para
      // mostrar. Reintentar es seguro: una franja ya reservada responde
      // ya_reservada y no se duplica.
      throw traducirError(e, 'No se pudo confirmar la reserva');
    }
  }

  @override
  Future<RespuestaCancelacion> cancelar(int reservaId) async {
    try {
      final Object? datos = await _bd.rpc(
        'cancelar_reserva',
        params: <String, dynamic>{'p_reserva_id': reservaId},
      );
      return cancelacionDesdeRespuesta(datos);
    } catch (e) {
      // Sin sesión llega como excepción con el mensaje listo para mostrar.
      // Reintentar es seguro: una reserva ya cancelada responde
      // ya_cancelada.
      throw traducirError(e, 'No se pudo cancelar la reserva');
    }
  }

  @override
  Future<int> horasAntelacionCancelar() async {
    try {
      final Map<String, dynamic>? fila = await _bd
          .from('configuracion')
          .select('horas_antelacion_cancelar')
          .maybeSingle();
      final Object? horas = fila?['horas_antelacion_cancelar'];
      return horas is int ? horas : horasAntelacionPorDefecto;
    } catch (e) {
      throw traducirError(e, 'No se pudo consultar el plazo para cancelar');
    }
  }

  @override
  Future<List<Reserva>> misReservas({DateTime? desde, DateTime? hasta}) async {
    try {
      final User? usuario = _bd.auth.currentUser;
      if (usuario == null) {
        throw const ErrorDeDatos(
          TipoDeError.credencialesInvalidas,
          'Inicia sesión para ver tus reservas.',
        );
      }

      // El filtro por persona es necesario aunque haya políticas de fila:
      // quien administra puede ver las reservas de todos.
      var consulta = _bd
          .from('reservas')
          .select('id, perfil_id, franja_id, fecha, zona_id, estado, codigo_qr, '
              'franjas(hora_inicio, hora_fin)')
          .eq('perfil_id', usuario.id);
      if (desde != null) consulta = consulta.gte('fecha', fechaIso(desde));
      if (hasta != null) consulta = consulta.lte('fecha', fechaIso(hasta));

      final List<Map<String, dynamic>> filas =
          await consulta.order('fecha').order('franja_id');

      return filas.map(reservaDesdeFila).toList();
    } catch (e) {
      throw traducirError(e, 'No se pudieron cargar tus reservas');
    }
  }

  @override
  Future<Reserva> registrarAsistencia(String codigoQr) {
    throw UnimplementedError('Pendiente: RF4, responsable David');
  }
}
