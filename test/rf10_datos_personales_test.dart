import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ufit/core/datos/errores.dart';
import 'package:ufit/core/datos/puertos/repositorio_perfiles.dart';
import 'package:ufit/core/datos/repositorios.dart';
import 'package:ufit/core/modelos/medicion.dart';
import 'package:ufit/core/modelos/perfil.dart';
import 'package:ufit/core/modelos/sesion.dart';
import 'package:ufit/features/cuenta/pantallas/rf10_datos_personales.dart';
import 'package:ufit/features/cuenta/reglas_cuenta.dart';

/// Repositorio falso del RF10: un perfil en memoria, sin red.
class _PerfilFalso implements RepositorioPerfiles {
  _PerfilFalso({
    this.perfil,
    this.errorAlCargar,
    this.errorAlGuardar,
  });

  Perfil? perfil;
  final String? errorAlCargar;
  final String? errorAlGuardar;

  int guardados = 0;

  @override
  Future<Perfil?> perfilActual() async {
    if (errorAlCargar != null) {
      throw ErrorDeDatos(TipoDeError.sinConexion, errorAlCargar!);
    }
    return perfil;
  }

  @override
  Future<Perfil> actualizarPerfil({
    required String nombre,
    required String apellido,
    String? telefono,
  }) async {
    if (errorAlGuardar != null) {
      throw ErrorDeDatos(TipoDeError.sinConexion, errorAlGuardar!);
    }
    guardados++;
    final Perfil p = perfil!;
    final String tel = (telefono ?? '').trim();
    // Lo mismo que hace el adaptador: recorta espacios y deja el
    // celular vacío como null. Documento, correo y rol no cambian.
    perfil = Perfil(
      id: p.id,
      nombre: nombre.trim(),
      apellido: apellido.trim(),
      documento: p.documento,
      correo: p.correo,
      telefono: tel.isEmpty ? null : tel,
      rol: p.rol,
      activo: p.activo,
    );
    return perfil!;
  }

  // Lo demás no se usa en estas pruebas.
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
  Future<List<MedicionAntropometrica>> misMediciones() async =>
      throw UnimplementedError();

  @override
  Future<MedicionAntropometrica> registrarMedicion({
    required double pesoKg,
    required double estaturaCm,
    double? cinturaCm,
    double? caderaCm,
    double? pechoCm,
    double? brazoCm,
    double? musloCm,
  }) async =>
      throw UnimplementedError();

  @override
  Future<void> borrarMedicion(int id) async => throw UnimplementedError();
}

const Perfil _david = Perfil(
  id: 'id-1',
  nombre: 'David',
  apellido: 'Perez',
  documento: '1098765432',
  correo: 'david.perez@correo.uis.edu.co',
);

