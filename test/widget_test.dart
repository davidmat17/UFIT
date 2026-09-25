import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ufit/core/datos/errores.dart';
import 'package:ufit/core/datos/puertos/repositorio_gimnasio.dart';
import 'package:ufit/core/datos/repositorios.dart';
import 'package:ufit/core/modelos/maquina.dart';
import 'package:ufit/core/modelos/zona.dart';
import 'package:ufit/desarrollo/pantalla_diagnostico.dart';
import 'package:ufit/desarrollo/pantalla_inicio.dart';

/// Repositorio de prueba: devuelve datos inventados, sin red ni base.
///
/// Que esto sea posible es la razón práctica de tener puertos. Antes,
/// probar la pantalla exigía internet y una base real.
class _GimnasioFalso implements RepositorioGimnasio {
  _GimnasioFalso({this.falla = false});

  final bool falla;

  @override
  Future<List<Zona>> zonas() async {
    if (falla) {
      throw const ErrorDeDatos(
        TipoDeError.sinConexion,
        'No se pudieron cargar las zonas del gimnasio.',
      );
    }
    return const <Zona>[
      Zona(id: 1, nombre: 'Cardiovascular', descripcion: 'Trotadoras'),
      Zona(id: 2, nombre: 'Fuerza', descripcion: 'Peso libre'),
    ];
  }

  @override
  Future<List<Maquina>> maquinas({int? zonaId}) async => const <Maquina>[];

  @override
  Future<String?> normativaVigente() async => null;
}

Widget _envolver(Widget pantalla) => MaterialApp(home: pantalla);

void main() {
  testWidgets('el menú de desarrollo lista los requerimientos',
      (WidgetTester tester) async {
    await tester.pumpWidget(_envolver(const PantallaInicio()));
    await tester.pumpAndSettle();

    expect(find.text('UFIT'), findsOneWidget);
    expect(find.text('RF1'), findsOneWidget);
    expect(find.text('Cuenta y perfil'), findsOneWidget);
  });

  testWidgets('el diagnóstico muestra las zonas que entrega el repositorio',
      (WidgetTester tester) async {
    Repositorios.gimnasio = _GimnasioFalso();

    await tester.pumpWidget(_envolver(const PantallaDiagnostico()));
    await tester.pumpAndSettle();

    expect(find.textContaining('2 zonas leídas'), findsOneWidget);
    expect(find.text('Cardiovascular'), findsOneWidget);
    expect(find.text('Fuerza'), findsOneWidget);
  });

  testWidgets('el diagnóstico muestra el mensaje cuando falla la consulta',
      (WidgetTester tester) async {
    Repositorios.gimnasio = _GimnasioFalso(falla: true);

    await tester.pumpWidget(_envolver(const PantallaDiagnostico()));
    await tester.pumpAndSettle();

    expect(find.text('No se pudo consultar la base'), findsOneWidget);
    expect(
      find.text('No se pudieron cargar las zonas del gimnasio.'),
      findsOneWidget,
    );
    expect(find.text('Reintentar'), findsWidgets);
  });
}
