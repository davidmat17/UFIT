import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ufit/core/datos/errores.dart';
import 'package:ufit/core/datos/puertos/repositorio_entrenamiento.dart';
import 'package:ufit/core/datos/puertos/repositorio_gimnasio.dart';
import 'package:ufit/core/datos/repositorios.dart';
import 'package:ufit/core/modelos/ejercicio.dart';
import 'package:ufit/core/modelos/franja_con_instructor.dart';
import 'package:ufit/core/modelos/maquina.dart';
import 'package:ufit/core/modelos/normativa.dart';
import 'package:ufit/core/modelos/rutina.dart';
import 'package:ufit/core/modelos/zona.dart';
import 'package:ufit/core/tema/app_theme.dart';
import 'package:ufit/features/entrenamiento/datos/respuestas_de_rutinas.dart';
import 'package:ufit/features/entrenamiento/pantallas/rf11_rutinas.dart';
import 'package:ufit/features/entrenamiento/reglas_rutinas.dart';

// ---------------------------------------------------------------------
// Catálogo de prueba (parecido al real)
// ---------------------------------------------------------------------

const Ejercicio _caminata = Ejercicio(
    id: 1, nombre: 'Caminata en pendiente', grupoMuscular: 'Cardiovascular');
const Ejercicio _trote =
    Ejercicio(id: 2, nombre: 'Trote continuo', grupoMuscular: 'Cardiovascular');
const Ejercicio _pressBanca =
    Ejercicio(id: 3, nombre: 'Press de banca', grupoMuscular: 'Pecho');
const Ejercicio _prensa =
    Ejercicio(id: 5, nombre: 'Prensa de piernas', grupoMuscular: 'Piernas');
const Ejercicio _curl =
    Ejercicio(id: 7, nombre: 'Curl de bíceps', grupoMuscular: 'Brazos');
const Ejercicio _intervalos = Ejercicio(
    id: 9, nombre: 'Pedaleo por intervalos', grupoMuscular: 'Cardiovascular');
const Ejercicio _reclinado = Ejercicio(
    id: 10,
    nombre: 'Pedaleo reclinado continuo',
    grupoMuscular: 'Cardiovascular');

const List<Maquina> _catalogo = <Maquina>[
  Maquina(
    id: 1,
    zonaId: 1,
    nombre: 'Trotadora',
    ejercicios: <Ejercicio>[_caminata, _trote],
  ),
  Maquina(
    id: 4,
    zonaId: 2,
    nombre: 'Banco plano',
    ejercicios: <Ejercicio>[_pressBanca],
  ),
  // En mantenimiento: no se ofrece para planear.
  Maquina(
    id: 7,
    zonaId: 3,
    nombre: 'Prensa de piernas',
    estado: EstadoMaquina.mantenimiento,
    ejercicios: <Ejercicio>[_prensa],
  ),
  Maquina(
    id: 8,
    zonaId: 2,
    nombre: 'Mancuernas',
    ejercicios: <Ejercicio>[_curl],
  ),
  Maquina(
    id: 11,
    zonaId: 1,
    nombre: 'Bicicleta reclinada',
    ejercicios: <Ejercicio>[_intervalos, _reclinado],
  ),
  Maquina(
    id: 10,
    zonaId: 1,
    nombre: 'Bicicleta estática',
    ejercicios: <Ejercicio>[_intervalos],
  ),
];

String _nombreDeEjercicio(int id) => <int, String>{
      for (final Maquina m in _catalogo)
        for (final Ejercicio e in m.ejercicios) e.id: e.nombre,
    }[id]!;

String _nombreDeMaquina(int id) =>
    _catalogo.firstWhere((Maquina m) => m.id == id).nombre;

Rutina _rutina(int id, String nombre, List<EjercicioDeRutina> ejercicios) =>
    Rutina(id: id, nombre: nombre, ejercicios: ejercicios);

/// "Fuerza A": press de banca en banco plano, lun-mié-vie, 4 × 12.
/// "Cardio": trote en trotadora, de lunes a viernes, 30 minutos.
List<Rutina> _dosRutinas() => <Rutina>[
      _rutina(1, 'Fuerza A', const <EjercicioDeRutina>[
        EjercicioDeRutina(
          ejercicioId: 3,
          nombreEjercicio: 'Press de banca',
          maquinaId: 4,
          nombreMaquina: 'Banco plano',
          dias: <int>[1, 3, 5],
          series: 4,
          repeticiones: 12,
        ),
      ]),
      _rutina(2, 'Cardio', const <EjercicioDeRutina>[
        EjercicioDeRutina(
          ejercicioId: 2,
          nombreEjercicio: 'Trote continuo',
          maquinaId: 1,
          nombreMaquina: 'Trotadora',
          dias: <int>[1, 2, 3, 4, 5],
          minutos: 30,
        ),
      ]),
    ];

