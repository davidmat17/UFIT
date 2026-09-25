/// Lo que el proveedor de identidad dice de quien acaba de ingresar.
///
/// Es distinto de [Perfil]: la sesión existe apenas Microsoft confirma
/// la identidad, pero el perfil solo existe cuando la persona completa
/// su registro en UFIT (documento, teléfono). Entre una cosa y la otra
/// la app muestra el formulario de registro.
class SesionActiva {
  const SesionActiva({required this.correo, this.nombreCompleto});

  /// Correo de la cuenta de Microsoft, en minúsculas.
  final String correo;

  /// Nombre que trae la cuenta de Microsoft, si lo trae. Solo sirve
  /// para prellenar el formulario de registro.
  final String? nombreCompleto;
}
