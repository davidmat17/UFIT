/// Traduce lo que entrega Supabase sobre rutinas a los modelos del
/// proyecto.
///
/// Vive aparte del adaptador para poder probarse sin red: las pruebas le
/// pasan el JSON tal como lo devuelve la base.
library;

import '../../../core/modelos/rutina.dart';

/// Las columnas que pide la consulta de rutinas. Los ejercicios y las
/// máquinas vienen en la misma consulta.
const String columnasDeRutina = 'id, nombre, creada_en, '
    'rutina_ejercicios(ejercicio_id, maquina_id, dias, series, repeticiones, '
    'minutos, orden, ejercicios(nombre, grupo_muscular), maquinas(nombre))';

/// Una fila de la tabla rutinas, con sus ejercicios embebidos.
Rutina rutinaDesdeFila(Map<String, dynamic> fila) {
  final Object? lineas = fila['rutina_ejercicios'];
  final List<Map<String, dynamic>> filas = <Map<String, dynamic>>[
    if (lineas is List)
      for (final Object? l in lineas)
        if (l is Map) Map<String, dynamic>.from(l),
  ]..sort((Map<String, dynamic> a, Map<String, dynamic> b) =>
      _entero(a['orden']).compareTo(_entero(b['orden'])));

  final Object? creada = fila['creada_en'];

  return Rutina(
    id: (fila['id'] as num).toInt(),
    nombre: fila['nombre'] as String,
    creadaEn: creada is String ? DateTime.tryParse(creada) : null,
    ejercicios: filas.map(_ejercicioDesdeFila).toList(),
  );
}

EjercicioDeRutina _ejercicioDesdeFila(Map<String, dynamic> f) {
  final Object? ejercicio = f['ejercicios'];
  final Object? maquina = f['maquinas'];
  final Object? dias = f['dias'];
  final Object? maquinaId = f['maquina_id'];

  return EjercicioDeRutina(
    ejercicioId: _entero(f['ejercicio_id']),
    nombreEjercicio: ejercicio is Map
        ? (ejercicio['nombre'] as String? ?? 'Ejercicio')
        : 'Ejercicio',
    grupoMuscular:
        ejercicio is Map ? ejercicio['grupo_muscular'] as String? : null,
    maquinaId: maquinaId is num ? maquinaId.toInt() : null,
    nombreMaquina: maquina is Map ? maquina['nombre'] as String? : null,
    dias: <int>[
      if (dias is List)
        for (final Object? d in dias)
          if (d is num) d.toInt(),
    ]..sort(),
    series: _enteroONulo(f['series']),
    repeticiones: _enteroONulo(f['repeticiones']),
    minutos: _enteroONulo(f['minutos']),
  );
}

int _entero(Object? valor) => valor is num ? valor.toInt() : 0;

int? _enteroONulo(Object? valor) => valor is num ? valor.toInt() : null;

/// La respuesta de crear_rutina(): una fila con resultado y rutina_id.
/// Lo que no se entienda es un fallo, nunca un éxito.
RespuestaCrearRutina respuestaCrearDesde(Object? datos) {
  final Object? fila = datos is List && datos.isNotEmpty ? datos.first : datos;
  if (fila is! Map) {
    return const RespuestaCrearRutina(
      resultado: ResultadoCrearRutina.desconocido,
    );
  }

  final Object? resultado = fila['resultado'];
  final Object? id = fila['rutina_id'];
  return RespuestaCrearRutina(
    resultado:
        resultadoCrearRutinaDesdeTexto(resultado is String ? resultado : null),
    rutinaId: id is num ? id.toInt() : null,
  );
}

/// La respuesta de eliminar_rutina(): un texto suelto.
ResultadoEliminarRutina resultadoEliminarDesde(Object? datos) =>
    resultadoEliminarRutinaDesdeTexto(datos is String ? datos : null);
