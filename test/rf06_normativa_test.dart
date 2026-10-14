import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ufit/core/datos/errores.dart';
import 'package:ufit/core/datos/puertos/repositorio_gimnasio.dart';
import 'package:ufit/core/datos/repositorios.dart';
import 'package:ufit/core/modelos/franja_con_instructor.dart';
import 'package:ufit/core/modelos/maquina.dart';
import 'package:ufit/core/modelos/normativa.dart';
import 'package:ufit/core/modelos/zona.dart';
import 'package:ufit/features/gimnasio/pantallas/rf06_normativa.dart';
import 'package:ufit/features/gimnasio/reglas_normativa.dart';

// ---------------------------------------------------------------------
// Datos de prueba
// ---------------------------------------------------------------------

final Normativa _vigente = Normativa(
  titulo: 'Normativa del gimnasio',
  contenido: '1. El uso de toalla es obligatorio.\n'
      '2. No se permite el ingreso de maletas.\n'
      '\n'
      '3. Prohibido el consumo de alimentos dentro del gimnasio.',
  version: 2,
  publicadaEn: DateTime(2026, 10, 13, 18, 30),
);

/// Repositorio falso del RF6: la normativa en memoria, sin red.
class _GimnasioFalso implements RepositorioGimnasio {
  _GimnasioFalso({this.normativa, this.falla = false});

  Normativa? normativa;
  bool falla;
  int consultas = 0;

  @override
  Future<Normativa?> normativaVigente() async {
    consultas++;
    if (falla) {
      throw const ErrorDeDatos(
        TipoDeError.sinConexion,
        'No se pudo cargar la normativa del gimnasio.',
      );
    }
    return normativa;
  }

  // El RF5 se prueba en rf05_catalogo_test.dart.
  @override
  Future<List<Zona>> zonas() async => const <Zona>[];

  @override
  Future<List<Maquina>> maquinas({int? zonaId}) async => const <Maquina>[];

  @override
  Future<List<FranjaConInstructor>> agendaInstructores({
    required DateTime desde,
    required DateTime hasta,
  }) async =>
      const <FranjaConInstructor>[];
}

Future<void> _abrir(WidgetTester tester, _GimnasioFalso repo) async {
  Repositorios.gimnasio = repo;
  await tester.pumpWidget(const MaterialApp(home: PantallaNormativa()));
  await tester.pumpAndSettle();
}

void main() {
  group('reglas de la normativa', () {
    test('separa una regla por línea y quita la numeración original', () {
      expect(
        reglasDeLaNormativa(' 1. Uno\n2) Dos\r\n\n- Tres\n• Cuatro\n10. Diez'),
        <String>['Uno', 'Dos', 'Tres', 'Cuatro', 'Diez'],
      );
    });

    test('no confunde un número dentro de la regla con la numeración', () {
      expect(
        reglasDeLaNormativa('30 min máximo en equipos aeróbicos.'),
        <String>['30 min máximo en equipos aeróbicos.'],
      );
    });

    test('un texto vacío no tiene reglas', () {
      expect(reglasDeLaNormativa('  \n \n'), isEmpty);
    });

    test('escribe la fecha en palabras', () {
      expect(fechaLarga(DateTime(2026, 10, 13)), '13 de octubre de 2026');
      expect(fechaLarga(DateTime(2027, 1, 2)), '2 de enero de 2027');
    });
  });

  group('pantalla de normativa', () {
    testWidgets('muestra las reglas numeradas con versión y fecha',
        (WidgetTester tester) async {
      await _abrir(tester, _GimnasioFalso(normativa: _vigente));

      expect(find.text('Normativa del gimnasio'), findsWidgets);
      expect(
        find.text('Versión 2 · Actualizada el 13 de octubre de 2026'),
        findsOneWidget,
      );
      expect(find.text('El uso de toalla es obligatorio.'), findsOneWidget);
      expect(find.text('No se permite el ingreso de maletas.'), findsOneWidget);
      expect(
        find.text('Prohibido el consumo de alimentos dentro del gimnasio.'),
        findsOneWidget,
      );
      // La numeración la pone la pantalla, no el texto.
      expect(find.text('1'), findsOneWidget);
      expect(find.text('3'), findsOneWidget);
      expect(find.textContaining('Sin conexión'), findsNothing);
    });

    testWidgets('sin conexión muestra la copia guardada y lo avisa (2a)',
        (WidgetTester tester) async {
      await _abrir(
        tester,
        _GimnasioFalso(normativa: _vigente.comoCopiaLocal()),
      );

      expect(find.textContaining('Sin conexión'), findsOneWidget);
      expect(find.text('El uso de toalla es obligatorio.'), findsOneWidget);
      expect(
        find.text('Versión 2 · Actualizada el 13 de octubre de 2026'),
        findsOneWidget,
      );
    });

    testWidgets('si no hay normativa publicada lo dice (2b)',
        (WidgetTester tester) async {
      await _abrir(tester, _GimnasioFalso());

      expect(find.text('Aún no hay normativa publicada'), findsOneWidget);
    });

    testWidgets('si falla la consulta deja reintentar',
        (WidgetTester tester) async {
      final _GimnasioFalso repo = _GimnasioFalso(normativa: _vigente, falla: true);
      await _abrir(tester, repo);

      expect(
        find.text('No se pudo cargar la normativa del gimnasio.'),
        findsOneWidget,
      );

      repo.falla = false;
      await tester.tap(find.text('Reintentar'));
      await tester.pumpAndSettle();

      expect(repo.consultas, 2);
      expect(find.text('El uso de toalla es obligatorio.'), findsOneWidget);
    });
  });
}
