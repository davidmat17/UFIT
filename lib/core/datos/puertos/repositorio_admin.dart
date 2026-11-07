import '../../modelos/administracion.dart';
import '../../modelos/estadisticas.dart';
import '../../modelos/maquina.dart';
import '../../modelos/perfil.dart';

/// Puerto de administración (RF12, RF13).
///
/// Todo lo de aquí es solo para el administrador. La barrera real está en
/// la base (políticas de fila y funciones que revisan el rol): si alguien
/// sin el rol llama estos métodos, fallan con un ErrorDeDatos de tipo
/// sinPermiso aunque la app no hubiera ocultado la pantalla.
abstract class RepositorioAdmin {
  // --- RF12: estadísticas ---

  /// Ocupación, asistencia efectiva y uso por zona entre [desde] y
  /// [hasta], opcionalmente solo de una zona o de una hora ("06:00").
  Future<EstadisticasDeUso> estadisticas({
    required DateTime desde,
    required DateTime hasta,
    int? zonaId,
    String? hora,
  });

  // --- RF13: catálogo ---

  /// Todas las máquinas, también las dadas de baja.
  Future<List<Maquina>> maquinas();

  /// Crea (sin id) o actualiza (con id) una máquina.
  Future<void> guardarMaquina(DatosMaquina datos);

  /// Borra una máquina si ninguna rutina la usa (CU13, 5a).
  Future<RespuestaEliminacion> eliminarMaquina(int id);

  /// Cambia solo el estado; es lo que se ofrece cuando no se puede borrar.
  Future<void> cambiarEstadoMaquina(int id, EstadoMaquina estado);

  /// Todos los ejercicios, también los dados de baja.
  Future<List<EjercicioAdmin>> ejercicios();

  /// Crea (sin id) o actualiza (con id) un ejercicio y sus máquinas.
  Future<void> guardarEjercicio(DatosEjercicio datos);

  /// Borra un ejercicio si ninguna rutina lo usa (CU13, 5a).
  Future<RespuestaEliminacion> eliminarEjercicio(int id);

  // --- RF13: normativa y plazo para cancelar ---

  /// La versión más reciente, o null si nunca se publicó ninguna.
  Future<NormativaAdmin?> normativaActual();

  /// Publica una versión nueva. [versionBase] es la que el administrador
  /// tenía en pantalla: si otro publicó después, no se sobrescribe
  /// (CU13, 5b).
  Future<RespuestaPublicacion> publicarNormativa({
    required String titulo,
    required String contenido,
    required int versionBase,
  });

  Future<int> horasAntelacionCancelar();

  Future<void> guardarHorasAntelacionCancelar(int horas);

  // --- RF13: personas e instructores ---

  /// Todas las personas registradas, con su rol.
  Future<List<Perfil>> personas();

  Future<ResultadoPersona> actualizarPersona({
    required String perfilId,
    required RolUsuario rol,
    required bool activo,
    String? especialidad,
  });

  /// Asigna [instructorId] (o quita, si es null) en las franjas de los
  /// [dias] (1 = lunes … 5 = viernes) entre [horaDesde] y [horaHasta]
  /// (horas enteras, 6 a 20), del [desde] al [hasta]. Devuelve cuántas
  /// franjas cambiaron.
  Future<int> asignarTurno({
    String? instructorId,
    required List<int> dias,
    required int horaDesde,
    required int horaHasta,
    required DateTime desde,
    required DateTime hasta,
  });

  // --- RF13: bitácora ---

  /// Las últimas [limite] entradas, de la más reciente a la más antigua.
  Future<List<EntradaBitacora>> bitacora({int limite = 100});
}
