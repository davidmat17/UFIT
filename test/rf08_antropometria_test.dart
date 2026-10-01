import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ufit/core/datos/errores.dart';
import 'package:ufit/core/datos/puertos/repositorio_perfiles.dart';
import 'package:ufit/core/datos/repositorios.dart';
import 'package:ufit/core/modelos/medicion.dart';
import 'package:ufit/core/modelos/perfil.dart';
import 'package:ufit/core/modelos/sesion.dart';
import 'package:ufit/features/cuenta/pantallas/rf08_antropometria.dart';
import 'package:ufit/features/cuenta/reglas_antropometria.dart';

/// Repositorio falso del RF8: guarda las mediciones en memoria, sin red.
class _MedidasFalsas implements RepositorioPerfiles {
  _MedidasFalsas({
    List<MedicionAntropometrica>? iniciales,
    this.errorAlGuardar,
  }) : mediciones = iniciales ?? <MedicionAntropometrica>[];

  /// De la más reciente a la más antigua, como las entrega Supabase.
  final List<MedicionAntropometrica> mediciones;

  /// Si no es null, registrarMedicion falla con este mensaje.
  final String? errorAlGuardar;

  int _siguienteId = 100;

  @override
  Future<List<MedicionAntropometrica>> misMediciones() async =>
      List<MedicionAntropometrica>.of(mediciones);

  @override
  Future<MedicionAntropometrica> registrarMedicion({
    required double pesoKg,
    required double estaturaCm,
    double? cinturaCm,
    double? caderaCm,
    double? pechoCm,
    double? brazoCm,
    double? musloCm,
  }) async {
    if (errorAlGuardar != null) {
      throw ErrorDeDatos(TipoDeError.reglaDeNegocio, errorAlGuardar!);
    }
    final MedicionAntropometrica nueva = MedicionAntropometrica(
      id: _siguienteId++,
      registradaEn: DateTime(2026, 10, 15),
      pesoKg: pesoKg,
      estaturaCm: estaturaCm,
      cinturaCm: cinturaCm,
      caderaCm: caderaCm,
      pechoCm: pechoCm,
      brazoCm: brazoCm,
      musloCm: musloCm,
    );
    mediciones.insert(0, nueva);
    return nueva;
  }

  @override
  Future<void> borrarMedicion(int id) async =>
      mediciones.removeWhere((MedicionAntropometrica m) => m.id == id);

  // Lo del RF1 no se usa en estas pruebas.
  @override
  Future<void> iniciarSesionInstitucional() async {}

  @override
  Stream<void> get cambiosDeSesion => const Stream<void>.empty();

  @override
  SesionActiva? sesionActual() => null;

  @override
  Future<Perfil> completarRegistro({
    required String nombre,
    required String apellido,
    required String documento,
    String? telefono,
  }) async =>
      throw UnimplementedError();

  @override
  Future<void> cerrarSesion() async {}

  @override
  Future<Perfil?> perfilActual() async => null;

  @override
  Future<Perfil> actualizarPerfil({
    required String nombre,
    required String apellido,
    String? telefono,
  }) async =>
      throw UnimplementedError();
}

final MedicionAntropometrica _octubre = MedicionAntropometrica(
  id: 2,
  registradaEn: DateTime(2026, 10, 1),
  pesoKg: 70,
  estaturaCm: 175,
  cinturaCm: 80,
);

final MedicionAntropometrica _septiembre = MedicionAntropometrica(
  id: 1,
  registradaEn: DateTime(2026, 9, 1),
  pesoKg: 72,
  estaturaCm: 175,
);

/// Pantalla alta para que el historial completo quepa sin desplazarse.
Future<void> _abrir(WidgetTester tester, _MedidasFalsas repo) async {
  await tester.binding.setSurfaceSize(const Size(800, 1600));
  addTearDown(() => tester.binding.setSurfaceSize(null));

  Repositorios.perfiles = repo;
  await tester.pumpWidget(const MaterialApp(home: PantallaAntropometria()));
  await tester.pumpAndSettle();
}

Future<void> _tocar(WidgetTester tester, String texto) async {
  await tester.ensureVisible(find.text(texto));
  await tester.pumpAndSettle();
  await tester.tap(find.text(texto));
  await tester.pumpAndSettle();
}

Finder _campo(String etiqueta) => find.widgetWithText(TextFormField, etiqueta);

