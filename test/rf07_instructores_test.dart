import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ufit/core/datos/errores.dart';
import 'package:ufit/core/datos/puertos/repositorio_gimnasio.dart';
import 'package:ufit/core/datos/repositorios.dart';
import 'package:ufit/core/modelos/franja_con_instructor.dart';
import 'package:ufit/core/modelos/maquina.dart';
import 'package:ufit/core/modelos/normativa.dart';
import 'package:ufit/core/modelos/zona.dart';
import 'package:ufit/core/tema/app_theme.dart';
import 'package:ufit/features/gimnasio/datos/respuestas_de_instructores.dart';
import 'package:ufit/features/gimnasio/pantallas/rf07_instructores.dart';
import 'package:ufit/features/gimnasio/reglas_instructores.dart';

// ---------------------------------------------------------------------
// Datos de prueba
// ---------------------------------------------------------------------

/// Miércoles 14 de octubre de 2026, 9:30 a. m. La semana va del lunes 12
/// al viernes 16.
final DateTime _ahoraDePrueba = DateTime(2026, 10, 14, 9, 30);

int _idDe(DateTime fecha, int hora) => fecha.day * 100 + hora;

String _hora(int h) => '${h.toString().padLeft(2, '0')}:00:00';

/// Franjas de 6 a. m. a 8 p. m., de lunes a viernes, desde el lunes 12 de
/// octubre durante 10 semanas. El viernes 16 no tiene franjas publicadas.
///
/// - Laura Gómez (Entrenamiento funcional): lunes, miércoles y
///   viernes de 6 a 10.
/// - Andrés Rojas (Acondicionamiento cardiovascular): todos los
///   días de 4 a 6 p. m.
/// - Las demás, sin instructor. La del miércoles 14 a las 7 p. m. está
///   cerrada.
List<FranjaConInstructor> _agendaDePrueba() {
  final List<FranjaConInstructor> lista = <FranjaConInstructor>[];
  for (int i = 0; i < 70; i++) {
    final DateTime fecha = DateTime(2026, 10, 12 + i);
    if (fecha.weekday > DateTime.friday) continue;
    if (fecha == DateTime(2026, 10, 16)) continue;

    for (int h = 6; h < 20; h++) {
      final bool laura =
          <int>[1, 3, 5].contains(fecha.weekday) && h >= 6 && h < 10;
      final bool andres = h >= 16 && h < 18;

      lista.add(FranjaConInstructor(
        franjaId: _idDe(fecha, h),
        fecha: fecha,
        horaInicio: _hora(h),
        horaFin: _hora(h + 1),
        abierta: !(fecha == DateTime(2026, 10, 14) && h == 19),
        instructor: laura
            ? 'Laura Gómez'
            : (andres ? 'Andrés Rojas' : null),
        especialidad: laura
            ? 'Entrenamiento funcional'
            : (andres ? 'Acondicionamiento cardiovascular' : null),
      ));
    }
  }
  return lista;
}

/// Repositorio falso del RF7: la agenda en memoria, sin red.
class _GimnasioFalso implements RepositorioGimnasio {
  _GimnasioFalso({List<FranjaConInstructor>? agenda})
      : agenda = agenda ?? _agendaDePrueba();

  List<FranjaConInstructor> agenda;
  bool falla = false;

  /// Los rangos que se consultaron.
  final List<(DateTime, DateTime)> consultas = <(DateTime, DateTime)>[];

  /// El administrador cambia al instructor de una franja.
  void reasignar(int franjaId, {String? instructor, String? especialidad}) {
    agenda = <FranjaConInstructor>[
      for (final FranjaConInstructor f in agenda)
        f.franjaId == franjaId
            ? FranjaConInstructor(
                franjaId: f.franjaId,
                fecha: f.fecha,
                horaInicio: f.horaInicio,
                horaFin: f.horaFin,
                abierta: f.abierta,
                instructor: instructor,
                especialidad: especialidad,
              )
            : f,
    ];
  }