Future<void> _abrir(WidgetTester tester, _PerfilFalso repo) async {
  await tester.binding.setSurfaceSize(const Size(800, 1400));
  addTearDown(() => tester.binding.setSurfaceSize(null));

  Repositorios.perfiles = repo;
  await tester.pumpWidget(const MaterialApp(home: PantallaDatosPersonales()));
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
  test('nombra los tres roles', () {
    expect(nombreDelRol(RolUsuario.usuario), 'Usuario');
    expect(nombreDelRol(RolUsuario.instructor), 'Instructor');
    expect(nombreDelRol(RolUsuario.administrador), 'Administrador');
  });

  testWidgets('muestra los datos personales en modo lectura',
      (WidgetTester tester) async {
    await _abrir(tester, _PerfilFalso(perfil: _david));

    expect(find.text('Mis datos personales'), findsOneWidget);
    expect(find.text('David Perez'), findsOneWidget);
    expect(find.text('1098765432'), findsOneWidget);
    expect(find.text('david.perez@correo.uis.edu.co'), findsOneWidget);
    expect(find.text('Sin registrar'), findsOneWidget);
    expect(find.text('Usuario'), findsOneWidget);
    expect(find.text('Guardar cambios'), findsNothing);
  });

  testWidgets('actualiza nombre y celular', (WidgetTester tester) async {
    final _PerfilFalso repo = _PerfilFalso(perfil: _david);
    await _abrir(tester, repo);

    await _tocar(tester, 'Actualizar mis datos');
    expect(find.text('Editar mis datos'), findsOneWidget);

    await tester.enterText(_campo('Nombres'), 'David Alejandro ');
    await tester.enterText(_campo('Celular (opcional)'), '3001234567');
    await _tocar(tester, 'Guardar cambios');

    expect(repo.guardados, 1);
    expect(repo.perfil?.nombre, 'David Alejandro');
    expect(repo.perfil?.telefono, '3001234567');
    expect(find.text('Tus datos se actualizaron.'), findsOneWidget);
    expect(find.text('Mis datos personales'), findsOneWidget);
    expect(find.text('David Alejandro Perez'), findsOneWidget);
    expect(find.text('3001234567'), findsOneWidget);
  });

  testWidgets('el documento y el correo no se pueden editar',
      (WidgetTester tester) async {
    await _abrir(tester, _PerfilFalso(perfil: _david));
    await _tocar(tester, 'Actualizar mis datos');

    expect(tester.widget<TextFormField>(_campo('Documento')).enabled, isFalse);
    expect(
      tester.widget<TextFormField>(_campo('Correo institucional')).enabled,
      isFalse,
    );
    expect(tester.widget<TextFormField>(_campo('Nombres')).enabled, isTrue);
  });

  testWidgets('no guarda un celular inválido ni un nombre vacío',
      (WidgetTester tester) async {
    final _PerfilFalso repo = _PerfilFalso(perfil: _david);
    await _abrir(tester, repo);
    await _tocar(tester, 'Actualizar mis datos');

    await tester.enterText(_campo('Nombres'), '  ');
    await tester.enterText(_campo('Celular (opcional)'), '6071234');
    await _tocar(tester, 'Guardar cambios');

    expect(find.text('Escribe tu nombre.'), findsOneWidget);
    expect(find.textContaining('Celular de 10 dígitos'), findsOneWidget);
    expect(repo.guardados, 0);
  });

  testWidgets('sin cambios no va a la base', (WidgetTester tester) async {
    final _PerfilFalso repo = _PerfilFalso(perfil: _david);
    await _abrir(tester, repo);
    await _tocar(tester, 'Actualizar mis datos');

    await _tocar(tester, 'Guardar cambios');

    expect(repo.guardados, 0);
    expect(find.text('Mis datos personales'), findsOneWidget);
  });

  testWidgets('cancelar descarta lo escrito', (WidgetTester tester) async {
    final _PerfilFalso repo = _PerfilFalso(perfil: _david);
    await _abrir(tester, repo);
    await _tocar(tester, 'Actualizar mis datos');

    await tester.enterText(_campo('Nombres'), 'Otro');
    await _tocar(tester, 'Cancelar');

    expect(repo.guardados, 0);
    expect(find.text('David Perez'), findsOneWidget);
    expect(find.text('Otro'), findsNothing);
  });

  testWidgets('si falla al guardar, avisa y se queda editando',
      (WidgetTester tester) async {
    await _abrir(
      tester,
      _PerfilFalso(
        perfil: _david,
        errorAlGuardar: 'No se pudieron guardar tus datos. Revisa tu conexión.',
      ),
    );
    await _tocar(tester, 'Actualizar mis datos');

    await tester.enterText(_campo('Apellidos'), 'Perez Gomez');
    await _tocar(tester, 'Guardar cambios');

    expect(find.textContaining('No se pudieron guardar'), findsOneWidget);
    expect(find.text('Editar mis datos'), findsOneWidget);
  });

  testWidgets('si falla al cargar, ofrece reintentar',
      (WidgetTester tester) async {
    await _abrir(
      tester,
      _PerfilFalso(errorAlCargar: 'No se pudo cargar tu perfil.'),
    );

    expect(find.text('No se pudo cargar tu perfil.'), findsOneWidget);
    expect(find.text('Reintentar'), findsOneWidget);
  });
}