// ---------------------------------------------------------------------
// Dobles de prueba
// ---------------------------------------------------------------------

/// Repositorio de entrenamiento falso. Aplica las mismas reglas que
/// crear_rutina() y eliminar_rutina() de la base (supabase/schema.sql), en
/// el mismo orden: solicitud repetida, máximo 3 y nombre repetido.
class _EntrenamientoFalso implements RepositorioEntrenamiento {
  _EntrenamientoFalso({List<Rutina>? rutinas})
      : rutinas = List<Rutina>.of(rutinas ?? <Rutina>[]);

  final List<Rutina> rutinas;

  /// Cuántas llamadas a crearRutina() fallan antes de funcionar.
  int fallosPorVenir = 0;

  /// En esos fallos, si la rutina alcanzó a quedar guardada: es lo que
  /// pasa cuando se corta la red justo antes de que llegue la respuesta.
  bool aplicarAntesDeFallar = false;

  /// Cada llamada a crearRutina(): nombre, ejercicios y solicitud.
  final List<(String, List<LineaNuevaRutina>, String)> pedidos =
      <(String, List<LineaNuevaRutina>, String)>[];

  final List<int> eliminaciones = <int>[];

  final Map<String, int> _solicitudes = <String, int>{};
  int _siguienteId = 100;

  /// Otra sesión (otro celular) elimina la rutina sin que esta pantalla se
  /// entere (CU11, 3c).
  void eliminarDesdeOtroDispositivo(int id) =>
      rutinas.removeWhere((Rutina r) => r.id == id);

  @override
  Future<List<Rutina>> misRutinas() async => List<Rutina>.of(rutinas);

  @override
  Future<RespuestaCrearRutina> crearRutina({
    required String nombre,
    required List<LineaNuevaRutina> ejercicios,
    required String solicitudId,
  }) async {
    pedidos.add((nombre, ejercicios, solicitudId));

    final bool fallar = fallosPorVenir > 0;
    if (fallar) fallosPorVenir--;
    if (fallar && !aplicarAntesDeFallar) throw _errorDeRed();

    final RespuestaCrearRutina r = _procesar(nombre, ejercicios, solicitudId);
    if (fallar) throw _errorDeRed();
    return r;
  }

  RespuestaCrearRutina _procesar(
    String nombre,
    List<LineaNuevaRutina> ejercicios,
    String solicitudId,
  ) {
    final int? previa = _solicitudes[solicitudId];
    if (previa != null) {
      return RespuestaCrearRutina(
        resultado: ResultadoCrearRutina.yaCreada,
        rutinaId: previa,
      );
    }
    if (rutinas.length >= maximoRutinas) {
      return const RespuestaCrearRutina(
        resultado: ResultadoCrearRutina.maximoRutinas,
      );
    }
    if (rutinas.any(
        (Rutina r) => r.nombre.toLowerCase() == nombre.toLowerCase())) {
      return const RespuestaCrearRutina(
        resultado: ResultadoCrearRutina.nombreRepetido,
      );
    }

    final int id = _siguienteId++;
    _solicitudes[solicitudId] = id;
    rutinas.add(_rutina(id, nombre, <EjercicioDeRutina>[
      for (final LineaNuevaRutina l in ejercicios)
        EjercicioDeRutina(
          ejercicioId: l.ejercicioId,
          nombreEjercicio: _nombreDeEjercicio(l.ejercicioId),
          maquinaId: l.maquinaId,
          nombreMaquina: _nombreDeMaquina(l.maquinaId),
          dias: l.dias,
          series: l.series,
          repeticiones: l.repeticiones,
          minutos: l.minutos,
        ),
    ]));
    return RespuestaCrearRutina(
      resultado: ResultadoCrearRutina.creada,
      rutinaId: id,
    );
  }

  ErrorDeDatos _errorDeRed() => const ErrorDeDatos(
        TipoDeError.sinConexion,
        'No se pudo guardar la rutina. '
        'Revisa tu conexión a internet e inténtalo de nuevo.',
      );

