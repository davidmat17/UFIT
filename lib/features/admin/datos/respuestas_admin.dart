/// Traduce lo que entrega Supabase en el módulo de administración a los
/// modelos del proyecto.
///
/// Vive aparte del adaptador para poder probarse sin red: las pruebas le
/// pasan el JSON tal como lo devuelve la base.
library;

import 'dart:convert';

import '../../../core/modelos/administracion.dart';
import '../../../core/modelos/estadisticas.dart';
import '../../../core/modelos/maquina.dart';
import '../../../core/modelos/perfil.dart';

const List<String> _dias = <String>[
  'Lunes', 'Martes', 'Miércoles', 'Jueves', 'Viernes', 'Sábado', 'Domingo',
];

int _entero(Object? v) => v is num ? v.toInt() : int.tryParse('$v') ?? 0;

double? _decimal(Object? v) =>
    v is num ? v.toDouble() : (v is String ? double.tryParse(v) : null);

String? _texto(Object? v) => v is String ? v : null;

/// "2026-11-09T14:05:00+00:00" → hora del reloj en Colombia (UTC-5).
DateTime? horaDeColombia(Object? instante) {
  if (instante is! String) return null;
  final DateTime? leido = DateTime.tryParse(instante);
  if (leido == null) return null;
  final DateTime c = leido.toUtc().subtract(const Duration(hours: 5));
  return DateTime(c.year, c.month, c.day, c.hour, c.minute, c.second);
}

List<Map<dynamic, dynamic>> _filas(Object? v) => v is List
    ? v.whereType<Map<dynamic, dynamic>>().toList()
    : const <Map<dynamic, dynamic>>[];

/// La respuesta de estadisticas_uso(). Devuelve null si la base dijo que
/// quien pregunta no es administrador (permitido = false).
EstadisticasDeUso? estadisticasDesdeRespuesta(
  Object? datos, {
  required DateTime desde,
  required DateTime hasta,
}) {
  Object? json = datos;
  if (json is String) json = jsonDecode(json);
  if (json is! Map || json['permitido'] != true) return null;

  final Object? r = json['resumen'];
  final Map<dynamic, dynamic> res = r is Map ? r : const <String, dynamic>{};

  return EstadisticasDeUso(
    desde: desde,
    hasta: hasta,
    resumen: ResumenDeUso(
      franjas: _entero(res['franjas']),
      reservas: _entero(res['reservas']),
      asistidas: _entero(res['asistidas']),
      noAsistidas: _entero(res['no_asistidas']),
      pendientes: _entero(res['pendientes']),
      canceladas: _entero(res['canceladas']),
      ocupacionPromedio: _decimal(res['ocupacion_promedio']),
    ),
    porHora: <UsoPorGrupo>[
      for (final Map<dynamic, dynamic> f in _filas(json['por_hora']))
        UsoPorGrupo(
          etiqueta: _texto(f['hora']) ?? '',
          franjas: _entero(f['franjas']),
          reservas: _entero(f['reservas']),
          asistidas: _entero(f['asistidas']),
          ocupacion: _decimal(f['ocupacion']),
        ),
    ],
    porDia: <UsoPorGrupo>[
      for (final Map<dynamic, dynamic> f in _filas(json['por_dia']))
        UsoPorGrupo(
          etiqueta: _entero(f['dia']) >= 1 && _entero(f['dia']) <= 7
              ? _dias[_entero(f['dia']) - 1]
              : '${f['dia']}',
          franjas: _entero(f['franjas']),
          reservas: _entero(f['reservas']),
          asistidas: _entero(f['asistidas']),
          ocupacion: _decimal(f['ocupacion']),
        ),
    ],
    porZona: <UsoPorGrupo>[
      for (final Map<dynamic, dynamic> f in _filas(json['por_zona']))
        UsoPorGrupo(
          etiqueta: _texto(f['zona']) ?? '',
          reservas: _entero(f['reservas']),
          asistidas: _entero(f['asistidas']),
          noAsistidas: _entero(f['no_asistidas']),
          canceladas: _entero(f['canceladas']),
        ),
    ],
    inventario: <InventarioDeZona>[
      for (final Map<dynamic, dynamic> f in _filas(json['maquinas']))
        InventarioDeZona(
          zona: _texto(f['zona']) ?? '',
          disponibles: _entero(f['disponibles']),
          fueraDeServicio: _entero(f['fuera_de_servicio']),
        ),
    ],
  );
}

