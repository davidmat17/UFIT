/// Una zona del gimnasio: cardiovascular, fuerza o musculación.
class Zona {
  const Zona({
    required this.id,
    required this.nombre,
    this.descripcion,
    this.activa = true,
  });

  final int id;
  final String nombre;
  final String? descripcion;
  final bool activa;
}
