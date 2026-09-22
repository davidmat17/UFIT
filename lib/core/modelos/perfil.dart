/// Los tres roles del sistema, tal como están en la tabla perfiles.
enum RolUsuario { usuario, instructor, administrador }

RolUsuario rolDesdeTexto(String? valor) => switch (valor) {
      'administrador' => RolUsuario.administrador,
      'instructor' => RolUsuario.instructor,
      _ => RolUsuario.usuario,
    };

/// Una persona registrada. Corresponde a la tabla perfiles.
class Perfil {
  const Perfil({
    required this.id,
    required this.nombre,
    required this.apellido,
    required this.documento,
    required this.correo,
    this.telefono,
    this.rol = RolUsuario.usuario,
    this.activo = true,
  });

  final String id;
  final String nombre;
  final String apellido;
  final String documento;
  final String correo;
  final String? telefono;
  final RolUsuario rol;
  final bool activo;

  String get nombreCompleto => '$nombre $apellido';

  bool get esAdministrador => rol == RolUsuario.administrador;
}
