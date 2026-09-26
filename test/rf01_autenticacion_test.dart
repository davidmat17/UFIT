import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ufit/core/datos/errores.dart';
import 'package:ufit/core/datos/puertos/repositorio_perfiles.dart';
import 'package:ufit/core/datos/repositorios.dart';
import 'package:ufit/core/modelos/perfil.dart';
import 'package:ufit/core/modelos/sesion.dart';
import 'package:ufit/features/cuenta/pantallas/rf01_autenticacion.dart';
import 'package:ufit/features/cuenta/reglas_cuenta.dart';

/// Repositorio de cuenta falso: simula a Microsoft y a la base en
/// memoria, sin red.
class _CuentaFalsa implements RepositorioPerfiles {
  _CuentaFalsa({this.sesion, this.perfil, this.documentoOcupado});

  SesionActiva? sesion;
  Perfil? perfil;
  final String? documentoOcupado;

  final StreamController<void> _cambios = StreamController<void>.broadcast();
  int cierresDeSesion = 0;

  /// Lo que haría Microsoft al volver a la app con una cuenta.
  void simularIngreso(SesionActiva nueva) {
    sesion = nueva;
    _cambios.add(null);
  }

  @override
  Stream<void> get cambiosDeSesion => _cambios.stream;

  @override
  SesionActiva? sesionActual() => sesion;

  @override
  Future<void> iniciarSesionInstitucional() async {}

  @override
  Future<void> cerrarSesion() async {
    cierresDeSesion++;
    sesion = null;
    _cambios.add(null);
  }

  @override
  Future<Perfil?> perfilActual() async => sesion == null ? null : perfil;

  @override
  Future<Perfil> completarRegistro({
    required String nombre,
    required String apellido,
    required String documento,
    String? telefono,
  }) async {
    if (documento == documentoOcupado) {
      throw const ErrorDeDatos(
        TipoDeError.reglaDeNegocio,
        'Ya existe una cuenta registrada con ese número de documento.',
      );
    }
    perfil = Perfil(
      id: 'id-1',
      nombre: nombre,
      apellido: apellido,
      documento: documento,
      correo: sesion!.correo,
      telefono: telefono,
    );
    return perfil!;
  }

  @override
  Future<Perfil> actualizarPerfil({
    required String nombre,
    required String apellido,
    String? telefono,
  }) async =>
      throw UnimplementedError();
}

const SesionActiva _sesionUis = SesionActiva(
  correo: 'david.perez@correo.uis.edu.co',
  nombreCompleto: 'DAVID ALEJANDRO PEREZ GOMEZ',
);

const Perfil _perfilDavid = Perfil(
  id: 'id-1',
  nombre: 'David',
  apellido: 'Perez',
  documento: '1098765432',
  correo: 'david.perez@correo.uis.edu.co',
);

/// El botón puede quedar debajo del borde de la pantalla de prueba:
/// primero se desplaza hasta él y después se toca.
Future<void> _tocar(WidgetTester tester, String texto) async {
  await tester.ensureVisible(find.text(texto));
  await tester.pumpAndSettle();
  await tester.tap(find.text(texto));
}

Widget _app() => MaterialApp(
      home: CompuertaDeSesion(
        inicio: (_) => const Scaffold(body: Text('INICIO DE LA APP')),
      ),
    );

