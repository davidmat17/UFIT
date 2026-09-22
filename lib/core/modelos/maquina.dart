/// Estado de una máquina del gimnasio.
enum EstadoMaquina { disponible, mantenimiento, retirada }

EstadoMaquina estadoMaquinaDesdeTexto(String? valor) => switch (valor) {
      'mantenimiento' => EstadoMaquina.mantenimiento,
      'retirada' => EstadoMaquina.retirada,
      _ => EstadoMaquina.disponible,
    };

/// Una máquina del catálogo (RF5, RF13).
class Maquina {
  const Maquina({
    required this.id,
    required this.zonaId,
    required this.nombre,
    this.descripcion,
    this.cantidad = 1,
    this.estado = EstadoMaquina.disponible,
    this.imagenUrl,
  });

  final int id;
  final int zonaId;
  final String nombre;
  final String? descripcion;
  final int cantidad;
  final EstadoMaquina estado;
  final String? imagenUrl;

  bool get estaDisponible => estado == EstadoMaquina.disponible;
}
