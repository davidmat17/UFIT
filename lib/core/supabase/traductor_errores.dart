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
      'No se pudo verificar tu cuenta institucional. '
      'Vuelve a ingresar con tu correo de la UIS.',
      causa: e,
    );
  }

  if (e is PostgrestException) {
    // Permiso negado por las políticas de fila o por los permisos de
    // columna (por ejemplo, intentar cambiarse el rol).
    if (e.code == '42501' || e.message.contains('row-level security')) {
      return ErrorDeDatos(
        TipoDeError.sinPermiso,
        'No tienes permiso para ver o modificar esta información.',
        causa: e,
      );
    }

    // Valor repetido en una columna única.
    if (e.code == '23505') {
      return ErrorDeDatos(
        TipoDeError.reglaDeNegocio,
        _mensajeDeDuplicado(e.message),
        causa: e,
      );
    }

    // Restricción CHECK de la base.
    if (e.code == '23514' &&
        e.message.contains('perfiles_correo_institucional')) {
      return ErrorDeDatos(
        TipoDeError.reglaDeNegocio,
        'Solo se aceptan correos institucionales de la UIS.',
        causa: e,
      );
    }

    // Una medida fuera del rango que acepta la base (RF8).
    if (e.code == '23514' && e.message.contains('medidas_antropometricas')) {
      return ErrorDeDatos(
        TipoDeError.reglaDeNegocio,
        'Alguna de las medidas está fuera del rango permitido. Revísalas.',
        causa: e,
      );
    }

    // Un campo del catálogo vacío, muy largo o con un formato inválido
    // (RF13, CU13 5c). Los formularios lo revisan antes; esto es por si
    // acaso.
    if (e.code == '23514' &&
        (e.message.contains('maquinas') || e.message.contains('ejercicios'))) {
      return ErrorDeDatos(
        TipoDeError.reglaDeNegocio,
        e.message.contains('imagen_url')
            ? 'La dirección de la imagen debe empezar por https://.'
            : 'Algún campo está vacío, es muy largo o no es válido. Revísalo.',
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

String _mensajeDeDuplicado(String detalle) {
  if (detalle.contains('documento')) {
    return 'Ya existe una cuenta registrada con ese número de documento.';
  }
  if (detalle.contains('correo')) {
    return 'Ese correo ya tiene una cuenta en UFIT.';
  }
  if (detalle.contains('maquinas_zona_id_nombre')) {
    return 'Ya existe una máquina con ese nombre en esa zona.';
  }
  if (detalle.contains('ejercicios_nombre')) {
    return 'Ya existe un ejercicio con ese nombre.';
  }
  if (detalle.contains('perfiles_pkey')) {
    return 'Tu cuenta ya estaba registrada.';
  }
  return 'Ese dato ya está registrado.';
}
