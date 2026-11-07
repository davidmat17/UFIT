import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ufit/core/datos/errores.dart';
import 'package:ufit/core/datos/puertos/repositorio_admin.dart';
import 'package:ufit/core/datos/puertos/repositorio_gimnasio.dart';
import 'package:ufit/core/datos/puertos/repositorio_perfiles.dart';
import 'package:ufit/core/datos/repositorios.dart';
import 'package:ufit/core/modelos/administracion.dart';
import 'package:ufit/core/modelos/estadisticas.dart';
import 'package:ufit/core/modelos/franja_con_instructor.dart';
import 'package:ufit/core/modelos/maquina.dart';
import 'package:ufit/core/modelos/medicion.dart';
import 'package:ufit/core/modelos/normativa.dart';
import 'package:ufit/core/modelos/perfil.dart';
import 'package:ufit/core/modelos/sesion.dart';
import 'package:ufit/core/modelos/zona.dart';
import 'package:ufit/core/tema/app_theme.dart';
import 'package:ufit/features/admin/datos/respuestas_admin.dart';
import 'package:ufit/features/admin/pantallas/rf12_estadisticas.dart';
import 'package:ufit/features/admin/reglas_admin.dart';

// ---------------------------------------------------------------------
// Respuestas reales: salen de correr schema.sql y las migraciones 015 a
// 017 en PostgreSQL 16 y pedirlas por PostgREST 12, como las pide la app.
// ---------------------------------------------------------------------

const String _estadisticas =
    '{"desde": "2026-11-02", "hasta": "2026-11-03", "por_dia": [{"dia": 1, '
    '"franjas": 1, "reservas": 2, "asistidas": 1, "ocupacion": 2.7}, {"dia": '
    '2, "franjas": 1, "reservas": 2, "asistidas": 1, "ocupacion": 2.7}], '
    '"resumen": {"franjas": 2, "reservas": 4, "asistidas": 2, "canceladas": '
    '0, "pendientes": 0, "no_asistidas": 2, "ocupacion_promedio": 2.7}, '
    '"maquinas": [{"zona": "Cardiovascular", "zona_id": 1, "disponibles": 22, '
    '"fuera_de_servicio": 0}], "por_hora": [{"hora": "06:00", "franjas": 2, '
    '"reservas": 4, "asistidas": 2, "ocupacion": 2.7}], "por_zona": [{"zona": '
    '"Fuerza", "zona_id": 2, "reservas": 2, "asistidas": 1, "canceladas": 0, '
    '"no_asistidas": 1}], "permitido": true}';

// ---------------------------------------------------------------------
// Dobles de prueba
// ---------------------------------------------------------------------

class _AdminFalso implements RepositorioAdmin {
  _AdminFalso({this.datos});

  EstadisticasDeUso? datos;
  final List<(DateTime, DateTime, int?, String?)> consultas =
      <(DateTime, DateTime, int?, String?)>[];

