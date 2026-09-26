import '../../modelos/perfil.dart';
import '../../modelos/sesion.dart';

/// Puerto de cuenta y perfil (RF1, RF8, RF10).
///
/// Define qué necesita el módulo, no cómo se consigue. La implementación
/// contra Supabase vive en lib/features/cuenta/datos/.
///
/// El ingreso es solo con la cuenta institucional de Microsoft: no hay
/// contraseñas propias de UFIT. "Registrarse" es ingresar por primera
/// vez y completar los datos que Microsoft no entrega.
abstract class RepositorioPerfiles {
  /// Abre la página de inicio de sesión de Microsoft. Termina cuando la
  /// página se abre, no cuando la persona ingresa: el resultado llega
  /// después por [cambiosDeSesion].
  Future<void> iniciarSesionInstitucional();

  /// Avisa cada vez que alguien inicia o cierra sesión.
  Stream<void> get cambiosDeSesion;

  /// Quién tiene la sesión abierta según Microsoft, o null si nadie.
  SesionActiva? sesionActual();

  /// Crea el perfil de quien tiene la sesión abierta. El correo no se
  /// pide: sale de la sesión. Lanza [ErrorDeDatos] si el documento ya
  /// está registrado o si el correo no es institucional.
  Future<Perfil> completarRegistro({
    required String nombre,
    required String apellido,
    required String documento,
    String? telefono,
  });

  Future<void> cerrarSesion();

  /// El perfil de quien tiene la sesión abierta, o null si no hay nadie
  /// o si todavía no completó el registro.
  Future<Perfil?> perfilActual();

  Future<Perfil> actualizarPerfil({
    required String nombre,
    required String apellido,
    String? telefono,
  });
}
