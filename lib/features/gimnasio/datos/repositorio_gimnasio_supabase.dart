import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/datos/puertos/repositorio_gimnasio.dart';
import '../../../core/modelos/ejercicio.dart';
import '../../../core/modelos/maquina.dart';
import '../../../core/modelos/zona.dart';
import '../../../core/supabase/supabase_config.dart';
import '../../../core/supabase/traductor_errores.dart';

/// Adaptador del puerto de gimnasio contra Supabase.
///
/// Es el único archivo del módulo que sabe que existe Supabase. Traduce
/// las filas que devuelve la API a los modelos del proyecto y los
/// errores de red a ErrorDeDatos.
class RepositorioGimnasioSupabase implements RepositorioGimnasio {
  const RepositorioGimnasioSupabase();

  SupabaseClient get _bd => SupabaseConfig.cliente;

  @override
  Future<List<Zona>> zonas() async {
    try {
      final List<Map<String, dynamic>> filas = await _bd
          .from('zonas')
          .select('id, nombre, descripcion, activa')
          .order('id');

      return filas
          .map((Map<String, dynamic> f) => Zona(
                id: f['id'] as int,
                nombre: f['nombre'] as String,
                descripcion: f['descripcion'] as String?,
                activa: (f['activa'] as bool?) ?? true,
              ))
          .toList();
    } catch (e) {
      throw traducirError(e, 'No se pudieron cargar las zonas del gimnasio');
    }
  }

  @override
  Future<List<Maquina>> maquinas({int? zonaId}) async {
    try {
      // "ejercicios(...)" le pide a Supabase que traiga, en la misma
      // consulta, los ejercicios de cada máquina. La base sabe llegar a
      // ellos a través de la tabla intermedia ejercicio_maquina, así que
      // no hace falta una consulta por máquina.
      final consulta = _bd.from('maquinas').select(
          'id, zona_id, nombre, descripcion, cantidad, estado, imagen_url, '
          'ejercicios(id, nombre, grupo_muscular, descripcion, instrucciones)');

      final List<Map<String, dynamic>> filas = zonaId == null
          ? await consulta.order('nombre')
          : await consulta.eq('zona_id', zonaId).order('nombre');

      return filas.map(_maquinaDesdeFila).toList();
    } catch (e) {
      throw traducirError(e, 'No se pudo cargar el catálogo de máquinas');
    }
  }

  Maquina _maquinaDesdeFila(Map<String, dynamic> f) {
    final List<dynamic> filasEjercicios =
        (f['ejercicios'] as List<dynamic>?) ?? const <dynamic>[];

    final List<Ejercicio> ejercicios = filasEjercicios
        .cast<Map<String, dynamic>>()
        .map((Map<String, dynamic> e) => Ejercicio(
              id: e['id'] as int,
              nombre: e['nombre'] as String,
              grupoMuscular: e['grupo_muscular'] as String,
              descripcion: e['descripcion'] as String?,
              instrucciones: e['instrucciones'] as String?,
            ))
        .toList()
      ..sort((Ejercicio a, Ejercicio b) => a.nombre.compareTo(b.nombre));

    return Maquina(
      id: f['id'] as int,
      zonaId: f['zona_id'] as int,
      nombre: f['nombre'] as String,
      descripcion: f['descripcion'] as String?,
      cantidad: (f['cantidad'] as int?) ?? 1,
      estado: estadoMaquinaDesdeTexto(f['estado'] as String?),
      imagenUrl: f['imagen_url'] as String?,
      ejercicios: ejercicios,
    );
  }

  @override
  Future<String?> normativaVigente() async {
    try {
      final Map<String, dynamic>? fila = await _bd
          .from('normativa')
          .select('contenido')
          .eq('vigente', true)
          .maybeSingle();

      return fila?['contenido'] as String?;
    } catch (e) {
      throw traducirError(e, 'No se pudo cargar la normativa del gimnasio');
    }
  }
}
