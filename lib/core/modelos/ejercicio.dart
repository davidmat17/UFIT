/// Un ejercicio del catálogo (RF5, RF11, RF13).
///
/// Se hace en una o varias máquinas; esa relación vive en la tabla
/// ejercicio_maquina de la base.
class Ejercicio {
  const Ejercicio({
    required this.id,
    required this.nombre,
    required this.grupoMuscular,
    this.descripcion,
    this.instrucciones,
  });

  final int id;
  final String nombre;
  final String grupoMuscular;
  final String? descripcion;

  /// Cómo se ejecuta, paso a paso. Puede faltar si el administrador
  /// todavía no lo ha escrito.
  final String? instrucciones;
}
