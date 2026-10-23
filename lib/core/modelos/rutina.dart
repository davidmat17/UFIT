/// Rutinas de ejercicio (RF11).
library;

/// Un ejercicio dentro de una rutina, como se consulta.
class EjercicioDeRutina {
  const EjercicioDeRutina({
    required this.ejercicioId,
    required this.nombreEjercicio,
    required this.dias,
    this.series,
    this.repeticiones,
    this.minutos,
    this.grupoMuscular,
    this.maquinaId,
    this.nombreMaquina,
  });

  final int ejercicioId;
  final String nombreEjercicio;
  final String? grupoMuscular;

  /// null si la máquina se retiró del catálogo después de crear la rutina.
  final int? maquinaId;
  final String? nombreMaquina;

  /// Días de la semana: 1 = lunes … 5 = viernes, en orden.
  final List<int> dias;

  /// Las tres son opcionales, pero cada ejercicio trae repeticiones,
  /// minutos o ambos: la caminata se mide en tiempo y el press de banca
  /// en repeticiones.
  final int? series;
  final int? repeticiones;
  final int? minutos;
}

/// Una rutina de la persona, con sus ejercicios en orden.
class Rutina {
  const Rutina({
    required this.id,
    required this.nombre,
    required this.ejercicios,
    this.creadaEn,
  });

  final int id;
  final String nombre;
  final DateTime? creadaEn;
  final List<EjercicioDeRutina> ejercicios;
}

/// Un ejercicio de una rutina nueva, como se envía a la base.
class LineaNuevaRutina {
  const LineaNuevaRutina({
    required this.ejercicioId,
    required this.maquinaId,
    required this.dias,
    this.series,
    this.repeticiones,
    this.minutos,
  });

  final int ejercicioId;
  final int maquinaId;
  final List<int> dias;
  final int? series;
  final int? repeticiones;
  final int? minutos;

  /// Como lo espera crear_rutina() en p_ejercicios.
  Map<String, dynamic> aJson() => <String, dynamic>{
        'ejercicio_id': ejercicioId,
        'maquina_id': maquinaId,
        'dias': dias,
        'series': series,
        'repeticiones': repeticiones,
        'minutos': minutos,
      };
}

// ---------------------------------------------------------------------
// Respuestas de la base
// ---------------------------------------------------------------------

/// Qué pasó al pedir crear una rutina. Cada valor corresponde a uno de los
/// textos que devuelve crear_rutina() (supabase/schema.sql).
enum ResultadoCrearRutina {
  creada,

  /// La misma solicitud ya se había guardado: fue un reintento.
  yaCreada,

  /// Ya tiene 3 rutinas (CU11, 7c).
  maximoRutinas,

  /// Ya tiene otra rutina con ese nombre.
  nombreRepetido,

  /// Un texto que esta versión de la app no conoce.
  desconocido,
}

ResultadoCrearRutina resultadoCrearRutinaDesdeTexto(String? valor) =>
    switch (valor) {
      'creada' => ResultadoCrearRutina.creada,
      'ya_creada' => ResultadoCrearRutina.yaCreada,
      'maximo_rutinas' => ResultadoCrearRutina.maximoRutinas,
      'nombre_repetido' => ResultadoCrearRutina.nombreRepetido,
      // Se trata como fallo, nunca como éxito.
      _ => ResultadoCrearRutina.desconocido,
    };

class RespuestaCrearRutina {
  const RespuestaCrearRutina({required this.resultado, this.rutinaId});

  final ResultadoCrearRutina resultado;
  final int? rutinaId;

  /// La rutina quedó guardada (ahora o en un intento anterior).
  bool get fueGuardada =>
      resultado == ResultadoCrearRutina.creada ||
      resultado == ResultadoCrearRutina.yaCreada;

  String get mensaje => switch (resultado) {
        ResultadoCrearRutina.creada ||
        ResultadoCrearRutina.yaCreada =>
          'Rutina creada correctamente',
        ResultadoCrearRutina.maximoRutinas =>
          'Ya tienes 3 rutinas. Elimina una para crear otra.',
        ResultadoCrearRutina.nombreRepetido =>
          'Ya tienes una rutina con ese nombre.',
        ResultadoCrearRutina.desconocido =>
          'No se pudo guardar la rutina. Inténtalo de nuevo.',
      };
}

/// Qué pasó al pedir eliminar una rutina (eliminar_rutina()).
enum ResultadoEliminarRutina {
  eliminada,

  /// Ya no existía, por ejemplo porque se eliminó desde otro dispositivo
  /// (CU11, 3c).
  yaEliminada,

  desconocido,
}

ResultadoEliminarRutina resultadoEliminarRutinaDesdeTexto(String? valor) =>
    switch (valor) {
      'eliminada' => ResultadoEliminarRutina.eliminada,
      'ya_eliminada' => ResultadoEliminarRutina.yaEliminada,
      _ => ResultadoEliminarRutina.desconocido,
    };

extension TextoDeEliminarRutina on ResultadoEliminarRutina {
  String get mensaje => switch (this) {
        ResultadoEliminarRutina.eliminada =>
          'Rutina eliminada. Ya tienes un cupo libre para crear otra.',
        ResultadoEliminarRutina.yaEliminada =>
          'Esta rutina ya fue eliminada.',
        ResultadoEliminarRutina.desconocido =>
          'No se pudo eliminar la rutina. Inténtalo de nuevo.',
      };
}