void main() {
  group('reglas de cuenta', () {
    test('acepta solo los dominios de la UIS', () {
      expect(esCorreoInstitucional('ana@uis.edu.co'), isTrue);
      expect(esCorreoInstitucional('Ana@Correo.UIS.edu.co '), isTrue);
      expect(esCorreoInstitucional('ana@gmail.com'), isFalse);
      expect(esCorreoInstitucional('ana@uis.edu.co.falso.com'), isFalse);
      expect(esCorreoInstitucional('ana@nouis.edu.co'), isFalse);
      expect(esCorreoInstitucional(''), isFalse);
    });

    test('parte el nombre de Microsoft en nombre y apellido', () {
      expect(dividirNombre('DAVID ALEJANDRO PEREZ GOMEZ'),
          (nombre: 'David Alejandro', apellido: 'Perez Gomez'));
      expect(dividirNombre('sergio rueda diaz'),
          (nombre: 'Sergio', apellido: 'Rueda Diaz'));
      expect(dividirNombre('Ana'), (nombre: 'Ana', apellido: ''));
      expect(dividirNombre(null), (nombre: '', apellido: ''));
    });

    test('valida documento y celular', () {
      expect(validarDocumento('1098765432'), isNull);
      expect(validarDocumento('1.098.765'), isNotNull);
      expect(validarDocumento(''), isNotNull);
      expect(validarTelefono(''), isNull);
      expect(validarTelefono('3001234567'), isNull);
      expect(validarTelefono('6071234'), isNotNull);
    });
  });

  group('compuerta de sesión', () {
    testWidgets('sin sesión muestra el ingreso institucional',
        (WidgetTester tester) async {
      Repositorios.perfiles = _CuentaFalsa();

      await tester.pumpWidget(_app());
      await tester.pumpAndSettle();

      expect(find.text('Ingresar con correo institucional'), findsOneWidget);
      expect(find.text('INICIO DE LA APP'), findsNothing);
    });

    testWidgets('con sesión y perfil entra directo a la app',
        (WidgetTester tester) async {
      Repositorios.perfiles =
          _CuentaFalsa(sesion: _sesionUis, perfil: _perfilDavid);

      await tester.pumpWidget(_app());
      await tester.pumpAndSettle();

      expect(find.text('INICIO DE LA APP'), findsOneWidget);
    });

    testWidgets('un correo que no es de la UIS se rechaza y cierra sesión',
        (WidgetTester tester) async {
      final _CuentaFalsa cuenta = _CuentaFalsa();
      Repositorios.perfiles = cuenta;

      await tester.pumpWidget(_app());
      await tester.pumpAndSettle();

      cuenta.simularIngreso(const SesionActiva(correo: 'david@gmail.com'));
      await tester.pumpAndSettle();

      expect(cuenta.cierresDeSesion, 1);
      expect(find.textContaining('solo acepta'), findsOneWidget);
      expect(find.text('Ingresar con correo institucional'), findsOneWidget);
      expect(find.text('INICIO DE LA APP'), findsNothing);
    });

    testWidgets('la primera vez pide completar el registro y luego entra',
        (WidgetTester tester) async {
      final _CuentaFalsa cuenta = _CuentaFalsa();
      Repositorios.perfiles = cuenta;

      await tester.pumpWidget(_app());
      await tester.pumpAndSettle();

      cuenta.simularIngreso(_sesionUis);
      await tester.pumpAndSettle();

      expect(find.text('Crea tu cuenta'), findsOneWidget);
      // El nombre llega prellenado desde Microsoft.
      expect(find.text('David Alejandro'), findsOneWidget);
      expect(find.text('Perez Gomez'), findsOneWidget);

      await tester.enterText(
          find.widgetWithText(TextFormField, 'Número de documento'),
          '1098765432');
      await _tocar(tester, 'Crear cuenta');
      await tester.pumpAndSettle();

      expect(cuenta.perfil?.documento, '1098765432');
      expect(find.text('INICIO DE LA APP'), findsOneWidget);
    });

    testWidgets('el registro no avanza sin documento',
        (WidgetTester tester) async {
      Repositorios.perfiles = _CuentaFalsa(sesion: _sesionUis);

      await tester.pumpWidget(_app());
      await tester.pumpAndSettle();

      await _tocar(tester, 'Crear cuenta');
      await tester.pumpAndSettle();

      expect(find.text('Escribe tu número de documento.'), findsOneWidget);
      expect(find.text('INICIO DE LA APP'), findsNothing);
    });

    testWidgets('un documento repetido muestra el mensaje de la base',
        (WidgetTester tester) async {
      Repositorios.perfiles =
          _CuentaFalsa(sesion: _sesionUis, documentoOcupado: '1098765432');

      await tester.pumpWidget(_app());
      await tester.pumpAndSettle();

      await tester.enterText(
          find.widgetWithText(TextFormField, 'Número de documento'),
          '1098765432');
      await _tocar(tester, 'Crear cuenta');
      await tester.pumpAndSettle();

      expect(
        find.text('Ya existe una cuenta registrada con ese número de documento.'),
        findsOneWidget,
      );
      expect(find.text('INICIO DE LA APP'), findsNothing);
    });

    testWidgets('una cuenta desactivada no entra',
        (WidgetTester tester) async {
      Repositorios.perfiles = _CuentaFalsa(
        sesion: _sesionUis,
        perfil: const Perfil(
          id: 'id-1',
          nombre: 'David',
          apellido: 'Perez',
          documento: '1098765432',
          correo: 'david.perez@correo.uis.edu.co',
          activo: false,
        ),
      );

      await tester.pumpWidget(_app());
      await tester.pumpAndSettle();

      expect(find.text('Cuenta desactivada'), findsOneWidget);
      expect(find.text('INICIO DE LA APP'), findsNothing);
    });

    testWidgets('cerrar sesión devuelve al ingreso',
        (WidgetTester tester) async {
      final _CuentaFalsa cuenta =
          _CuentaFalsa(sesion: _sesionUis, perfil: _perfilDavid);
      Repositorios.perfiles = cuenta;

      await tester.pumpWidget(_app());
      await tester.pumpAndSettle();
      expect(find.text('INICIO DE LA APP'), findsOneWidget);

      await cuenta.cerrarSesion();
      await tester.pumpAndSettle();

      expect(find.text('Ingresar con correo institucional'), findsOneWidget);
    });
  });
}
