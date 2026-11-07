import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ufit/core/datos/puertos/repositorio_admin.dart';
import 'package:ufit/core/datos/puertos/repositorio_gimnasio.dart';
import 'package:ufit/core/datos/puertos/repositorio_perfiles.dart';
import 'package:ufit/core/datos/repositorios.dart';
import 'package:ufit/core/modelos/administracion.dart';
import 'package:ufit/core/modelos/franja_con_instructor.dart';
import 'package:ufit/core/modelos/maquina.dart';
import 'package:ufit/core/modelos/medicion.dart';
import 'package:ufit/core/modelos/normativa.dart';
import 'package:ufit/core/modelos/perfil.dart';
import 'package:ufit/core/modelos/sesion.dart';
import 'package:ufit/core/modelos/zona.dart';
import 'package:ufit/core/tema/app_theme.dart';
import 'package:ufit/features/admin/datos/respuestas_admin.dart';
import 'package:ufit/features/admin/pantallas/rf13_gestion_contenidos.dart';
import 'package:ufit/features/admin/reglas_admin.dart';

// ---------------------------------------------------------------------
// Respuestas reales: salen de correr schema.sql y las migraciones 015 y
// 016 en PostgreSQL 16 y pedirlas por PostgREST 12, como las pide la app.
// ---------------------------------------------------------------------

const String _publicada =
    '[{"resultado":"publicada","version":3,'
    '"publicada_en":"2026-11-07T15:45:27.883107+00:00"}]';

const String _versionCambio =
    '[{"resultado":"version_cambio","version":2,'
    '"publicada_en":"2026-11-07T15:37:20.944207+00:00"}]';

const String _ejercicio =
    '{"id":1,"nombre":"Caminata en pendiente","grupo_muscular":"Cardiovascular",'
    '"activo":true,"actualizado_en":"2026-11-07T15:37:21.034866+00:00",'
    '"ejercicio_maquina":[{"maquina_id": 3}, {"maquina_id": 1}]}';

const String _bitacora =
    '{"creada_en":"2026-11-07T15:45:27.909485+00:00","accion":"asignar_turno",'
    '"entidad":"asignaciones_instructor","entidad_id":'
    '"00000000-0000-0000-0000-00000000000d","detalle":{"dias": [1, 2], '
    '"franjas": 8},"perfiles":{"nombre": "Ada", "apellido": "Admin"}}';

// ---------------------------------------------------------------------
// Dobles de prueba
// ---------------------------------------------------------------------

class _AdminFalso implements RepositorioAdmin {

  @override
  Future<List<Maquina>> maquinas() async => const <Maquina>[
        Maquina(id: 1, zonaId: 1, nombre: 'Trotadora', cantidad: 4),
        Maquina(
          id: 2,
          zonaId: 2,
          nombre: 'Banco plano',
          estado: EstadoMaquina.mantenimiento,
        ),
      ];

  @override
  Future<void> guardarMaquina(DatosMaquina datos) async {}

  @override
  Future<RespuestaEliminacion> eliminarMaquina(int id) async =>
      const RespuestaEliminacion(resultado: ResultadoEliminacion.enUso, rutinas: 2);

  @override
  Future<void> cambiarEstadoMaquina(int id, EstadoMaquina estado) async {}

  @override
  Future<List<EjercicioAdmin>> ejercicios() async => const <EjercicioAdmin>[];

  @override
  Future<void> guardarEjercicio(DatosEjercicio datos) async {}

  @override
  Future<RespuestaEliminacion> eliminarEjercicio(int id) async =>
      const RespuestaEliminacion(resultado: ResultadoEliminacion.eliminado);

  @override
  Future<NormativaAdmin?> normativaActual() async => null;

  @override
  Future<RespuestaPublicacion> publicarNormativa({
    required String titulo,
    required String contenido,
    required int versionBase,
  }) async =>
      const RespuestaPublicacion(resultado: ResultadoPublicacion.publicada);

  @override
  Future<int> horasAntelacionCancelar() async => 3;

  @override
  Future<void> guardarHorasAntelacionCancelar(int horas) async {}

  @override
  Future<List<Perfil>> personas() async => const <Perfil>[];

  @override
  Future<ResultadoPersona> actualizarPersona({
    required String perfilId,
    required RolUsuario rol,
    required bool activo,
    String? especialidad,
  }) async =>
      ResultadoPersona.actualizada;

  @override
  Future<int> asignarTurno({
    String? instructorId,
    required List<int> dias,
    required int horaDesde,
    required int horaHasta,
    required DateTime desde,
    required DateTime hasta,
  }) async =>
      0;

  @override
  Future<List<EntradaBitacora>> bitacora({int limite = 100}) async =>
      const <EntradaBitacora>[];
}

class _PerfilFalso implements RepositorioPerfiles {
  _PerfilFalso(this.rol);

  final RolUsuario rol;

  @override
  Future<Perfil?> perfilActual() async => Perfil(
        id: 'yo',
        nombre: 'Ada',
        apellido: 'Admin',
        documento: '100',
        correo: 'admin@uis.edu.co',
        rol: rol,
      );

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
  }) =>
      throw UnimplementedError();

  @override
  Future<void> cerrarSesion() async {}

  @override
  Future<Perfil> actualizarPerfil({
    required String nombre,
    required String apellido,
    String? telefono,
  }) =>
      throw UnimplementedError();

  @override
  Future<List<MedicionAntropometrica>> misMediciones() =>
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
  }) =>
      throw UnimplementedError();

  @override
  Future<void> borrarMedicion(int id) => throw UnimplementedError();
}

class _GimnasioFalso implements RepositorioGimnasio {
  @override
  Future<List<Zona>> zonas() async => const <Zona>[
        Zona(id: 1, nombre: 'Cardiovascular'),
        Zona(id: 2, nombre: 'Fuerza'),
      ];

