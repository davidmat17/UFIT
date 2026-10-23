/// Reglas del RF11 (rutinas de ejercicio) que no dependen de pantallas ni
/// de la base de datos. Por eso se pueden probar solas.
///
/// La base hace cumplir las mismas (crear_rutina() en supabase/schema.sql);
/// aquí sirven para mostrar el mensaje en el campo antes de enviar
/// (CU11, 7a y 7b).
library;

import 'dart:math';

import '../../core/modelos/ejercicio.dart';
import '../../core/modelos/maquina.dart';

// ---------------------------------------------------------------------
// Límites (acordados el 23 de octubre de 2026)
// ---------------------------------------------------------------------

/// Máximo de rutinas activas por persona (RF11).
const int maximoRutinas = 3;

const int maximoEjerciciosPorRutina = 20;
const int largoMaximoDelNombre = 60;

// Series, repeticiones y minutos son opcionales, pero cada ejercicio
// lleva repeticiones, minutos o ambos (decisión del 23 oct 2026).
const int minimoSeries = 1;
const int maximoSeries = 10;

const int minimoRepeticiones = 1;
const int maximoRepeticiones = 50;

const int minimoMinutos = 1;
const int maximoMinutos = 60;

/// Lunes (1) a viernes (5): el gimnasio no abre el fin de semana.
const List<int> diasPermitidos = <int>[1, 2, 3, 4, 5];

// ---------------------------------------------------------------------
// Validaciones (null = válido)
// ---------------------------------------------------------------------

String? validarNombre(String? valor) {
  final String nombre = (valor ?? '').trim();
  if (nombre.isEmpty) return 'Escribe un nombre para la rutina.';
  if (nombre.length > largoMaximoDelNombre) {
    return 'Máximo $largoMaximoDelNombre caracteres.';
  }
  return null;
}

/// Vacío es válido (el campo es opcional). Si tiene algo, solo enteros
/// en el rango: "12.5" o "doce" no sirven.
String? _validarEnteroOpcional(
  String? valor,
  int minimo,
  int maximo,
  String que,
) {
  final String texto = (valor ?? '').trim();
  if (texto.isEmpty) return null;
  final int? n = int.tryParse(texto);
  if (n == null || n < minimo || n > maximo) {
    return '$que deben ser un número entero de $minimo a $maximo.';
  }
  return null;
}

String? validarSeries(String? valor) =>
    _validarEnteroOpcional(valor, minimoSeries, maximoSeries, 'Las series');

String? validarRepeticiones(String? valor) => _validarEnteroOpcional(
    valor, minimoRepeticiones, maximoRepeticiones, 'Las repeticiones');

String? validarMinutos(String? valor) =>
    _validarEnteroOpcional(valor, minimoMinutos, maximoMinutos, 'Los minutos');

/// Cada ejercicio necesita repeticiones, minutos o ambos.
String? validarRepeticionesOMinutos(String? repeticiones, String? minutos) =>
    (repeticiones ?? '').trim().isEmpty && (minutos ?? '').trim().isEmpty
        ? 'Escribe las repeticiones, los minutos o ambos.'
        : null;

/// El número de un campo opcional ya validado; null si está vacío.
int? numeroOpcional(String texto) =>
    texto.trim().isEmpty ? null : int.parse(texto.trim());

String? validarDias(Iterable<int> dias) =>
    dias.isEmpty ? 'Elige al menos un día.' : null;

// ---------------------------------------------------------------------
// Textos
// ---------------------------------------------------------------------

const List<String> _diasCortos = <String>['lun', 'mar', 'mié', 'jue', 'vie'];

/// "lun" para 1 … "vie" para 5.
String nombreCortoDelDia(int dia) => _diasCortos[dia - 1];

/// "lun, mié, vie", o "lunes a viernes" si son los cinco.
String textoDeDias(List<int> dias) {
  final List<int> ordenados = dias.toSet().toList()..sort();
  if (ordenados.length == diasPermitidos.length) return 'lunes a viernes';
  return ordenados.map(nombreCortoDelDia).join(', ');
}

/// "2 de 3 rutinas".
String textoDelContador(int cantidad) =>
    '$cantidad de $maximoRutinas rutinas';

