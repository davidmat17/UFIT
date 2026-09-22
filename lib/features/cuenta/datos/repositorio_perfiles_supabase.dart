import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/datos/errores.dart';
import '../../../core/datos/puertos/repositorio_perfiles.dart';
import '../../../core/modelos/perfil.dart';
import '../../../core/supabase/supabase_config.dart';
import '../../../core/supabase/traductor_errores.dart';

/// Adaptador del puerto de cuenta contra Supabase (RF1, RF10).
class RepositorioPerfilesSupabase implements RepositorioPerfiles {
  const RepositorioPerfilesSupabase();

  SupabaseClient get _bd => SupabaseConfig.cliente;

  Perfil _desdeFila(Map<String, dynamic> f) => Perfil(
        id: f['id'] as String,
        nombre: f['nombre'] as String,
        apellido: f['apellido'] as String,
        documento: f['documento'] as String,
        correo: f['correo'] as String,
        telefono: f['telefono'] as String?,
        rol: rolDesdeTexto(f['rol'] as String?),
        activo: (f['activo'] as bool?) ?? true,
      );

  @override
  Future<Perfil> registrar({
    required String correo,
    required String contrasena,
    required String nombre,
    required String apellido,
    required String documento,
    String? telefono,
  }) async {
    try {
      final AuthResponse respuesta = await _bd.auth.signUp(
        email: correo,
        password: contrasena,
      );

      final User? usuario = respuesta.user;
      if (usuario == null) {
        throw const ErrorDeDatos(
          TipoDeError.desconocido,
          'No se pudo crear la cuenta. Inténtalo de nuevo.',
        );
      }

      final Map<String, dynamic> fila = await _bd
          .from('perfiles')
          .insert(<String, dynamic>{
            'id': usuario.id,
            'nombre': nombre,
            'apellido': apellido,
            'documento': documento,
            'correo': correo,
            'telefono': telefono,
          })
          .select()
          .single();

      return _desdeFila(fila);
    } catch (e) {
      throw traducirError(e, 'No se pudo completar el registro');
    }
  }

  @override
  Future<Perfil> iniciarSesion({
    required String correo,
    required String contrasena,
  }) async {
    try {
      await _bd.auth.signInWithPassword(email: correo, password: contrasena);

      final Perfil? perfil = await perfilActual();
      if (perfil == null) {
        throw const ErrorDeDatos(
          TipoDeError.noEncontrado,
          'La cuenta existe pero no tiene perfil asociado. Avisa al administrador.',
        );
      }
      return perfil;
    } catch (e) {
      throw traducirError(e, 'No se pudo iniciar sesión');
    }
  }

  @override
  Future<void> cerrarSesion() async {
    try {
      await _bd.auth.signOut();
    } catch (e) {
      throw traducirError(e, 'No se pudo cerrar la sesión');
    }
  }

  @override
  Future<Perfil?> perfilActual() async {
    final User? usuario = _bd.auth.currentUser;
    if (usuario == null) return null;

    try {
      final Map<String, dynamic>? fila =
          await _bd.from('perfiles').select().eq('id', usuario.id).maybeSingle();

      return fila == null ? null : _desdeFila(fila);
    } catch (e) {
      throw traducirError(e, 'No se pudo cargar tu perfil');
    }
  }

  @override
  Future<Perfil> actualizarPerfil({
    required String nombre,
    required String apellido,
    String? telefono,
  }) async {
    final User? usuario = _bd.auth.currentUser;
    if (usuario == null) {
      throw const ErrorDeDatos(
        TipoDeError.sinPermiso,
        'Debes iniciar sesión para actualizar tus datos.',
      );
    }

    try {
      final Map<String, dynamic> fila = await _bd
          .from('perfiles')
          .update(<String, dynamic>{
            'nombre': nombre,
            'apellido': apellido,
            'telefono': telefono,
          })
          .eq('id', usuario.id)
          .select()
          .single();

      return _desdeFila(fila);
    } catch (e) {
      throw traducirError(e, 'No se pudieron guardar tus datos');
    }
  }
}