  @override
  Future<List<Maquina>> maquinas({int? zonaId}) async => const <Maquina>[];

  @override
  Future<Normativa?> normativaVigente() async => null;

  @override
  Future<List<FranjaConInstructor>> agendaInstructores({
    required DateTime desde,
    required DateTime hasta,
  }) async =>
      const <FranjaConInstructor>[];
}

Future<_AdminFalso> _abrir(
  WidgetTester tester,
  Widget pantalla, {
  RolUsuario rol = RolUsuario.administrador,
}) async {
  await tester.binding.setSurfaceSize(const Size(900, 2400));
  addTearDown(() => tester.binding.setSurfaceSize(null));

  final _AdminFalso admin = _AdminFalso();
  Repositorios.admin = admin;
  Repositorios.perfiles = _PerfilFalso(rol);
  Repositorios.gimnasio = _GimnasioFalso();

  await tester.pumpWidget(MaterialApp(theme: AppTheme.claro, home: pantalla));
  await tester.pumpAndSettle();
  return admin;
}

void main() {
  group('respuestas de la base', () {
    test('publicar normativa', () {
      final RespuestaPublicacion p = publicacionDesdeRespuesta(jsonDecode(_publicada));
      expect(p.resultado, ResultadoPublicacion.publicada);
      expect(p.version, 3);
      expect(p.publicadaEn, DateTime(2026, 11, 7, 10, 45, 27));
      expect(publicacionDesdeRespuesta(jsonDecode(_versionCambio)).resultado,
          ResultadoPublicacion.versionCambio);
    });

    test('eliminar', () {
      final RespuestaEliminacion r = eliminacionDesdeRespuesta(
          jsonDecode('[{"resultado":"en_uso","rutinas":2}]'));
      expect(r.resultado, ResultadoEliminacion.enUso);
      expect(r.rutinas, 2);
      expect(eliminacionDesdeRespuesta(null).resultado,
          ResultadoEliminacion.desconocido);
    });

    test('ejercicio con sus máquinas', () {
      final EjercicioAdmin e = ejercicioDesdeFila(
          jsonDecode(_ejercicio) as Map<String, dynamic>);
      expect(e.maquinaIds, <int>[1, 3]);
      expect(e.activo, isTrue);
    });

    test('bitácora', () {
      final EntradaBitacora b =
          entradaDesdeFila(jsonDecode(_bitacora) as Map<String, dynamic>);
      expect(b.persona, 'Ada Admin');
      expect(b.fecha, DateTime(2026, 11, 7, 10, 45, 27));
      expect(accionLegible(b), 'Asignó un turno de instructor');
      expect(b.detalle, contains('"franjas":8'));
    });

    test('roles y resultados en texto', () {
      expect(resultadoPersonaDesdeTexto('propia'), ResultadoPersona.propia);
      expect(rolATexto(RolUsuario.instructor), 'instructor');
      expect(rolDesdeTexto(rolATexto(RolUsuario.administrador)),
          RolUsuario.administrador);
    });
  });

  group('reglas', () {
    test('validación por campo (5c)', () {
      expect(validarNombre(''), isNotNull);
      expect(validarNombre('Remo'), isNull);
      expect(validarCantidad('0'), isNotNull);
      expect(validarCantidad('3'), isNull);
      expect(validarImagenUrl('http://x.com/a.jpg'), isNotNull);
      expect(validarImagenUrl('https://x.com/a.jpg'), isNull);
      expect(validarImagenUrl(''), isNull);
      expect(validarContenidoNormativa('corto'), isNotNull);
    });

    test('rangos y turnos', () {
      expect(validarRangoDeFechas(DateTime(2026, 11, 9), DateTime(2026, 11, 1)),
          isNotNull);
      expect(
          validarRangoDeFechas(DateTime(2026, 11, 1), DateTime(2027, 3, 1),
              maximoDias: 62),
          isNotNull);
      expect(validarTurno(dias: <int>{}, horaDesde: 6, horaHasta: 8), isNotNull);
      expect(validarTurno(dias: <int>{1}, horaDesde: 8, horaHasta: 8), isNotNull);
      expect(validarTurno(dias: <int>{1}, horaDesde: 6, horaHasta: 8), isNull);
    });

    test('mensajes', () {
      expect(
        mensajeDeEliminacion(
          const RespuestaEliminacion(resultado: ResultadoEliminacion.enUso, rutinas: 2),
          que: 'La máquina',
        ),
        contains('usan 2 rutinas'),
      );
      expect(mensajeDePersona(ResultadoPersona.propia), contains('propia'));
    });
  });

  group('pantallas', () {
    testWidgets('un instructor no entra a los contenidos',
        (WidgetTester tester) async {
      await _abrir(
        tester,
        const PantallaGestionContenidos(),
        rol: RolUsuario.instructor,
      );
      expect(find.textContaining('solo para el administrador'), findsOneWidget);
      expect(find.text('Máquinas'), findsNothing);
    });

    testWidgets('máquina en uso: ofrece dejarla fuera de servicio (5a)',
        (WidgetTester tester) async {
      await _abrir(tester, const PantallaGestionContenidos());

      expect(find.text('Trotadora'), findsOneWidget);
      expect(find.textContaining('Fuera de servicio'), findsOneWidget);

      await tester.tap(find.byTooltip('Eliminar Trotadora'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Eliminar'));
      await tester.pumpAndSettle();

      expect(find.text('No se puede eliminar'), findsOneWidget);
      expect(find.textContaining('usan 2 rutinas'), findsOneWidget);
      expect(find.text('Dejar fuera de servicio'), findsOneWidget);
    });
  });
}
