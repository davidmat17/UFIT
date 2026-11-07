import 'ejercicio.dart';

/// Estado de una máquina del gimnasio.
enum EstadoMaquina { disponible, mantenimiento, retirada }

/// Como lo guarda la base.
String estadoMaquinaATexto(EstadoMaquina e) => switch (e) {
      EstadoMaquina.disponible => 'disponible',
      EstadoMaquina.mantenimiento => 'mantenimiento',
      EstadoMaquina.retirada => 'retirada',
    };

/// Para mostrar. Son los mismos nombres del catálogo (RF5): una máquina
/// en mantenimiento sale como "Fuera de servicio"; una retirada está dada
/// de baja y el catálogo ya no la muestra.
String nombreDeEstadoMaquina(EstadoMaquina e) => switch (e) {
      EstadoMaquina.disponible => 'Disponible',
      EstadoMaquina.mantenimiento => 'Fuera de servicio',
      EstadoMaquina.retirada => 'Dada de baja',
    };

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
    this.ejercicios = const <Ejercicio>[],
  });

  final int id;
  final int zonaId;
  final String nombre;
  final String? descripcion;
  final int cantidad;
  final EstadoMaquina estado;
  final String? imagenUrl;

  /// Los ejercicios que se pueden hacer en esta máquina (RF5).
  final List<Ejercicio> ejercicios;

  bool get estaDisponible => estado == EstadoMaquina.disponible;
}
