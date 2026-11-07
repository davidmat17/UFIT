/// Lo que maneja el administrador en el RF13: respuestas de las funciones
/// de la base y la bitácora
/// (supabase/migraciones/016_rf13_gestion_contenidos.sql).
library;

/// Qué pasó al pedir borrar una máquina o un ejercicio (CU13, 5a).
enum ResultadoEliminacion {
  eliminado,

  /// Lo usan rutinas de alguien: no se borra. Se ofrece dejarlo fuera de
  /// servicio.
  enUso,

  /// Ya no existía (por ejemplo, lo borró otro administrador).
  inexistente,

  desconocido,
}

ResultadoEliminacion resultadoEliminacionDesdeTexto(String? valor) =>
    switch (valor) {
      'eliminada' || 'eliminado' => ResultadoEliminacion.eliminado,
      'en_uso' => ResultadoEliminacion.enUso,
      'inexistente' => ResultadoEliminacion.inexistente,
      _ => ResultadoEliminacion.desconocido,
    };

class RespuestaEliminacion {
  const RespuestaEliminacion({required this.resultado, this.rutinas = 0});

  final ResultadoEliminacion resultado;

  /// Cuántas rutinas lo usan, cuando el resultado es enUso.
  final int rutinas;
}

/// Qué pasó al publicar una versión nueva de la normativa (CU13, 4a, 5b).
enum ResultadoPublicacion { publicada, versionCambio, desconocido }

class RespuestaPublicacion {
  const RespuestaPublicacion({
    required this.resultado,
    this.version,
    this.publicadaEn,
  });

  final ResultadoPublicacion resultado;

  /// La versión publicada, o la que ya estaba si otro administrador se
  /// adelantó.
  final int? version;
  final DateTime? publicadaEn;
}

/// Qué pasó al cambiar el rol o el estado de una persona.
enum ResultadoPersona {
  actualizada,

  /// El administrador intentó quitarse su propio rol o desactivarse.
  propia,
  inexistente,
  desconocido,
}

ResultadoPersona resultadoPersonaDesdeTexto(String? valor) => switch (valor) {
      'actualizada' => ResultadoPersona.actualizada,
      'propia' => ResultadoPersona.propia,
      'inexistente' => ResultadoPersona.inexistente,
      _ => ResultadoPersona.desconocido,
    };

/// Una línea de la bitácora de auditoría.
class EntradaBitacora {
  const EntradaBitacora({
    required this.fecha,
    required this.accion,
    required this.entidad,
    this.persona,
    this.entidadId,
    this.detalle,
  });

  /// En hora de Colombia.
  final DateTime fecha;

  /// crear, editar, eliminar, publicar, asignar_turno, quitar_turno,
  /// acceso_denegado.
  final String accion;

  /// La tabla o el recurso: maquinas, ejercicios, normativa…
  final String entidad;

  /// Nombre de quien lo hizo, o null si se hizo desde el panel de
  /// Supabase.
  final String? persona;
  final String? entidadId;

  /// Los datos del cambio, como texto JSON.
  final String? detalle;
}

/// Los datos de una máquina en el formulario del administrador.
class DatosMaquina {
  const DatosMaquina({
    this.id,
    required this.zonaId,
    required this.nombre,
    this.descripcion,
    required this.cantidad,
    required this.estado,
    this.imagenUrl,
  });

  /// null para crear una nueva.
  final int? id;
  final int zonaId;
  final String nombre;
  final String? descripcion;
  final int cantidad;

  /// 'disponible', 'mantenimiento' o 'retirada'.
  final String estado;
  final String? imagenUrl;
}

/// Los datos de un ejercicio en el formulario del administrador.
class DatosEjercicio {
  const DatosEjercicio({
    this.id,
    required this.nombre,
    required this.grupoMuscular,
    this.descripcion,
    this.instrucciones,
    this.activo = true,
    this.maquinaIds = const <int>[],
  });

  /// null para crear uno nuevo.
  final int? id;
  final String nombre;
  final String grupoMuscular;
  final String? descripcion;
  final String? instrucciones;
  final bool activo;

  /// Las máquinas en las que se hace.
  final List<int> maquinaIds;
}

/// Un ejercicio del catálogo completo, con las máquinas en que se hace.
/// Incluye los dados de baja, que el usuario ya no ve.
class EjercicioAdmin {
  const EjercicioAdmin({
    required this.id,
    required this.nombre,
    required this.grupoMuscular,
    this.descripcion,
    this.instrucciones,
    this.activo = true,
    this.maquinaIds = const <int>[],
    this.actualizadoEn,
  });

  final int id;
  final String nombre;
  final String grupoMuscular;
  final String? descripcion;
  final String? instrucciones;
  final bool activo;
  final List<int> maquinaIds;
  final DateTime? actualizadoEn;
}

/// La normativa como la ve el administrador: la vigente con su versión,
/// que es la base para publicar la siguiente.
class NormativaAdmin {
  const NormativaAdmin({
    required this.titulo,
    required this.contenido,
    required this.version,
    required this.publicadaEn,
  });

  final String titulo;
  final String contenido;
  final int version;

  /// En hora de Colombia.
  final DateTime publicadaEn;
}