/// Lo que se hace en un ejercicio: "4 series × 12 repeticiones",
/// "12 repeticiones", "20 min" o "3 series × 10 repeticiones · 5 min",
/// con singular cuando toca.
String textoDeCarga({int? series, int? repeticiones, int? minutos}) {
  String plural(int n, String uno, String varios) =>
      '$n ${n == 1 ? uno : varios}';

  final List<String> partes = <String>[];
  if (repeticiones != null) {
    final String reps = plural(repeticiones, 'repetición', 'repeticiones');
    partes.add(series == null
        ? reps
        : '${plural(series, 'serie', 'series')} × $reps');
  } else if (series != null) {
    partes.add(plural(series, 'serie', 'series'));
  }
  if (minutos != null) partes.add('$minutos min');
  return partes.join(' · ');
}

/// "1 ejercicio", "3 ejercicios".
String textoDeEjercicios(int n) => n == 1 ? '1 ejercicio' : '$n ejercicios';

// ---------------------------------------------------------------------
// Catálogo para el formulario
// ---------------------------------------------------------------------

/// Un ejercicio que se puede agregar a una rutina, con las máquinas
/// disponibles en las que se hace.
class OpcionDeEjercicio {
  const OpcionDeEjercicio({required this.ejercicio, required this.maquinas});

  final Ejercicio ejercicio;
  final List<Maquina> maquinas;

  /// "Press de banca (Pecho)".
  String get etiqueta => '${ejercicio.nombre} (${ejercicio.grupoMuscular})';
}

/// Arma la lista de ejercicios a partir del catálogo de máquinas (RF5).
///
/// Solo cuentan las máquinas disponibles: una en mantenimiento o retirada
/// no sirve para planear. Un ejercicio sin ninguna máquina disponible no
/// se ofrece. Van ordenados por grupo muscular y luego por nombre.
List<OpcionDeEjercicio> opcionesDeEjercicio(List<Maquina> catalogo) {
  final Map<int, Ejercicio> ejercicios = <int, Ejercicio>{};
  final Map<int, List<Maquina>> maquinasPorEjercicio = <int, List<Maquina>>{};

  for (final Maquina m in catalogo) {
    if (!m.estaDisponible) continue;
    for (final Ejercicio e in m.ejercicios) {
      ejercicios[e.id] = e;
      (maquinasPorEjercicio[e.id] ??= <Maquina>[]).add(m);
    }
  }

  final List<OpcionDeEjercicio> opciones = <OpcionDeEjercicio>[
    for (final MapEntry<int, Ejercicio> e in ejercicios.entries)
      OpcionDeEjercicio(
        ejercicio: e.value,
        maquinas: maquinasPorEjercicio[e.key]!
          ..sort((Maquina a, Maquina b) => a.nombre.compareTo(b.nombre)),
      ),
  ];

  opciones.sort((OpcionDeEjercicio a, OpcionDeEjercicio b) {
    final int porGrupo =
        a.ejercicio.grupoMuscular.compareTo(b.ejercicio.grupoMuscular);
    if (porGrupo != 0) return porGrupo;
    return a.ejercicio.nombre.compareTo(b.ejercicio.nombre);
  });
  return opciones;
}

// ---------------------------------------------------------------------
// Identificador de la solicitud
// ---------------------------------------------------------------------

/// Un UUID versión 4 al azar, como "3f2b8c1e-…". La pantalla genera uno
/// por formulario; si la red falla y se reintenta, se envía el mismo y la
/// base no duplica la rutina (CU11, 7d).
String nuevoIdDeSolicitud([Random? azar]) {
  final Random r = azar ?? Random.secure();
  final List<int> b = List<int>.generate(16, (_) => r.nextInt(256));
  b[6] = (b[6] & 0x0f) | 0x40; // versión 4
  b[8] = (b[8] & 0x3f) | 0x80; // variante RFC 4122

  final String h =
      b.map((int x) => x.toRadixString(16).padLeft(2, '0')).join();
  return '${h.substring(0, 8)}-${h.substring(8, 12)}-${h.substring(12, 16)}-'
      '${h.substring(16, 20)}-${h.substring(20)}';
}
