import '../../modelos/perfil.dart';

/// Puerto de cuenta y perfil (RF1, RF8, RF10).
///
/// Define qué necesita el módulo, no cómo se consigue. La implementación
/// contra Supabase vive en lib/features/cuenta/datos/.
abstract class RepositorioPerfiles {
  /// Crea la cuenta y su perfil. Lanza [ErrorDeDatos] si el correo ya
  /// existe o si la contraseña no cumple las reglas.
  Future<Perfil> registrar({
    required String correo,
    required String contrasena,
    required String nombre,
    required String apellido,
    required String documento,
    String? telefono,
  });

  Future<Perfil> iniciarSesion({
    required String correo,
    required String contrasena,
  });

  Future<void> cerrarSesion();

  /// El perfil de quien tiene la sesión abierta, o null si no hay nadie.
  Future<Perfil?> perfilActual();

  Future<Perfil> actualizarPerfil({
    required String nombre,
    required String apellido,
    String? telefono,
  });
}
