import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/datos/errores.dart';
import '../../../core/datos/puertos/repositorio_admin.dart';
import '../../../core/modelos/administracion.dart';
import '../../../core/modelos/maquina.dart';
import '../../../core/modelos/perfil.dart';
import '../../../core/supabase/supabase_config.dart';
import '../../../core/supabase/traductor_errores.dart';
import 'respuestas_admin.dart';

/// Adaptador del puerto de administración contra Supabase (RF12, RF13).
///
/// Crear y editar máquinas y ejercicios va directo a las tablas (las
/// políticas *_admin solo se lo permiten al administrador). Borrar,
/// publicar la normativa, asignar turnos y cambiar roles pasan por
/// funciones de la base, que revisan el rol y dejan la bitácora
/// (migración 016).
class RepositorioAdminSupabase implements RepositorioAdmin {
  const RepositorioAdminSupabase();

  SupabaseClient get _bd => SupabaseConfig.cliente;

  static const ErrorDeDatos _sinPermiso = ErrorDeDatos(
    TipoDeError.sinPermiso,
    'Esta sección es solo para el administrador del gimnasio.',
  );

  // -------------------------------------------------------------------
  // RF13: catálogo
  // -------------------------------------------------------------------

  @override
  Future<List<Maquina>> maquinas() async {
    try {
      final List<Map<String, dynamic>> filas = await _bd
          .from('maquinas')
          .select('id, zona_id, nombre, descripcion, cantidad, estado, imagen_url')
          .order('zona_id')
          .order('nombre');
      return filas.map(maquinaDesdeFila).toList();
    } catch (e) {
      throw traducirError(e, 'No se pudieron cargar las máquinas');
    }
  }

  @override
  Future<void> guardarMaquina(DatosMaquina datos) async {
    final Map<String, dynamic> fila = <String, dynamic>{
      'zona_id': datos.zonaId,
      'nombre': datos.nombre.trim(),
      'descripcion': _nuloSiVacio(datos.descripcion),
      'cantidad': datos.cantidad,
      'estado': datos.estado,
      'imagen_url': _nuloSiVacio(datos.imagenUrl),
    };
    try {
      final int? id = datos.id;
      if (id == null) {
        await _bd.from('maquinas').insert(fila);
      } else {
        await _bd.from('maquinas').update(fila).eq('id', id);
      }
    } catch (e) {
      throw traducirError(e, 'No se pudo guardar la máquina');
    }
  }

  @override
  Future<RespuestaEliminacion> eliminarMaquina(int id) async {
    try {
      final Object? datos = await _bd
          .rpc('eliminar_maquina', params: <String, dynamic>{'p_maquina_id': id});
      return eliminacionDesdeRespuesta(datos);
    } catch (e) {
      throw traducirError(e, 'No se pudo eliminar la máquina');
    }
  }

  @override
  Future<void> cambiarEstadoMaquina(int id, EstadoMaquina estado) async {
    try {
      await _bd
          .from('maquinas')
          .update(<String, dynamic>{'estado': estadoMaquinaATexto(estado)})
          .eq('id', id);
    } catch (e) {
      throw traducirError(e, 'No se pudo cambiar el estado de la máquina');
    }
  }

  @override
  Future<List<EjercicioAdmin>> ejercicios() async {
    try {
      final List<Map<String, dynamic>> filas = await _bd
          .from('ejercicios')
          .select('id, nombre, grupo_muscular, descripcion, instrucciones, '
              'activo, actualizado_en, ejercicio_maquina(maquina_id)')
          .order('grupo_muscular')
          .order('nombre');
      return filas.map(ejercicioDesdeFila).toList();
    } catch (e) {
      throw traducirError(e, 'No se pudieron cargar los ejercicios');
    }
  }

  @override
  Future<void> guardarEjercicio(DatosEjercicio datos) async {
    final Map<String, dynamic> fila = <String, dynamic>{
      'nombre': datos.nombre.trim(),
      'grupo_muscular': datos.grupoMuscular.trim(),
      'descripcion': _nuloSiVacio(datos.descripcion),
      'instrucciones': _nuloSiVacio(datos.instrucciones),
      'activo': datos.activo,
    };
    try {
      int id;
      final int? existente = datos.id;
      if (existente == null) {
        final Map<String, dynamic> creada =
            await _bd.from('ejercicios').insert(fila).select('id').single();
        id = (creada['id'] as num).toInt();
      } else {
        id = existente;
        await _bd.from('ejercicios').update(fila).eq('id', id);
      }

      // Las máquinas: se quitan las que sobran y se agregan las nuevas,
      // para que la bitácora muestre solo lo que cambió.
      final List<Map<String, dynamic>> actuales = await _bd
          .from('ejercicio_maquina')
          .select('maquina_id')
          .eq('ejercicio_id', id);
      final Set<int> antes = <int>{
        for (final Map<String, dynamic> m in actuales)
          (m['maquina_id'] as num).toInt(),
      };
      final Set<int> despues = datos.maquinaIds.toSet();

      final List<int> quitar = antes.difference(despues).toList();
      final List<int> agregar = despues.difference(antes).toList();

      if (quitar.isNotEmpty) {
        await _bd
            .from('ejercicio_maquina')
            .delete()
            .eq('ejercicio_id', id)
            .inFilter('maquina_id', quitar);
      }
      if (agregar.isNotEmpty) {
        await _bd.from('ejercicio_maquina').insert(<Map<String, dynamic>>[
          for (final int m in agregar)
            <String, dynamic>{'ejercicio_id': id, 'maquina_id': m},
        ]);
      }
    } catch (e) {
      throw traducirError(e, 'No se pudo guardar el ejercicio');
    }
  }