void main() {
  group('reglas de antropometría', () {
    test('lee números con coma o con punto', () {
      expect(leerNumero('70,5'), 70.5);
      expect(leerNumero(' 70.5 '), 70.5);
      expect(leerNumero(''), isNull);
      expect(leerNumero('setenta'), isNull);
    });

    test('peso y estatura son obligatorios y con rango', () {
      expect(validarPeso('70'), isNull);
      expect(validarPeso(''), 'Escribe tu peso.');
      expect(validarPeso('5'), isNotNull);
      expect(validarPeso('abc'), isNotNull);
      expect(validarEstatura('175'), isNull);
      // La estatura en metros es el error típico.
      expect(validarEstatura('1,75'), isNotNull);
    });

    test('las circunferencias son opcionales', () {
      expect(validarCircunferencia(''), isNull);
      expect(validarCircunferencia('80'), isNull);
      expect(validarCircunferencia('900'), isNotNull);
    });

    test('calcula y clasifica el IMC', () {
      expect(_octubre.imc, closeTo(22.86, 0.01));
      expect(clasificarImc(17), 'Bajo peso');
      expect(clasificarImc(22.9), 'Peso normal');
      expect(clasificarImc(27), 'Sobrepeso');
      expect(clasificarImc(31), 'Obesidad');
    });

    test('formatea números, diferencias y fechas en español', () {
      expect(formatearNumero(70), '70');
      expect(formatearNumero(70.5), '70,5');
      expect(formatearNumero(22.857), '22,9');
      expect(formatearDiferencia(1.5), '+1,5');
      expect(formatearDiferencia(-2), '-2');
      expect(formatearDiferencia(0.01), '0');
      expect(formatearFecha(DateTime(2026, 10, 1)), '1 de octubre de 2026');
      expect(formatearFechaCorta(DateTime(2026, 9, 1)), '1 sep 2026');
    });
  });

  group('pantalla del RF8', () {
    testWidgets('sin mediciones invita a registrar la primera',
        (WidgetTester tester) async {
      await _abrir(tester, _MedidasFalsas());

      expect(find.text('Aún no has registrado tus medidas'), findsOneWidget);
      expect(find.text('Registrar medición'), findsOneWidget);
    });

    testWidgets('muestra la última medición, la evolución y el historial',
        (WidgetTester tester) async {
      await _abrir(
        tester,
        _MedidasFalsas(iniciales: <MedicionAntropometrica>[_octubre, _septiembre]),
      );

      expect(find.text('Última medición · 1 de octubre de 2026'), findsOneWidget);
      // También sale en el eje de la gráfica.
      expect(find.text('70 kg'), findsWidgets);
      expect(find.text('-2 kg'), findsOneWidget);
      expect(find.text('22,9'), findsOneWidget);
      expect(find.text('Peso normal'), findsOneWidget);
      expect(find.text('Cintura 80'), findsOneWidget);
      expect(find.text('Evolución del peso'), findsOneWidget);
      expect(find.text('Historial (2)'), findsOneWidget);
      expect(find.text('1 de septiembre de 2026'), findsOneWidget);
    });

    testWidgets('registrar una medición la suma al historial',
        (WidgetTester tester) async {
      final _MedidasFalsas repo =
          _MedidasFalsas(iniciales: <MedicionAntropometrica>[_octubre]);
      await _abrir(tester, repo);

      await _tocar(tester, 'Registrar medición');

      // La estatura viene de la medición anterior; el peso no.
      expect(find.text('Nueva medición'), findsOneWidget);
      expect(find.text('175'), findsOneWidget);
      expect(find.text('Antes: 70'), findsOneWidget);

      await tester.enterText(_campo('Peso (kg)'), '69,5');
      await _tocar(tester, 'Guardar medición');

      expect(repo.mediciones, hasLength(2));
      expect(repo.mediciones.first.pesoKg, 69.5);
      expect(find.text('Medición registrada.'), findsOneWidget);
      expect(find.text('69,5 kg'), findsWidgets);
      expect(find.text('-0,5 kg'), findsOneWidget);
      expect(find.text('Historial (2)'), findsOneWidget);
    });

    testWidgets('no guarda sin peso', (WidgetTester tester) async {
      final _MedidasFalsas repo = _MedidasFalsas();
      await _abrir(tester, repo);

      await _tocar(tester, 'Registrar medición');
      await tester.enterText(_campo('Estatura (cm)'), '175');
      await _tocar(tester, 'Guardar medición');

      expect(find.text('Escribe tu peso.'), findsOneWidget);
      expect(repo.mediciones, isEmpty);
    });

    testWidgets('muestra el error de la base y se queda en el formulario',
        (WidgetTester tester) async {
      await _abrir(
        tester,
        _MedidasFalsas(errorAlGuardar: 'Alguna de las medidas está fuera del '
            'rango permitido. Revísalas.'),
      );

      await _tocar(tester, 'Registrar medición');
      await tester.enterText(_campo('Peso (kg)'), '70');
      await tester.enterText(_campo('Estatura (cm)'), '175');
      await _tocar(tester, 'Guardar medición');

      expect(find.textContaining('fuera del rango permitido'), findsOneWidget);
      expect(find.text('Nueva medición'), findsOneWidget);
    });

    testWidgets('borra una medición después de confirmar',
        (WidgetTester tester) async {
      final _MedidasFalsas repo = _MedidasFalsas(
        iniciales: <MedicionAntropometrica>[_octubre, _septiembre],
      );
      await _abrir(tester, repo);

      await tester.tap(find.byTooltip('Borrar medición').last);
      await tester.pumpAndSettle();
      expect(find.text('¿Borrar esta medición?'), findsOneWidget);

      await tester.tap(find.widgetWithText(FilledButton, 'Borrar'));
      await tester.pumpAndSettle();

      expect(repo.mediciones.map((MedicionAntropometrica m) => m.id), <int>[2]);
      expect(find.text('Historial (1)'), findsOneWidget);
      expect(find.text('Evolución del peso'), findsNothing);
    });
  });
}
