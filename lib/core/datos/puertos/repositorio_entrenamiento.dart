import '../../modelos/rutina.dart';

/// Puerto de entrenamiento (RF11).
///
/// Crear y eliminar pasan por funciones de la base (crear_rutina y
/// eliminar_rutina), que hacen cumplir el máximo de 3 rutinas, guardan la
/// rutina completa en una sola transacción y responden qué pasó.
abstract class RepositorioEntrenamiento {
  /// Las rutinas de quien tiene la sesión abierta, de la más antigua a la
  /// más nueva, cada una con sus ejercicios en orden.
  Future<List<Rutina>> misRutinas();

  /// Crea una rutina con todos sus ejercicios.
  ///
  /// [solicitudId] lo genera la pantalla una vez por formulario: si la red
  /// falla y se reintenta con el mismo, la base no crea otra rutina
  /// (responde [ResultadoCrearRutina.yaCreada]). Falla con un ErrorDeDatos
  /// cuando no hay conexión o los datos no son válidos.
  Future<RespuestaCrearRutina> crearRutina({
    required String nombre,
    required List<LineaNuevaRutina> ejercicios,
    required String solicitudId,
  });

  /// Elimina una rutina propia con sus ejercicios. Eliminarla dos veces no
  /// es un error: la segunda responde [ResultadoEliminarRutina.yaEliminada].
  Future<ResultadoEliminarRutina> eliminarRutina(int rutinaId);
}
