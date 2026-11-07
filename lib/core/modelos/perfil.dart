/// Los tres roles del sistema, tal como están en la tabla perfiles.
enum RolUsuario { usuario, instructor, administrador }

/// Como lo guarda la base: 'usuario', 'instructor', 'administrador'.
String rolATexto(RolUsuario rol) => switch (rol) {
      RolUsuario.usuario => 'usuario',
      RolUsuario.instructor => 'instructor',
      RolUsuario.administrador => 'administrador',
    };

/// Para mostrar: 'Usuario', 'Instructor', 'Administrador'.
String nombreDeRol(RolUsuario rol) => switch (rol) {
      RolUsuario.usuario => 'Usuario',
      RolUsuario.instructor => 'Instructor',
      RolUsuario.administrador => 'Administrador',
    };

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
    this.especialidad,
  });

  final String id;
  final String nombre;
  final String apellido;
  final String documento;
  final String correo;
  final String? telefono;
  final RolUsuario rol;
  final bool activo;

  /// Solo para instructores: en qué acompaña (RF7). La escribe el
  /// administrador (RF13).
  final String? especialidad;

  String get nombreCompleto => '$nombre $apellido';

  bool get esAdministrador => rol == RolUsuario.administrador;

  /// Instructor o administrador: puede validar ingresos (RF4).
  bool get esPersonal =>
      rol == RolUsuario.instructor || rol == RolUsuario.administrador;
}