  @override
  Future<List<FranjaConInstructor>> agendaInstructores({
    required DateTime desde,
    required DateTime hasta,
  }) async {
    consultas.add((desde, hasta));
    if (falla) {
      throw const ErrorDeDatos(
        TipoDeError.sinConexion,
        'No se pudo cargar el horario de instructores. '
        'Revisa tu conexión a internet e inténtalo de nuevo.',
      );
    }
    final DateTime d = DateTime(desde.year, desde.month, desde.day);
    final DateTime h = DateTime(hasta.year, hasta.month, hasta.day);
    return agenda
        .where((FranjaConInstructor f) =>
            !f.fecha.isBefore(d) && !f.fecha.isAfter(h))
        .toList();
  }

  // Lo que no es del RF7 no se usa en estas pruebas.
  @override
  Future<List<Zona>> zonas() async => const <Zona>[];

  @override
  Future<List<Maquina>> maquinas({int? zonaId}) async => const <Maquina>[];

  @override
  Future<Normativa?> normativaVigente() async => null;
}

// ---------------------------------------------------------------------
// Ayudas para las pruebas de pantalla
// ---------------------------------------------------------------------

/// Pantalla alta para que el día completo quepa sin desplazarse.
Future<void> _abrir(
  WidgetTester tester,
  _GimnasioFalso repo, {
  DateTime? ahora,
}) async {
  await tester.binding.setSurfaceSize(const Size(800, 3200));
  addTearDown(() => tester.binding.setSurfaceSize(null));

  Repositorios.gimnasio = repo;
  final DateTime reloj = ahora ?? _ahoraDePrueba;

  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.claro,
      home: PantallaInstructores(reloj: () => reloj),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _tocar(WidgetTester tester, Finder finder) async {
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

/// Busca solo dentro de la hoja con el detalle de la franja.
Finder _enHoja(Finder buscado) =>
    find.descendant(of: find.byType(BottomSheet), matching: buscado);

bool _activo(WidgetTester tester, IconData icono) =>
    tester.widget<IconButton>(find.widgetWithIcon(IconButton, icono)).onPressed !=
    null;

const String _respuestaDeLaBase = '''
[
  {"franja_id": 43, "fecha": "2026-10-19", "hora_inicio": "06:00:00",
   "hora_fin": "07:00:00", "abierta": true, "instructor": "Laura Gómez",
   "especialidad": "Entrenamiento funcional"},
  {"franja_id": 44, "fecha": "2026-10-19", "hora_inicio": "07:00:00",
   "hora_fin": "08:00:00", "abierta": false, "instructor": null,
   "especialidad": null},
  {"franja_id": 45, "fecha": "2026-10-19", "hora_inicio": "08:00:00",
   "hora_fin": "09:00:00", "abierta": true, "instructor": "   ",
   "especialidad": ""},
  {"franja_id": "no es un número"},
  "tampoco es una fila"
]
''';

void main() {
  // -------------------------------------------------------------------
  group('fechas y textos', () {
    test('abre en el día de hoy, o el lunes siguiente si es fin de semana', () {
      expect(primerDiaAMostrar(DateTime(2026, 10, 14, 9)), DateTime(2026, 10, 14));
      expect(primerDiaAMostrar(DateTime(2026, 10, 16, 20)), DateTime(2026, 10, 16));
      expect(primerDiaAMostrar(DateTime(2026, 10, 17, 9)), DateTime(2026, 10, 19));
      expect(primerDiaAMostrar(DateTime(2026, 10, 18, 9)), DateTime(2026, 10, 19));
      // Cruza de mes.
      expect(primerDiaAMostrar(DateTime(2026, 10, 31)), DateTime(2026, 11, 2));
    });

    test('la semana de servicio va de lunes a viernes', () {
      final List<DateTime> dias = diasDeServicio(DateTime(2026, 10, 26));
      expect(dias, hasLength(5));
      expect(dias.first, DateTime(2026, 10, 26));
      expect(dias.last, DateTime(2026, 10, 30));
      expect(dias.map(diaCorto), <String>['lun', 'mar', 'mié', 'jue', 'vie']);
    });

    test('escribe la semana, también cuando cruza de mes o de año', () {
      expect(semanaDeServicio(DateTime(2026, 10, 12)), '12 – 16 de octubre de 2026');
      expect(
        semanaDeServicio(DateTime(2026, 11, 30)),
        '30 de noviembre – 4 de diciembre de 2026',
      );
      expect(
        semanaDeServicio(DateTime(2026, 12, 28)),
        '28 de diciembre de 2026 – 1 de enero de 2027',
      );
    });

    test('escribe el día y la franja', () {
      expect(diaLargo(DateTime(2026, 10, 14)), 'Miércoles 14 de octubre');
      expect(horaCorta('06:00:00'), '06:00');
      expect(horaCorta('7:30'), '07:30');

      final FranjaConInstructor f = _agendaDePrueba().first;
      expect(rangoDe(f), '06:00 – 07:00');
    });

    test('una franja termina a su hora de fin', () {
      final FranjaConInstructor seis = _agendaDePrueba()
          .firstWhere((FranjaConInstructor f) => f.franjaId == _idDe(DateTime(2026, 10, 14), 6));
      expect(franjaTermino(seis, DateTime(2026, 10, 14, 6, 59)), isFalse);
      expect(franjaTermino(seis, DateTime(2026, 10, 14, 7)), isTrue);
    });
  });

  // -------------------------------------------------------------------
  group('instructor de una franja', () {
    FranjaConInstructor franja({
      String? instructor,
      String? especialidad,
    }) =>
        FranjaConInstructor(
          franjaId: 1,
          fecha: DateTime(2026, 10, 14),
          horaInicio: '06:00:00',
          horaFin: '07:00:00',
          abierta: true,
          instructor: instructor,
          especialidad: especialidad,
        );

    test('sin instructor nunca queda vacío (CU07, 4b)', () {
      expect(textoDelInstructor(franja()), 'Sin instructor asignado');
      expect(textoDelInstructor(franja(instructor: '')), 'Sin instructor asignado');
      expect(textoDelInstructor(franja(instructor: 'Laura Gómez')), 'Laura Gómez');
    });

    test('el detalle es la especialidad, si la hay', () {
      expect(
        detalleDelInstructor(franja(
          instructor: 'Laura Gómez',
          especialidad: 'Entrenamiento funcional',
        )),
        'Entrenamiento funcional',
      );
      expect(detalleDelInstructor(franja(instructor: 'Laura Gómez')), isNull);
      // Sin instructor no se muestra especialidad aunque llegue.
      expect(detalleDelInstructor(franja(especialidad: 'Funcional')), isNull);
    });

    test('resume el día', () {
      final List<FranjaConInstructor> miercoles =
          agendaDelDia(_agendaDePrueba(), DateTime(2026, 10, 14));
      expect(miercoles, hasLength(14));
      expect(resumenDelDia(miercoles), 'Instructor en 6 de 14 franjas');

      expect(
        resumenDelDia(<FranjaConInstructor>[franja()]),
        'Sin instructores asignados este día',
      );
      expect(
        resumenDelDia(<FranjaConInstructor>[franja(instructor: 'Laura Gómez')]),
        'Hay instructor en todas las franjas',
      );
    });

    test('la agenda del día sale ordenada por hora', () {
      final List<FranjaConInstructor> desordenada =
          agendaDelDia(_agendaDePrueba(), DateTime(2026, 10, 14)).reversed.toList();
      final List<FranjaConInstructor> ordenada =
          agendaDelDia(desordenada, DateTime(2026, 10, 14));
      expect(ordenada.first.horaInicio, '06:00:00');
      expect(ordenada.last.horaInicio, '19:00:00');
    });
  });

  // -------------------------------------------------------------------
  group('lo que responde la base', () {
    test('lee la agenda y se salta las filas con forma inesperada', () {
      final List<FranjaConInstructor> agenda =
          agendaDesdeRespuesta(jsonDecode(_respuestaDeLaBase));

      expect(agenda, hasLength(3));

      expect(agenda[0].franjaId, 43);
      expect(agenda[0].fecha, DateTime(2026, 10, 19));
      expect(agenda[0].instructor, 'Laura Gómez');
      expect(agenda[0].especialidad, 'Entrenamiento funcional');
      expect(agenda[0].tieneInstructor, isTrue);

      expect(agenda[1].abierta, isFalse);
      expect(agenda[1].tieneInstructor, isFalse);

      // Un nombre en blanco cuenta como sin instructor.
      expect(agenda[2].instructor, isNull);
      expect(agenda[2].especialidad, isNull);
      expect(textoDelInstructor(agenda[2]), 'Sin instructor asignado');
    });

    test('una respuesta que no es una lista da una agenda vacía', () {
      expect(agendaDesdeRespuesta(null), isEmpty);
      expect(agendaDesdeRespuesta(<String, dynamic>{}), isEmpty);
    });
  });

  // -------------------------------------------------------------------
  group('pantalla del RF7', () {
    testWidgets('muestra el horario de hoy con el instructor de cada franja',
        (WidgetTester tester) async {
      final _GimnasioFalso repo = _GimnasioFalso();
      await _abrir(tester, repo);

      // Consulta solo la semana que se ve, de lunes a viernes.
      expect(repo.consultas, hasLength(1));
      expect(repo.consultas.single.$1, DateTime(2026, 10, 12));
      expect(repo.consultas.single.$2, DateTime(2026, 10, 16));

      expect(find.text('12 – 16 de octubre de 2026'), findsOneWidget);
      expect(find.text('Miércoles 14 de octubre'), findsOneWidget);
      expect(find.text('Instructor en 6 de 14 franjas'), findsOneWidget);

      expect(find.text('Laura Gómez'), findsNWidgets(4));
      expect(find.text('Entrenamiento funcional'), findsNWidgets(4));
      expect(find.text('Andrés Rojas'), findsNWidgets(2));
      expect(find.text('Acondicionamiento cardiovascular'), findsNWidgets(2));
      expect(find.text('Sin instructor asignado'), findsNWidgets(8));

      // A las 9:30 ya terminaron las de 6, 7 y 8; la de 7 p. m. está cerrada.
      expect(find.text('Ya terminó'), findsNWidgets(3));
      expect(find.text('Cerrada'), findsOneWidget);

      // El fin de semana no aparece.
      expect(find.text('sáb'), findsNothing);
      expect(find.text('dom'), findsNothing);
    });

    testWidgets('cambia de día dentro de la semana', (WidgetTester tester) async {
      await _abrir(tester, _GimnasioFalso());

      await _tocar(tester, find.text('jue'));

      expect(find.text('Jueves 15 de octubre'), findsOneWidget);
      // El jueves Laura no está; Andrés sí.
      expect(find.text('Laura Gómez'), findsNothing);
      expect(find.text('Andrés Rojas'), findsNWidgets(2));
      expect(find.text('Sin instructor asignado'), findsNWidgets(12));
    });

    testWidgets('un día sin franjas lo dice', (WidgetTester tester) async {
      await _abrir(tester, _GimnasioFalso());

      await _tocar(tester, find.text('vie'));

      expect(find.text('Viernes 16 de octubre'), findsOneWidget);
      expect(find.text('No hay franjas publicadas para este día.'), findsOneWidget);
    });

    testWidgets('al tocar una franja muestra el instructor y su especialidad',
        (WidgetTester tester) async {
      await _abrir(tester, _GimnasioFalso());

      await _tocar(tester, find.text('09:00 – 10:00'));

      expect(_enHoja(find.text('Miércoles 14 de octubre · 09:00 – 10:00')),
          findsOneWidget);
      expect(_enHoja(find.text('Instructor')), findsOneWidget);
      expect(_enHoja(find.text('Laura Gómez')), findsOneWidget);
      expect(_enHoja(find.text('Especialidad')), findsOneWidget);
      expect(_enHoja(find.text('Entrenamiento funcional')), findsOneWidget);
      // El instructor no tiene zona: atiende todo el gimnasio.
      expect(_enHoja(find.textContaining('a cargo de todo el gimnasio')),
          findsOneWidget);
      expect(_enHoja(find.text('Zona')), findsNothing);
    });

    testWidgets('una franja sin instructor lo dice también en el detalle',
        (WidgetTester tester) async {
      await _abrir(tester, _GimnasioFalso());

      await _tocar(tester, find.text('14:00 – 15:00'));

      expect(_enHoja(find.text('Sin instructor asignado')), findsOneWidget);
      expect(_enHoja(find.textContaining('no hay un instructor')), findsOneWidget);
      expect(_enHoja(find.text('Especialidad')), findsNothing);
    });

    testWidgets('el detalle de una franja cerrada lo advierte',
        (WidgetTester tester) async {
      await _abrir(tester, _GimnasioFalso());

      await _tocar(tester, find.text('19:00 – 20:00'));

      expect(_enHoja(find.text('La administración cerró esta franja.')),
          findsOneWidget);
    });

    testWidgets('muestra la asignación más reciente del administrador (4a)',
        (WidgetTester tester) async {
      final _GimnasioFalso repo = _GimnasioFalso();
      await _abrir(tester, repo);
      expect(find.text('Laura Gómez'), findsNWidgets(4));

      // El administrador cambia la franja de las 9:00 del miércoles 14.
      repo.reasignar(
        _idDe(DateTime(2026, 10, 14), 9),
        instructor: 'Camila Duarte',
        especialidad: 'Técnica en máquinas guiadas',
      );

      // Ir a la semana siguiente y volver consulta de nuevo la base.
      await _tocar(tester, find.byTooltip('Semana siguiente'));
      await _tocar(tester, find.byTooltip('Semana anterior'));

      expect(repo.consultas, hasLength(3));
      expect(find.text('Miércoles 14 de octubre'), findsOneWidget);
      expect(find.text('Laura Gómez'), findsNWidgets(3));
      expect(find.text('Camila Duarte'), findsOneWidget);
      expect(find.text('Técnica en máquinas guiadas'), findsOneWidget);
    });

    testWidgets('navega entre semanas hasta el límite',
        (WidgetTester tester) async {
      final _GimnasioFalso repo = _GimnasioFalso();
      await _abrir(tester, repo);

      // No se puede ir a semanas que ya pasaron.
      expect(_activo(tester, Icons.chevron_left), isFalse);
      expect(_activo(tester, Icons.chevron_right), isTrue);

      // Al cambiar de semana se queda en el mismo día de la semana.
      await _tocar(tester, find.byTooltip('Semana siguiente'));
      expect(find.text('19 – 23 de octubre de 2026'), findsOneWidget);
      expect(find.text('Miércoles 21 de octubre'), findsOneWidget);
      expect(repo.consultas.last.$1, DateTime(2026, 10, 19));
      expect(repo.consultas.last.$2, DateTime(2026, 10, 23));

      for (int i = 1; i < horizonteEnSemanas; i++) {
        await _tocar(tester, find.byTooltip('Semana siguiente'));
      }
      expect(_activo(tester, Icons.chevron_right), isFalse);
      expect(_activo(tester, Icons.chevron_left), isTrue);
    });

    testWidgets('un sábado abre en el lunes siguiente',
        (WidgetTester tester) async {
      final _GimnasioFalso repo = _GimnasioFalso();
      await _abrir(tester, repo, ahora: DateTime(2026, 10, 17, 10));

      expect(find.text('19 – 23 de octubre de 2026'), findsOneWidget);
      expect(find.text('Lunes 19 de octubre'), findsOneWidget);
      expect(repo.consultas.single.$1, DateTime(2026, 10, 19));
      expect(_activo(tester, Icons.chevron_left), isFalse);
    });

    testWidgets('si falla la consulta, avisa y deja reintentar',
        (WidgetTester tester) async {
      final _GimnasioFalso repo = _GimnasioFalso()..falla = true;
      await _abrir(tester, repo);

      expect(find.textContaining('No se pudo cargar el horario'), findsOneWidget);
      expect(find.text('Laura Gómez'), findsNothing);

      repo.falla = false;
      await _tocar(tester, find.text('Reintentar'));

      expect(find.text('Laura Gómez'), findsNWidgets(4));
    });
  });
}
