import 'package:supabase_flutter/supabase_flutter.dart';

import '../datos/errores.dart';

/// Traduce las excepciones del SDK de Supabase a los errores del
/// proyecto.
///
/// Vive junto al cliente, en el núcleo, porque es infraestructura: es el
/// mismo trabajo para los cinco módulos. Lo importante es que ninguna
/// pantalla vea jamás un PostgrestException.
ErrorDeDatos traducirError(Object e, String mensajeGeneral) {
  if (e is ErrorDeDatos) return e;

  if (e is AuthException) {
    return ErrorDeDatos(
      TipoDeError.credencialesInvalidas,
      'Correo o contraseña incorrectos.',
      causa: e,
    );
  }

  if (e is PostgrestException) {
    if (e.code == '42501' || e.message.contains('row-level security')) {
      return ErrorDeDatos(
        TipoDeError.sinPermiso,
        'No tienes permiso para ver o modificar esta información.',
        causa: e,
      );
    }
    return ErrorDeDatos(TipoDeError.reglaDeNegocio, e.message, causa: e);
  }

  return ErrorDeDatos(
    TipoDeError.sinConexion,
    '$mensajeGeneral. Revisa tu conexión a internet e inténtalo de nuevo.',
    causa: e,
  );
}