  @override
  Future<RespuestaEliminacion> eliminarEjercicio(int id) async {
    try {
      final Object? datos = await _bd.rpc('eliminar_ejercicio',
          params: <String, dynamic>{'p_ejercicio_id': id});
      return eliminacionDesdeRespuesta(datos);
    } catch (e) {
      throw traducirError(e, 'No se pudo eliminar el ejercicio');
    }
  }

  // -------------------------------------------------------------------
  // RF13: normativa y configuración
  // -------------------------------------------------------------------

  @override
  Future<NormativaAdmin?> normativaActual() async {
    try {
      final Map<String, dynamic>? fila = await _bd
          .from('normativa')
          .select('titulo, contenido, version, publicada_en')
          .order('version', ascending: false)
          .limit(1)
          .maybeSingle();
      if (fila == null) return null;
      return NormativaAdmin(
        titulo: fila['titulo'] as String,
        contenido: fila['contenido'] as String,
        version: (fila['version'] as num).toInt(),
        publicadaEn: horaDeColombia(fila['publicada_en']) ?? DateTime(2000),
      );
    } catch (e) {
      throw traducirError(e, 'No se pudo cargar la normativa');
    }
  }

  @override
  Future<RespuestaPublicacion> publicarNormativa({
    required String titulo,
    required String contenido,
    required int versionBase,
  }) async {
    try {
      final Object? datos = await _bd.rpc(
        'publicar_normativa',
        params: <String, dynamic>{
          'p_titulo': titulo,
          'p_contenido': contenido,
          'p_version_base': versionBase,
        },
      );
      return publicacionDesdeRespuesta(datos);
    } catch (e) {
      throw traducirError(e, 'No se pudo publicar la normativa');
    }
  }

  @override
  Future<int> horasAntelacionCancelar() async {
    try {
      final Map<String, dynamic>? fila = await _bd
          .from('configuracion')
          .select('horas_antelacion_cancelar')
          .maybeSingle();
      final Object? horas = fila?['horas_antelacion_cancelar'];
      return horas is num ? horas.toInt() : 3;
    } catch (e) {
      throw traducirError(e, 'No se pudo consultar el plazo para cancelar');
    }
  }

  @override
  Future<void> guardarHorasAntelacionCancelar(int horas) async {
    try {
      // Si la política de fila no deja actualizar, PostgREST no falla:
      // responde sin filas. Por eso se pide la fila de vuelta.
      final List<Map<String, dynamic>> filas = await _bd
          .from('configuracion')
          .update(<String, dynamic>{'horas_antelacion_cancelar': horas})
          .eq('id', true)
          .select('horas_antelacion_cancelar');
      if (filas.isEmpty) throw _sinPermiso;
    } catch (e) {
      throw traducirError(e, 'No se pudo guardar el plazo para cancelar');
    }
  }

  // -------------------------------------------------------------------
  // RF13: personas e instructores
  // -------------------------------------------------------------------

  @override
  Future<List<Perfil>> personas() async {
    try {
      final List<Map<String, dynamic>> filas = await _bd
          .from('perfiles')
          .select('id, nombre, apellido, documento, correo, telefono, rol, '
              'activo, especialidad')
          .order('apellido')
          .order('nombre');
      return filas.map(perfilDesdeFila).toList();
    } catch (e) {
      throw traducirError(e, 'No se pudieron cargar las personas');
    }
  }

  @override
  Future<ResultadoPersona> actualizarPersona({
    required String perfilId,
    required RolUsuario rol,
    required bool activo,
    String? especialidad,
  }) async {
    try {
      final Object? datos = await _bd.rpc(
        'actualizar_persona',
        params: <String, dynamic>{
          'p_perfil': perfilId,
          'p_rol': rolATexto(rol),
          'p_activo': activo,
          'p_especialidad': especialidad,
        },
      );
      return resultadoPersonaDesdeTexto(datos is String ? datos : null);
    } catch (e) {
      throw traducirError(e, 'No se pudo actualizar la persona');
    }
  }

  @override
  Future<int> asignarTurno({
    String? instructorId,
    required List<int> dias,
    required int horaDesde,
    required int horaHasta,
    required DateTime desde,
    required DateTime hasta,
  }) async {
    try {
      final Object? datos = await _bd.rpc(
        'asignar_turno',
        params: <String, dynamic>{
          'p_instructor': instructorId,
          'p_dias': dias,
          'p_hora_desde': horaParaBase(horaDesde),
          'p_hora_hasta': horaParaBase(horaHasta),
          'p_desde': fechaParaBase(desde),
          'p_hasta': fechaParaBase(hasta),
        },
      );
      return datos is num ? datos.toInt() : 0;
    } catch (e) {
      throw traducirError(e, 'No se pudo guardar la asignación');
    }
  }

  // -------------------------------------------------------------------
  // RF13: bitácora
  // -------------------------------------------------------------------

  @override
  Future<List<EntradaBitacora>> bitacora({int limite = 100}) async {
    try {
      final List<Map<String, dynamic>> filas = await _bd
          .from('bitacora')
          .select('creada_en, accion, entidad, entidad_id, detalle, '
              'perfiles(nombre, apellido)')
          .order('creada_en', ascending: false)
          .limit(limite);
      return filas.map(entradaDesdeFila).toList();
    } catch (e) {
      throw traducirError(e, 'No se pudo cargar la bitácora');
    }
  }

  static String? _nuloSiVacio(String? v) {
    final String t = (v ?? '').trim();
    return t.isEmpty ? null : t;
  }
}