  @override
  Future<ResultadoEliminarRutina> eliminarRutina(int rutinaId) async {
    eliminaciones.add(rutinaId);
    final int antes = rutinas.length;
    rutinas.removeWhere((Rutina r) => r.id == rutinaId);
    return rutinas.length < antes
        ? ResultadoEliminarRutina.eliminada
        : ResultadoEliminarRutina.yaEliminada;
  }
}

class _GimnasioFalso implements RepositorioGimnasio {
  @override
  Future<List<Maquina>> maquinas({int? zonaId}) async => _catalogo;

  @override
  Future<List<Zona>> zonas() async => const <Zona>[];

  @override
  Future<Normativa?> normativaVigente() async => null;

  @override
  Future<List<FranjaConInstructor>> agendaInstructores({
    required DateTime desde,
    required DateTime hasta,
  }) async =>
      const <FranjaConInstructor>[];
}

// ---------------------------------------------------------------------
// Respuestas reales
//
// Salen de correr supabase/schema.sql y la migración 013 en un Postgres
// de verdad y pedirlas a través de PostgREST, como las pide la app.
// ---------------------------------------------------------------------

const String _consultaReal =
    '[{"id":12,"nombre":"C","creada_en":"2026-10-23T10:36:25.424987-05:00",'
    '"rutina_ejercicios":[{"id": 5, "dias": [1, 2, 3, 4, 5], "orden": 1, '
    '"series": 3, "maquinas": {"nombre": "Trotadora"}, "ejercicios": '
    '{"nombre": "Trote continuo", "grupo_muscular": "Cardiovascular"}, '
    '"maquina_id": 1, "ejercicio_id": 2, "repeticiones": 10}]}]';

/// Dos ejercicios que llegan en desorden y uno sin máquina (la retiraron).
const String _filaDesordenada =
    '{"id":7,"nombre":"Mixta","creada_en":"2026-10-23T10:00:00-05:00",'
    '"rutina_ejercicios":['
    '{"orden": 2, "dias": [5, 1], "series": 2, "repeticiones": 8, '
    '"maquina_id": null, "maquinas": null, "ejercicio_id": 3, '
    '"ejercicios": {"nombre": "Press de banca", "grupo_muscular": "Pecho"}},'
    '{"orden": 1, "dias": [2], "series": 3, "repeticiones": 15, '
    '"maquina_id": 1, "maquinas": {"nombre": "Trotadora"}, "ejercicio_id": 1, '
    '"ejercicios": {"nombre": "Caminata en pendiente", '
    '"grupo_muscular": "Cardiovascular"}}]}';

// ---------------------------------------------------------------------
// Ayudas para las pruebas de pantalla
// ---------------------------------------------------------------------

Future<void> _abrir(WidgetTester tester, _EntrenamientoFalso repo) async {
  await tester.binding.setSurfaceSize(const Size(800, 2000));
  addTearDown(() => tester.binding.setSurfaceSize(null));

  Repositorios.entrenamiento = repo;
  Repositorios.gimnasio = _GimnasioFalso();

  await tester.pumpWidget(
    MaterialApp(theme: AppTheme.claro, home: const PantallaRutinas()),
  );
  await tester.pumpAndSettle();
}