/// La respuesta de eliminar_maquina() o eliminar_ejercicio().
RespuestaEliminacion eliminacionDesdeRespuesta(Object? datos) {
  final Object? fila = datos is List && datos.isNotEmpty ? datos.first : datos;
  if (fila is! Map) {
    return const RespuestaEliminacion(
      resultado: ResultadoEliminacion.desconocido,
    );
  }
  return RespuestaEliminacion(
    resultado: resultadoEliminacionDesdeTexto(_texto(fila['resultado'])),
    rutinas: _entero(fila['rutinas']),
  );
}

/// La respuesta de publicar_normativa().
RespuestaPublicacion publicacionDesdeRespuesta(Object? datos) {
  final Object? fila = datos is List && datos.isNotEmpty ? datos.first : datos;
  if (fila is! Map) {
    return const RespuestaPublicacion(
      resultado: ResultadoPublicacion.desconocido,
    );
  }
  final ResultadoPublicacion resultado = switch (_texto(fila['resultado'])) {
    'publicada' => ResultadoPublicacion.publicada,
    'version_cambio' => ResultadoPublicacion.versionCambio,
    _ => ResultadoPublicacion.desconocido,
  };
  final Object? version = fila['version'];
  return RespuestaPublicacion(
    resultado: resultado,
    version: version is num ? version.toInt() : null,
    publicadaEn: horaDeColombia(fila['publicada_en']),
  );
}

/// Una fila de maquinas, sin ejercicios.
Maquina maquinaDesdeFila(Map<dynamic, dynamic> f) => Maquina(
      id: _entero(f['id']),
      zonaId: _entero(f['zona_id']),
      nombre: _texto(f['nombre']) ?? '',
      descripcion: _texto(f['descripcion']),
      cantidad: f['cantidad'] == null ? 1 : _entero(f['cantidad']),
      estado: estadoMaquinaDesdeTexto(_texto(f['estado'])),
      imagenUrl: _texto(f['imagen_url']),
    );

/// Una fila de ejercicios con `ejercicio_maquina(maquina_id)` embebido.
EjercicioAdmin ejercicioDesdeFila(Map<dynamic, dynamic> f) => EjercicioAdmin(
      id: _entero(f['id']),
      nombre: _texto(f['nombre']) ?? '',
      grupoMuscular: _texto(f['grupo_muscular']) ?? '',
      descripcion: _texto(f['descripcion']),
      instrucciones: _texto(f['instrucciones']),
      activo: f['activo'] != false,
      maquinaIds: <int>[
        for (final Map<dynamic, dynamic> m in _filas(f['ejercicio_maquina']))
          _entero(m['maquina_id']),
      ]..sort(),
      actualizadoEn: horaDeColombia(f['actualizado_en']),
    );

/// Una fila de perfiles.
Perfil perfilDesdeFila(Map<dynamic, dynamic> f) => Perfil(
      id: _texto(f['id']) ?? '',
      nombre: _texto(f['nombre']) ?? '',
      apellido: _texto(f['apellido']) ?? '',
      documento: _texto(f['documento']) ?? '',
      correo: _texto(f['correo']) ?? '',
      telefono: _texto(f['telefono']),
      rol: rolDesdeTexto(_texto(f['rol'])),
      activo: f['activo'] != false,
      especialidad: _texto(f['especialidad']),
    );

/// Una fila de bitacora con `perfiles(nombre, apellido)` embebido.
EntradaBitacora entradaDesdeFila(Map<dynamic, dynamic> f) {
  final Object? p = f['perfiles'];
  final String? persona = p is Map
      ? '${_texto(p['nombre']) ?? ''} ${_texto(p['apellido']) ?? ''}'.trim()
      : null;
  final Object? detalle = f['detalle'];
  return EntradaBitacora(
    fecha: horaDeColombia(f['creada_en']) ?? DateTime(2000),
    accion: _texto(f['accion']) ?? '',
    entidad: _texto(f['entidad']) ?? '',
    entidadId: _texto(f['entidad_id']),
    persona: persona == null || persona.isEmpty ? null : persona,
    detalle: detalle == null ? null : jsonEncode(detalle),
  );
}

/// "06:00" para el parámetro de hora de las funciones.
String horaParaBase(int hora) => '${hora.toString().padLeft(2, '0')}:00';

/// "2026-11-09" para los parámetros de fecha.
String fechaParaBase(DateTime d) => '${d.year.toString().padLeft(4, '0')}-'
    '${d.month.toString().padLeft(2, '0')}-'
    '${d.day.toString().padLeft(2, '0')}';
