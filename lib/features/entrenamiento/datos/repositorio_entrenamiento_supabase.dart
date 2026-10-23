import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/datos/errores.dart';
import '../../../core/datos/puertos/repositorio_entrenamiento.dart';
import '../../../core/modelos/rutina.dart';
import '../../../core/supabase/supabase_config.dart';
import '../../../core/supabase/traductor_errores.dart';
import 'respuestas_de_rutinas.dart';

/// Adaptador del puerto de entrenamiento contra Supabase (RF11).
///
/// Las rutinas se leen directo de las tablas (las políticas de fila dejan
/// ver solo las propias). Crear y eliminar pasan por las funciones
/// crear_rutina() y eliminar_rutina() de la base: desde la app no se
/// puede escribir en esas tablas (supabase/schema.sql).
class RepositorioEntrenamientoSupabase implements RepositorioEntrenamiento {
  const RepositorioEntrenamientoSupabase();

  SupabaseClient get _bd => SupabaseConfig.cliente;

  @override
  Future<List<Rutina>> misRutinas() async {
    try {
      final User? usuario = _bd.auth.currentUser;
      if (usuario == null) {
        throw const ErrorDeDatos(
          TipoDeError.credencialesInvalidas,
          'Inicia sesión para ver tus rutinas.',
        );
      }

      final List<Map<String, dynamic>> filas = await _bd
          .from('rutinas')
          .select(columnasDeRutina)
          .eq('perfil_id', usuario.id)
          // De la más antigua a la más nueva: así no cambian de puesto.
          .order('creada_en', ascending: true)
          .order('id', ascending: true);

      return filas.map(rutinaDesdeFila).toList();
    } catch (e) {
      throw traducirError(e, 'No se pudieron cargar tus rutinas');
    }
  }

  @override
  Future<RespuestaCrearRutina> crearRutina({
    required String nombre,
    required List<LineaNuevaRutina> ejercicios,
    required String solicitudId,
  }) async {
    try {
      final Object? datos = await _bd.rpc(
        'crear_rutina',
        params: <String, dynamic>{
          'p_nombre': nombre,
          'p_ejercicios': <Map<String, dynamic>>[
            for (final LineaNuevaRutina l in ejercicios) l.aJson(),
          ],
          'p_solicitud': solicitudId,
        },
      );
      return respuestaCrearDesde(datos);
    } catch (e) {
      // Los datos inválidos llegan como excepción con el mensaje listo
      // para mostrar. Reintentar con la misma solicitud es seguro.
      throw traducirError(e, 'No se pudo guardar la rutina');
    }
  }

  @override
  Future<ResultadoEliminarRutina> eliminarRutina(int rutinaId) async {
    try {
      final Object? datos = await _bd.rpc(
        'eliminar_rutina',
        params: <String, dynamic>{'p_rutina_id': rutinaId},
      );
      return resultadoEliminarDesde(datos);
    } catch (e) {
      throw traducirError(e, 'No se pudo eliminar la rutina');
    }
  }
}