Future<void> _tocar(WidgetTester tester, Finder finder) async {
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

/// El botón (de cualquier tipo) que contiene ese texto. Se busca por la
/// clase base porque FilledButton.icon construye una subclase privada.
Finder _boton(String texto) => find.ancestor(
      of: find.text(texto),
      matching: find.byWidgetPredicate((Widget w) => w is ButtonStyleButton),
    );

bool _activo(WidgetTester tester, String texto) =>
    tester.widget<ButtonStyleButton>(_boton(texto)).enabled;

Finder _campo(String etiqueta) => find.widgetWithText(TextFormField, etiqueta);

/// Busca solo dentro de la hoja de agregar ejercicio.
Finder _enHoja(Finder buscado) =>
    find.descendant(of: find.byType(BottomSheet), matching: buscado);

/// Abre la hoja y agrega un ejercicio completo.
Future<void> _agregarEjercicio(
  WidgetTester tester, {
  required String etiqueta,
  String? maquina,
  List<String> dias = const <String>['lun'],
  String? series,
  String? repeticiones = '10',
  String? minutos,
}) async {
  await _tocar(tester, find.text('Agregar ejercicio'));
  await _tocar(tester, find.byType(DropdownButtonFormField<OpcionDeEjercicio>));
  await _tocar(tester, find.text(etiqueta).last);
  if (maquina != null) await _tocar(tester, _enHoja(find.text(maquina)));
  for (final String d in dias) {
    await _tocar(tester, _enHoja(find.text(d)));
  }
  if (series != null) await tester.enterText(_campo('Series'), series);
  if (repeticiones != null) {
    await tester.enterText(_campo('Repeticiones'), repeticiones);
  }
  if (minutos != null) await tester.enterText(_campo('Minutos'), minutos);
  await _tocar(tester, find.text('Agregar a la rutina'));
}

void main() {
  group('validaciones', () {
    test('el nombre no puede estar vacío ni pasar de 60 caracteres', () {
      expect(validarNombre(''), 'Escribe un nombre para la rutina.');
      expect(validarNombre('   '), 'Escribe un nombre para la rutina.');
      expect(validarNombre(null), 'Escribe un nombre para la rutina.');
      expect(validarNombre('a' * 61), 'Máximo 60 caracteres.');
      expect(validarNombre('  ${'a' * 60}  '), isNull);
      expect(validarNombre('Fuerza A'), isNull);
    });

    test('las repeticiones son un entero de 1 a 50', () {
      const String error =
          'Las repeticiones deben ser un número entero de 1 a 50.';
      for (final String malo in <String>['0', '51', '-3', '12.5', 'doce']) {
        expect(validarRepeticiones(malo), error, reason: malo);
      }
      // Vacío vale: el ejercicio puede medirse en minutos.
      expect(validarRepeticiones(''), isNull);
      expect(validarRepeticiones('1'), isNull);
      expect(validarRepeticiones(' 50 '), isNull);
    });

    test('las series son opcionales, de 1 a 10', () {
      expect(validarSeries('0'), isNotNull);
      expect(validarSeries('11'), isNotNull);
      expect(validarSeries(''), isNull);
      expect(validarSeries('3'), isNull);
      expect(validarSeries('10'), isNull);
    });

    test('los minutos son opcionales, de 1 a 60', () {
      const String error = 'Los minutos deben ser un número entero de 1 a 60.';
      for (final String malo in <String>['0', '61', '2.5', 'media hora']) {
        expect(validarMinutos(malo), error, reason: malo);
      }
      expect(validarMinutos(''), isNull);
      expect(validarMinutos('60'), isNull);
    });

    test('cada ejercicio necesita repeticiones, minutos o ambos', () {
      const String error = 'Escribe las repeticiones, los minutos o ambos.';
      expect(validarRepeticionesOMinutos('', ''), error);
      expect(validarRepeticionesOMinutos(' ', null), error);
      expect(validarRepeticionesOMinutos('12', ''), isNull);
      expect(validarRepeticionesOMinutos('', '20'), isNull);
      expect(validarRepeticionesOMinutos('10', '5'), isNull);
      expect(numeroOpcional(' 12 '), 12);
      expect(numeroOpcional(''), isNull);
    });

    test('hace falta al menos un día', () {
      expect(validarDias(<int>[]), 'Elige al menos un día.');
      expect(validarDias(<int>[2]), isNull);
    });
  });

  group('textos', () {
    test('días, contador, series, repeticiones y minutos', () {
      expect(textoDeDias(<int>[5, 1, 3]), 'lun, mié, vie');
      expect(textoDeDias(<int>[1, 2, 3, 4, 5]), 'lunes a viernes');
      expect(textoDelContador(2), '2 de 3 rutinas');
      expect(textoDeCarga(series: 4, repeticiones: 12),
          '4 series × 12 repeticiones');
      expect(textoDeCarga(series: 1, repeticiones: 1), '1 serie × 1 repetición');
      expect(textoDeCarga(repeticiones: 15), '15 repeticiones');
      expect(textoDeCarga(minutos: 20), '20 min');
      expect(textoDeCarga(series: 3, repeticiones: 10, minutos: 5),
          '3 series × 10 repeticiones · 5 min');
      expect(textoDeCarga(series: 2, minutos: 10), '2 series · 10 min');
      expect(textoDeEjercicios(1), '1 ejercicio');
      expect(textoDeEjercicios(3), '3 ejercicios');
    });
  });

  group('catálogo para el formulario', () {
    test('solo máquinas disponibles, por grupo muscular y nombre', () {
      final List<OpcionDeEjercicio> opciones = opcionesDeEjercicio(_catalogo);

      expect(
        opciones.map((OpcionDeEjercicio o) => o.ejercicio.nombre),
        <String>[
          'Curl de bíceps', // Brazos
          'Caminata en pendiente', // Cardiovascular
          'Pedaleo por intervalos',
          'Pedaleo reclinado continuo',
          'Trote continuo',
          'Press de banca', // Pecho
          // La prensa está en mantenimiento: no aparece.
        ],
      );

      final OpcionDeEjercicio intervalos = opciones
          .firstWhere((OpcionDeEjercicio o) => o.ejercicio.id == _intervalos.id);
      expect(
        intervalos.maquinas.map((Maquina m) => m.nombre),
        <String>['Bicicleta estática', 'Bicicleta reclinada'],
      );
      expect(intervalos.etiqueta, 'Pedaleo por intervalos (Cardiovascular)');
    });

    test('el identificador de la solicitud es un UUID v4 distinto cada vez', () {
      final RegExp v4 = RegExp(
          r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$');
      final String a = nuevoIdDeSolicitud();
      final String b = nuevoIdDeSolicitud();
      expect(a, matches(v4));
      expect(b, matches(v4));
      expect(a, isNot(b));
      // Con la misma semilla sale el mismo: no depende de nada más.
      expect(nuevoIdDeSolicitud(Random(7)), nuevoIdDeSolicitud(Random(7)));
    });
  });

  group('lo que responde la base', () {
    test('lee una rutina con sus ejercicios', () {
      final List<dynamic> filas = jsonDecode(_consultaReal) as List<dynamic>;
      final Rutina r = rutinaDesdeFila(filas.first as Map<String, dynamic>);

      expect(r.id, 12);
      expect(r.nombre, 'C');
      expect(r.creadaEn, isNotNull);
      expect(r.ejercicios, hasLength(1));
      final EjercicioDeRutina e = r.ejercicios.first;
      expect(e.nombreEjercicio, 'Trote continuo');
      expect(e.grupoMuscular, 'Cardiovascular');
      expect(e.nombreMaquina, 'Trotadora');
      expect(e.maquinaId, 1);
      expect(e.dias, <int>[1, 2, 3, 4, 5]);
      expect(e.series, 3);
      expect(e.repeticiones, 10);
      expect(e.minutos, isNull);
    });

    test('ordena los ejercicios y tolera una máquina retirada', () {
      final Rutina r = rutinaDesdeFila(
          jsonDecode(_filaDesordenada) as Map<String, dynamic>);

      expect(
        r.ejercicios.map((EjercicioDeRutina e) => e.nombreEjercicio),
        <String>['Caminata en pendiente', 'Press de banca'],
      );
      expect(r.ejercicios.last.maquinaId, isNull);
      expect(r.ejercicios.last.nombreMaquina, isNull);
      expect(r.ejercicios.last.dias, <int>[1, 5]);
    });

    test('lee lo que responde crear_rutina()', () {
      RespuestaCrearRutina leer(String json) =>
          respuestaCrearDesde(jsonDecode(json));

      final RespuestaCrearRutina creada =
          leer('[{"resultado":"creada","rutina_id":20}]');
      expect(creada.resultado, ResultadoCrearRutina.creada);
      expect(creada.rutinaId, 20);
      expect(creada.fueGuardada, isTrue);
      expect(creada.mensaje, 'Rutina creada correctamente');

      final RespuestaCrearRutina reintento =
          leer('[{"resultado":"ya_creada","rutina_id":20}]');
      expect(reintento.resultado, ResultadoCrearRutina.yaCreada);
      expect(reintento.fueGuardada, isTrue);

      final RespuestaCrearRutina tope =
          leer('[{"resultado":"maximo_rutinas","rutina_id":null}]');
      expect(tope.resultado, ResultadoCrearRutina.maximoRutinas);
      expect(tope.rutinaId, isNull);
      expect(tope.fueGuardada, isFalse);
    });

    test('lo que no se entiende es un fallo, nunca un éxito', () {
      for (final Object? datos in <Object?>[
        null,
        <Object?>[],
        'creada',
        <Object?>[
          <String, Object?>{'resultado': 'otra_cosa', 'rutina_id': 3},
        ],
      ]) {
        final RespuestaCrearRutina r = respuestaCrearDesde(datos);
        expect(r.resultado, ResultadoCrearRutina.desconocido);
        expect(r.fueGuardada, isFalse);
      }
    });

    test('lee lo que responde eliminar_rutina()', () {
      expect(resultadoEliminarDesde('eliminada'),
          ResultadoEliminarRutina.eliminada);
      expect(resultadoEliminarDesde('ya_eliminada'),
          ResultadoEliminarRutina.yaEliminada);
      expect(resultadoEliminarDesde(null), ResultadoEliminarRutina.desconocido);
      expect(ResultadoEliminarRutina.yaEliminada.mensaje,
          'Esta rutina ya fue eliminada.');
    });

    test('envía cada ejercicio como lo espera la base', () {
      const LineaNuevaRutina l = LineaNuevaRutina(
        ejercicioId: 9,
        maquinaId: 11,
        dias: <int>[1, 3],
        minutos: 20,
      );
      expect(l.aJson(), <String, dynamic>{
        'ejercicio_id': 9,
        'maquina_id': 11,
        'dias': <int>[1, 3],
        'series': null,
        'repeticiones': null,
        'minutos': 20,
      });
    });
  });

  group('pantalla del RF11', () {
    testWidgets('muestra las rutinas con el contador y el detalle',
        (WidgetTester tester) async {
      await _abrir(tester, _EntrenamientoFalso(rutinas: _dosRutinas()));

      expect(find.text('Mis rutinas'), findsOneWidget);
      expect(find.text('2 de 3 rutinas'), findsOneWidget);
      expect(_activo(tester, 'Nueva rutina'), isTrue);

      expect(find.text('Fuerza A'), findsOneWidget);
      expect(find.text('Press de banca'), findsOneWidget);
      expect(find.text('Banco plano · lun, mié, vie'), findsOneWidget);
      expect(find.text('4 series × 12 repeticiones'), findsOneWidget);

      expect(find.text('Cardio'), findsOneWidget);
      expect(find.text('Trotadora · lunes a viernes'), findsOneWidget);
      expect(find.text('30 min'), findsOneWidget);
    });

    testWidgets('sin rutinas lo dice y deja crear',
        (WidgetTester tester) async {
      await _abrir(tester, _EntrenamientoFalso());

      expect(find.text('0 de 3 rutinas'), findsOneWidget);
      expect(find.text('Todavía no tienes rutinas.'), findsOneWidget);
      expect(_activo(tester, 'Nueva rutina'), isTrue);
    });

    testWidgets('con 3 rutinas no deja crear y explica por qué (3a)',
        (WidgetTester tester) async {
      await _abrir(
        tester,
        _EntrenamientoFalso(rutinas: <Rutina>[
          ..._dosRutinas(),
          _rutina(3, 'Piernas', const <EjercicioDeRutina>[]),
        ]),
      );

      expect(find.text('3 de 3 rutinas'), findsOneWidget);
      expect(_activo(tester, 'Nueva rutina'), isFalse);
      expect(find.textContaining('Elimina una para poder crear otra'),
          findsOneWidget);
    });

    testWidgets('eliminar pide confirmación y libera el cupo (3b)',
        (WidgetTester tester) async {
      final _EntrenamientoFalso repo =
          _EntrenamientoFalso(rutinas: _dosRutinas());
      await _abrir(tester, repo);

      // Si no confirma, no pasa nada.
      await _tocar(tester, find.byTooltip('Eliminar rutina').first);
      expect(find.text('¿Eliminar esta rutina?'), findsOneWidget);
      expect(find.textContaining('«Fuerza A» y su ejercicio se borrarán.'),
          findsOneWidget);
      await _tocar(tester, find.text('Cancelar'));
      expect(repo.eliminaciones, isEmpty);
      expect(find.text('Fuerza A'), findsOneWidget);

      // Confirmando, se elimina y el contador baja.
      await _tocar(tester, find.byTooltip('Eliminar rutina').first);
      await _tocar(tester, find.text('Eliminar'));

      expect(repo.eliminaciones, <int>[1]);
      expect(
        find.text('Rutina eliminada. Ya tienes un cupo libre para crear otra.'),
        findsOneWidget,
      );
      expect(find.text('Fuerza A'), findsNothing);
      expect(find.text('1 de 3 rutinas'), findsOneWidget);
    });

    testWidgets('si ya se eliminó en otro dispositivo, lo dice (3c)',
        (WidgetTester tester) async {
      final _EntrenamientoFalso repo =
          _EntrenamientoFalso(rutinas: _dosRutinas());
      await _abrir(tester, repo);

      repo.eliminarDesdeOtroDispositivo(2);
      expect(find.text('Cardio'), findsOneWidget);

      await _tocar(tester, find.byTooltip('Eliminar rutina').last);
      await _tocar(tester, find.text('Eliminar'));

      expect(find.text('Esta rutina ya fue eliminada.'), findsOneWidget);
      expect(find.text('Cardio'), findsNothing);
      expect(find.text('1 de 3 rutinas'), findsOneWidget);
    });

    testWidgets('crea una rutina completa y actualiza el contador',
        (WidgetTester tester) async {
      final _EntrenamientoFalso repo =
          _EntrenamientoFalso(rutinas: _dosRutinas());
      await _abrir(tester, repo);

      await _tocar(tester, find.text('Nueva rutina'));
      expect(find.text('Ejercicios (0 de 20)'), findsOneWidget);

      // 7a: sin nombre y sin ejercicios no se guarda.
      await _tocar(tester, find.text('Guardar'));
      expect(find.text('Escribe un nombre para la rutina.'), findsOneWidget);
      expect(find.text('Agrega al menos un ejercicio.'), findsOneWidget);
      expect(repo.pedidos, isEmpty);

      await tester.enterText(_campo('Nombre de la rutina'), 'Pierna y cardio');

      // La hoja tampoco deja agregar un ejercicio a medias.
      await _tocar(tester, find.text('Agregar ejercicio'));
      await _tocar(tester, find.text('Agregar a la rutina'));
      expect(find.text('Elige un ejercicio.'), findsOneWidget);
      expect(find.text('Elige al menos un día.'), findsOneWidget);
      expect(find.text('Escribe las repeticiones, los minutos o ambos.'),
          findsOneWidget);

      // Un ejercicio con dos máquinas: hay que elegir una.
      await _tocar(
          tester, find.byType(DropdownButtonFormField<OpcionDeEjercicio>));
      await _tocar(
          tester, find.text('Pedaleo por intervalos (Cardiovascular)').last);
      await _tocar(tester, find.text('Agregar a la rutina'));
      expect(find.text('Elige una máquina.'), findsOneWidget);

      await _tocar(tester, _enHoja(find.text('Bicicleta reclinada')));
      await _tocar(tester, _enHoja(find.text('lun')));
      await _tocar(tester, _enHoja(find.text('mié')));
      // Se mide en tiempo: sin series ni repeticiones.
      await tester.enterText(_campo('Minutos'), '20');
      await _tocar(tester, find.text('Agregar a la rutina'));

      expect(find.byType(BottomSheet), findsNothing);
      expect(find.text('Pedaleo por intervalos'), findsOneWidget);
      expect(find.text('Bicicleta reclinada · lun, mié\n20 min'),
          findsOneWidget);
      expect(find.text('Ejercicios (1 de 20)'), findsOneWidget);

      // Un ejercicio de una sola máquina queda con ella elegida.
      await _agregarEjercicio(
        tester,
        etiqueta: 'Curl de bíceps (Brazos)',
        dias: <String>['mar', 'jue'],
        series: '3',
        repeticiones: '12',
      );
      expect(
        find.text('Mancuernas · mar, jue\n3 series × 12 repeticiones'),
        findsOneWidget,
      );

      await _tocar(tester, find.text('Guardar'));

      // Se envió completa, en orden y en una sola llamada.
      expect(repo.pedidos, hasLength(1));
      final (String nombre, List<LineaNuevaRutina> lineas, String _) =
          repo.pedidos.single;
      expect(nombre, 'Pierna y cardio');
      expect(
        lineas.map((LineaNuevaRutina l) => l.aJson()).toList(),
        <Map<String, dynamic>>[
          <String, dynamic>{
            'ejercicio_id': 9,
            'maquina_id': 11,
            'dias': <int>[1, 3],
            'series': null,
            'repeticiones': null,
            'minutos': 20,
          },
          <String, dynamic>{
            'ejercicio_id': 7,
            'maquina_id': 8,
            'dias': <int>[2, 4],
            'series': 3,
            'repeticiones': 12,
            'minutos': null,
          },
        ],
      );

      // De vuelta en Mis rutinas: confirmación, contador y tope.
      expect(find.text('Rutina creada correctamente'), findsOneWidget);
      expect(find.text('Pierna y cardio'), findsOneWidget);
      expect(find.text('3 de 3 rutinas'), findsOneWidget);
      expect(_activo(tester, 'Nueva rutina'), isFalse);
    });

    testWidgets('las repeticiones fuera de rango o con decimales no pasan (7b)',
        (WidgetTester tester) async {
      await _abrir(tester, _EntrenamientoFalso());
      await _tocar(tester, find.text('Nueva rutina'));
      await _tocar(tester, find.text('Agregar ejercicio'));

      const String error =
          'Las repeticiones deben ser un número entero de 1 a 50.';
      for (final String malo in <String>['51', '12.5', '0']) {
        await tester.enterText(_campo('Repeticiones'), malo);
        await _tocar(tester, find.text('Agregar a la rutina'));
        expect(find.text(error), findsOneWidget, reason: malo);
      }

      await tester.enterText(_campo('Series'), '11');
      await _tocar(tester, find.text('Agregar a la rutina'));
      expect(
        find.text('Las series deben ser un número entero de 1 a 10.'),
        findsOneWidget,
      );

      await tester.enterText(_campo('Minutos'), '61');
      await _tocar(tester, find.text('Agregar a la rutina'));
      expect(
        find.text('Los minutos deben ser un número entero de 1 a 60.'),
        findsOneWidget,
      );
    });

    testWidgets('un ejercicio no se puede agregar dos veces',
        (WidgetTester tester) async {
      await _abrir(tester, _EntrenamientoFalso());
      await _tocar(tester, find.text('Nueva rutina'));
      await _agregarEjercicio(tester, etiqueta: 'Curl de bíceps (Brazos)');

      await _tocar(tester, find.text('Agregar ejercicio'));
      await _tocar(
          tester, find.byType(DropdownButtonFormField<OpcionDeEjercicio>));
      expect(find.text('Curl de bíceps (Brazos)'), findsNothing);
      expect(find.text('Press de banca (Pecho)'), findsWidgets);
    });

    testWidgets('si la red falla, reintentar no duplica la rutina (7d)',
        (WidgetTester tester) async {
      final _EntrenamientoFalso repo =
          _EntrenamientoFalso(rutinas: _dosRutinas())
            ..fallosPorVenir = 1
            ..aplicarAntesDeFallar = true;
      await _abrir(tester, repo);

      await _tocar(tester, find.text('Nueva rutina'));
      await tester.enterText(_campo('Nombre de la rutina'), 'Brazos');
      await _agregarEjercicio(tester, etiqueta: 'Curl de bíceps (Brazos)');

      // Primer intento: la base guardó, pero la respuesta no llegó.
      await _tocar(tester, find.text('Guardar'));
      expect(find.textContaining('No se pudo guardar la rutina'),
          findsOneWidget);
      expect(find.text('Nueva rutina'), findsOneWidget); // sigue en el formulario

      // Segundo intento, con la misma solicitud: no se crea otra.
      await _tocar(tester, find.text('Guardar'));

      expect(repo.pedidos, hasLength(2));
      expect(repo.pedidos[0].$3, repo.pedidos[1].$3);
      expect(
        repo.rutinas.where((Rutina r) => r.nombre == 'Brazos'),
        hasLength(1),
      );
      expect(find.text('Rutina creada correctamente'), findsOneWidget);
      expect(find.text('3 de 3 rutinas'), findsOneWidget);
    });

    testWidgets('un nombre repetido se marca en el campo',
        (WidgetTester tester) async {
      final _EntrenamientoFalso repo =
          _EntrenamientoFalso(rutinas: _dosRutinas());
      await _abrir(tester, repo);

      await _tocar(tester, find.text('Nueva rutina'));
      await tester.enterText(_campo('Nombre de la rutina'), 'fuerza a');
      await _agregarEjercicio(tester, etiqueta: 'Curl de bíceps (Brazos)');
      await _tocar(tester, find.text('Guardar'));

      expect(find.text('Ya tienes una rutina con ese nombre.'), findsOneWidget);
      expect(repo.rutinas, hasLength(2));

      // Al cambiar el nombre, se guarda.
      await tester.enterText(_campo('Nombre de la rutina'), 'Fuerza B');
      await _tocar(tester, find.text('Guardar'));
      expect(find.text('Fuerza B'), findsOneWidget);
      expect(find.text('3 de 3 rutinas'), findsOneWidget);
    });
  });
}