  @override
  Future<EstadisticasDeUso> estadisticas({
    required DateTime desde,
    required DateTime hasta,
    int? zonaId,
    String? hora,
  }) async {
    consultas.add((desde, hasta, zonaId, hora));
    final EstadisticasDeUso? d = datos;
    if (d == null) {
      throw const ErrorDeDatos(TipoDeError.sinPermiso, 'Sin permiso.');
    }
    return d;
  }

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

EstadisticasDeUso _leerEstadisticas() => estadisticasDesdeRespuesta(
      jsonDecode(_estadisticas),
      desde: DateTime(2026, 11, 2),
      hasta: DateTime(2026, 11, 3),
    )!;

Future<_AdminFalso> _abrir(
  WidgetTester tester,
  Widget pantalla, {
  RolUsuario rol = RolUsuario.administrador,
  EstadisticasDeUso? datos,
}) async {
  await tester.binding.setSurfaceSize(const Size(900, 2400));
  addTearDown(() => tester.binding.setSurfaceSize(null));

  final _AdminFalso admin = _AdminFalso(datos: datos);
  Repositorios.admin = admin;
  Repositorios.perfiles = _PerfilFalso(rol);
  Repositorios.gimnasio = _GimnasioFalso();

  await tester.pumpWidget(MaterialApp(theme: AppTheme.claro, home: pantalla));
  await tester.pumpAndSettle();
  return admin;
}

void main() {
  group('respuestas de la base', () {
    test('estadísticas', () {
      final EstadisticasDeUso e = _leerEstadisticas();
      expect(e.resumen.reservas, 4);
      expect(e.resumen.asistidas, 2);
      expect(e.resumen.noAsistidas, 2);
      expect(e.resumen.asistenciaEfectiva, 50);
      expect(e.resumen.ocupacionPromedio, 2.7);
      expect(e.porHora.single.etiqueta, '06:00');
      expect(e.porDia.map((UsoPorGrupo g) => g.etiqueta),
          <String>['Lunes', 'Martes']);
      expect(e.porZona.single.noAsistidas, 1);
      expect(e.inventario.single.disponibles, 22);
    });

    test('sin permiso no hay estadísticas', () {
      expect(
        estadisticasDesdeRespuesta(<String, dynamic>{'permitido': false},
            desde: DateTime(2026), hasta: DateTime(2026)),
        isNull,
      );
    });

  });

  group('reglas', () {
    test('porcentajes y extremos', () {
      expect(porcentaje(50), '50 %');
      expect(porcentaje(2.76), '2,8 %');
      expect(porcentaje(null), '—');

      final ({UsoPorGrupo mayor, UsoPorGrupo menor})? x = extremosDeOcupacion(
        const <UsoPorGrupo>[
          UsoPorGrupo(etiqueta: '06:00', reservas: 9, asistidas: 5, franjas: 5, ocupacion: 12),
          UsoPorGrupo(etiqueta: '07:00', reservas: 0, asistidas: 0, franjas: 5, ocupacion: 0),
          UsoPorGrupo(etiqueta: '18:00', reservas: 30, asistidas: 20, franjas: 5, ocupacion: 40),
          // Sin franjas: no cuenta.
          UsoPorGrupo(etiqueta: '19:00', reservas: 0, asistidas: 0),
        ],
      );
      expect(x?.mayor.etiqueta, '18:00');
      expect(x?.menor.etiqueta, '07:00');
      expect(extremosDeOcupacion(const <UsoPorGrupo>[]), isNull);
    });

    test('el reporte CSV trae los indicadores', () {
      final String csv = reporteCsv(_leerEstadisticas());
      expect(csv, contains('Asistencia efectiva;50 %'));
      expect(csv, contains('06:00;2;4;2;2,7 %'));
      expect(csv, contains('Fuerza;2;1;1;0'));
    });

  });

  group('pantallas', () {
    testWidgets('estadísticas del mes en curso', (WidgetTester tester) async {
      final _AdminFalso admin = await _abrir(
        tester,
        PantallaEstadisticas(reloj: () => DateTime(2026, 11, 9, 10)),
        datos: _leerEstadisticas(),
      );

      expect(admin.consultas.first.$1, DateTime(2026, 11, 1));
      expect(admin.consultas.first.$2, DateTime(2026, 11, 30));
      expect(find.text('Asistencia efectiva'), findsOneWidget);
      expect(find.text('50 %'), findsWidgets);
      expect(find.textContaining('Hora de mayor ocupación: 06:00'), findsOneWidget);
      expect(find.text('Fuerza'), findsWidgets);
    });

    testWidgets('sin datos lo dice en vez de graficar (4b)',
        (WidgetTester tester) async {
      await _abrir(
        tester,
        PantallaEstadisticas(reloj: () => DateTime(2026, 11, 9, 10)),
        datos: EstadisticasDeUso(
          desde: DateTime(2026, 11, 1),
          hasta: DateTime(2026, 11, 30),
          resumen: const ResumenDeUso(
            franjas: 200,
            reservas: 0,
            asistidas: 0,
            noAsistidas: 0,
            pendientes: 0,
            canceladas: 0,
          ),
        ),
      );
      expect(find.textContaining('No hay reservas en ese periodo'), findsOneWidget);
      expect(find.text('Ocupación por hora'), findsNothing);
    });

    testWidgets('un usuario no entra a las estadísticas (1a)',
        (WidgetTester tester) async {
      final _AdminFalso admin = await _abrir(
        tester,
        const PantallaEstadisticas(),
        rol: RolUsuario.usuario,
      );
      expect(find.textContaining('solo para el administrador'), findsOneWidget);
      expect(admin.consultas, isEmpty);
    });

  });
}
