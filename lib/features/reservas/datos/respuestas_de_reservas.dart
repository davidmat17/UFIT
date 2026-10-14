/// Traduce lo que entrega Supabase sobre reservas a los modelos del
/// proyecto.
///
/// Vive aparte del adaptador para poder probarse sin red: las pruebas le
/// pasan el JSON tal como lo devuelve la base.
library;

import '../../../core/modelos/reserva.dart';
import '../../../core/modelos/resultado_reserva.dart';

/// Una fila de la tabla reservas —o el objeto "reserva" que devuelve
/// reservar_cupos()— convertida en [Reserva].
Reserva reservaDesdeFila(Map<String, dynamic> fila) {
  return Reserva(
    id: (fila['id'] as num).toInt(),
    perfilId: fila['perfil_id'] as String,
    franjaId: (fila['franja_id'] as num).toInt(),
    fecha: DateTime.parse(fila['fecha'] as String),
    zonaId: (fila['zona_id'] as num).toInt(),
    estado: estadoReservaDesdeTexto(fila['estado'] as String?),
    codigoQr: fila['codigo_qr'] as String,
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
