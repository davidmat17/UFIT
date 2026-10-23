/// Traduce lo que entrega Supabase sobre reservas a los modelos del
/// proyecto.
///
/// Vive aparte del adaptador para poder probarse sin red: las pruebas le
/// pasan el JSON tal como lo devuelve la base.
library;

import '../../../core/modelos/reserva.dart';
import '../../../core/modelos/resultado_cancelacion.dart';
import '../../../core/modelos/resultado_reserva.dart';

/// Una fila de la tabla reservas —o el objeto "reserva" que devuelven
/// reservar_cupos() y cancelar_reserva()— convertida en [Reserva].
///
/// Si la consulta trajo la franja embebida (`franjas(hora_inicio,
/// hora_fin)`), también lee sus horas.
Reserva reservaDesdeFila(Map<String, dynamic> fila) {
  final Object? franja = fila['franjas'];
  final Map<dynamic, dynamic> horas =
      franja is Map ? franja : const <String, dynamic>{};
  final Object? inicio = horas['hora_inicio'];
  final Object? fin = horas['hora_fin'];

  return Reserva(
    id: (fila['id'] as num).toInt(),
    perfilId: fila['perfil_id'] as String,
    franjaId: (fila['franja_id'] as num).toInt(),
    fecha: DateTime.parse(fila['fecha'] as String),
    zonaId: (fila['zona_id'] as num).toInt(),
    estado: estadoReservaDesdeTexto(fila['estado'] as String?),
    codigoQr: fila['codigo_qr'] as String,
    horaInicio: inicio is String ? inicio : null,
    horaFin: fin is String ? fin : null,
  );
}

/// La respuesta de reservar_cupos(): una fila por franja con las columnas
/// franja, resultado y reserva (esta última es un objeto JSON o null).
///
/// Devuelve una respuesta por cada franja de [pedidas], en ese orden y sin
/// repetidas. Si la base no dijo nada de alguna, queda como
/// [ResultadoReserva.desconocido]: un fallo, nunca un éxito.
List<ResultadoPorFranja> resultadosDesdeRespuesta(
  Object? datos,
  List<int> pedidas,
) {
  final Map<int, ResultadoPorFranja> porFranja = <int, ResultadoPorFranja>{};

  if (datos is List) {
    for (final Object? fila in datos) {
      if (fila is! Map) continue;

      final Object? franja = fila['franja'];
      if (franja is! num) continue;

      final Object? resultado = fila['resultado'];
      final Object? reserva = fila['reserva'];

      porFranja[franja.toInt()] = ResultadoPorFranja(
        franjaId: franja.toInt(),
        resultado:
            resultadoReservaDesdeTexto(resultado is String ? resultado : null),
        reserva: reserva is Map ? _leerReserva(reserva) : null,
      );
    }
  }

  return <ResultadoPorFranja>[
    for (final int id in pedidas.toSet())
      porFranja[id] ??
          ResultadoPorFranja(
            franjaId: id,
            resultado: ResultadoReserva.desconocido,
          ),
  ];
}

Reserva? _leerReserva(Map<dynamic, dynamic> valor) {
  try {
    return reservaDesdeFila(Map<String, dynamic>.from(valor));
  } catch (_) {
    // Una respuesta con forma inesperada no debe convertir una reserva ya
    // hecha en un error: la persona la verá en sus reservas.
    return null;
  }
}

/// La respuesta de cancelar_reserva(): una sola fila con las columnas
/// resultado, reserva (objeto JSON o null) y horas_antelacion.
///
/// Lo que no se entienda queda como [ResultadoCancelacion.desconocido]:
/// un fallo, nunca un éxito.
RespuestaCancelacion cancelacionDesdeRespuesta(Object? datos) {
  final Object? fila = datos is List && datos.isNotEmpty ? datos.first : datos;
  if (fila is! Map) {
    return const RespuestaCancelacion(
      resultado: ResultadoCancelacion.desconocido,
    );
  }

  final Object? resultado = fila['resultado'];
  final Object? reserva = fila['reserva'];
  final Object? horas = fila['horas_antelacion'];

  return RespuestaCancelacion(
    resultado:
        resultadoCancelacionDesdeTexto(resultado is String ? resultado : null),
    reserva: reserva is Map ? _leerReserva(reserva) : null,
    horasAntelacion: horas is int ? horas : horasAntelacionPorDefecto,
  );
}
