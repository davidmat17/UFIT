import 'reserva.dart';

/// Qué pasó al pedir cancelar una reserva (RF3).
///
/// Cada valor corresponde a uno de los textos que devuelve la función
/// cancelar_reserva() de la base de datos (supabase/schema.sql).
enum ResultadoCancelacion {
  /// Se canceló ahora y el cupo quedó libre.
  cancelada,

  /// Ya estaba cancelada, por ejemplo desde otro dispositivo (CU03, 4c).
  yaCancelada,

  /// El ingreso ya se registró con el QR (CU03, 4b).
  yaAsistida,

  /// Faltan menos horas de las permitidas, o la franja ya pasó (CU03, 4a).
  fueraDePlazo,

  /// No existe o no es de quien la pide.
  inexistente,

  /// Un texto que esta versión de la app no conoce.
  desconocido,
}

ResultadoCancelacion resultadoCancelacionDesdeTexto(String? valor) =>
    switch (valor) {
      'cancelada' => ResultadoCancelacion.cancelada,
      'ya_cancelada' => ResultadoCancelacion.yaCancelada,
      'ya_asistida' => ResultadoCancelacion.yaAsistida,
      'fuera_de_plazo' => ResultadoCancelacion.fueraDePlazo,
      'inexistente' => ResultadoCancelacion.inexistente,
      // Se trata como fallo, nunca como éxito.
      _ => ResultadoCancelacion.desconocido,
    };

/// Las horas de antelación si la base no dice otra cosa. Es el valor por
/// defecto de configuracion.horas_antelacion_cancelar.
const int horasAntelacionPorDefecto = 3;

/// La respuesta de la base al pedir cancelar.
class RespuestaCancelacion {
  const RespuestaCancelacion({
    required this.resultado,
    this.reserva,
    this.horasAntelacion = horasAntelacionPorDefecto,
  });

  final ResultadoCancelacion resultado;

  /// La reserva tal como quedó. null si no existe o no se pudo leer.
  final Reserva? reserva;

  /// El plazo vigente en la base, para explicar la restricción con el
  /// número correcto aunque el administrador lo haya cambiado.
  final int horasAntelacion;

  bool get fueCancelada => resultado == ResultadoCancelacion.cancelada;

  /// Texto para la persona, sin jerga.
  String get mensaje => switch (resultado) {
        ResultadoCancelacion.cancelada =>
          'Reserva cancelada. El cupo quedó libre para otra persona.',
        ResultadoCancelacion.yaCancelada =>
          'Esta reserva ya estaba cancelada. Actualizamos tu lista.',
        ResultadoCancelacion.yaAsistida =>
          'Ya registraste el ingreso con esta reserva, así que no se puede '
              'cancelar.',
        ResultadoCancelacion.fueraDePlazo =>
          'Ya no se puede cancelar: las reservas se cancelan hasta '
              '${_horas(horasAntelacion)} antes de que empiece la franja.',
        ResultadoCancelacion.inexistente =>
          'No encontramos esta reserva. Actualizamos tu lista.',
        ResultadoCancelacion.desconocido =>
          'No se pudo cancelar la reserva. Inténtalo de nuevo.',
      };
}

/// "1 hora", "3 horas".
String _horas(int n) => n == 1 ? '1 hora' : '$n horas';
