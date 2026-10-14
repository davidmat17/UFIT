import 'reserva.dart';

/// Qué pasó al pedir reservar una franja (RF2).
///
/// Cada valor corresponde a uno de los textos que devuelve la función
/// reservar_cupos() de la base de datos (supabase/schema.sql).
enum ResultadoReserva {
  creada,
  yaReservada,
  otraReservaEseDia,
  limiteSemanal,
  sinCupo,
  franjaCerrada,
  franjaPasada,
  franjaInexistente,
  desconocido,
}

ResultadoReserva resultadoReservaDesdeTexto(String? valor) => switch (valor) {
      'creada' => ResultadoReserva.creada,
      'ya_reservada' => ResultadoReserva.yaReservada,
      'otra_reserva_ese_dia' => ResultadoReserva.otraReservaEseDia,
      'limite_semanal' => ResultadoReserva.limiteSemanal,
      'sin_cupo' => ResultadoReserva.sinCupo,
      'franja_cerrada' => ResultadoReserva.franjaCerrada,
      'franja_pasada' => ResultadoReserva.franjaPasada,
      'franja_inexistente' => ResultadoReserva.franjaInexistente,
      // Un código que esta versión de la app no conoce: se trata como
      // fallo, nunca como éxito.
      _ => ResultadoReserva.desconocido,
    };

extension TextoDeResultadoReserva on ResultadoReserva {
  /// Hay una reserva a nombre de la persona para esa franja.
  bool get fueExitoso =>
      this == ResultadoReserva.creada || this == ResultadoReserva.yaReservada;

  /// Texto para la persona, sin jerga.
  String get mensaje => switch (this) {
        ResultadoReserva.creada => 'Reserva confirmada.',
        ResultadoReserva.yaReservada => 'Ya tenías esta franja reservada.',
        ResultadoReserva.otraReservaEseDia =>
          'Ya tienes otra reserva ese día. Solo se permite una por día; '
              'cancélala si quieres cambiarla.',
        ResultadoReserva.limiteSemanal =>
          'Ya tienes 3 reservas esa semana. La normativa del gimnasio '
              'permite máximo 3 por semana.',
        ResultadoReserva.sinCupo => 'Esta franja ya no tiene cupos.',
        ResultadoReserva.franjaCerrada => 'Esta franja está cerrada.',
        ResultadoReserva.franjaPasada => 'Esta franja ya terminó.',
        ResultadoReserva.franjaInexistente =>
          'Esta franja ya no existe. Actualiza el calendario.',
        ResultadoReserva.desconocido => 'No se pudo reservar esta franja.',
      };
}

/// La respuesta de la base para una de las franjas pedidas.
class ResultadoPorFranja {
  const ResultadoPorFranja({
    required this.franjaId,
    required this.resultado,
    this.reserva,
  });

  final int franjaId;
  final ResultadoReserva resultado;

  /// La reserva vigente de la persona en esa franja. Solo viene cuando
  /// [resultado] es [ResultadoReserva.creada] o
  /// [ResultadoReserva.yaReservada].
  final Reserva? reserva;

  bool get exitoso => resultado.fueExitoso;
}
