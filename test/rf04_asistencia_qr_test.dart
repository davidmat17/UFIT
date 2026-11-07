import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:ufit/core/datos/errores.dart';
import 'package:ufit/core/datos/puertos/repositorio_gimnasio.dart';
import 'package:ufit/core/datos/puertos/repositorio_perfiles.dart';
import 'package:ufit/core/datos/puertos/repositorio_reservas.dart';
import 'package:ufit/core/datos/repositorios.dart';
import 'package:ufit/core/modelos/franja_con_instructor.dart';
import 'package:ufit/core/modelos/franja_disponible.dart';
import 'package:ufit/core/modelos/maquina.dart';
import 'package:ufit/core/modelos/medicion.dart';
import 'package:ufit/core/modelos/normativa.dart';
import 'package:ufit/core/modelos/perfil.dart';
import 'package:ufit/core/modelos/reserva.dart';
import 'package:ufit/core/modelos/resultado_cancelacion.dart';
import 'package:ufit/core/modelos/resultado_reserva.dart';
import 'package:ufit/core/modelos/sesion.dart';
import 'package:ufit/core/modelos/validacion_ingreso.dart';
import 'package:ufit/core/modelos/zona.dart';
import 'package:ufit/core/tema/app_theme.dart';
import 'package:ufit/features/reservas/datos/respuestas_de_reservas.dart';
import 'package:ufit/features/reservas/pantallas/rf04_asistencia_qr.dart';
import 'package:ufit/features/reservas/reglas_asistencia.dart';

// ---------------------------------------------------------------------
// Datos de prueba
// ---------------------------------------------------------------------

/// "Ahora" en las pruebas: lunes 9 de noviembre de 2026, 9:50 a. m.
final DateTime _ahora = DateTime(2026, 11, 9, 9, 50);

Reserva _reserva({
  int id = 1,
  DateTime? fecha,
  int hora = 10,
  EstadoReserva estado = EstadoReserva.confirmada,
  DateTime? ingresoEn,
}) =>
    Reserva(
      id: id,
      perfilId: 'yo',
      franjaId: 100 + id,
      fecha: fecha ?? DateTime(2026, 11, 9),
      zonaId: 1,
      estado: estado,
      codigoQr: '11111111-1111-1111-1111-11111111111$id',
      horaInicio: '${hora.toString().padLeft(2, '0')}:00:00',
      horaFin: '${(hora + 1).toString().padLeft(2, '0')}:00:00',
      ingresoEn: ingresoEn,
    );

// Respuestas reales: salen de correr schema.sql y la migración 015 en
// PostgreSQL 16 y pedirlas por PostgREST 12, como las pide la app.

const String _filaConAsistencia =
    '{"id":1,"perfil_id":"00000000-0000-0000-0000-00000000000c",'
    '"franja_id":282,"fecha":"2026-11-07","zona_id":1,"estado":"asistida",'
    '"codigo_qr":"11111111-1111-1111-1111-111111111111",'
    '"franjas":{"hora_fin": "11:00:00", "hora_inicio": "10:00:00"},'
    '"asistencias":{"registrada_en": "2026-11-07T15:27:45.695913+00:00"}}';

const String _filaSinAsistencia =
    '{"id":3,"perfil_id":"00000000-0000-0000-0000-00000000000c",'
    '"franja_id":283,"fecha":"2026-11-08","zona_id":1,"estado":"confirmada",'
    '"codigo_qr":"33333333-3333-3333-3333-333333333333",'
    '"franjas":{"hora_fin": "09:00:00", "hora_inicio": "08:00:00"},'
    '"asistencias":null}';

const String _respuestaYaValidado =
    '[{"resultado":"ya_validado","reserva":{"id": 1, "fecha": "2026-11-07", '
    '"estado": "asistida", "zona_id": 1, "codigo_qr": '
    '"11111111-1111-1111-1111-111111111111", "creada_en": '
    '"2026-11-07T15:27:45.689183+00:00", "franja_id": 282, "perfil_id": '
    '"00000000-0000-0000-0000-00000000000c", "cancelada_en": null},'
    '"persona":"Ana Usuaria","documento":"300","hora_inicio":"10:00:00",'
    '"hora_fin":"11:00:00","zona":"Cardiovascular",'
    '"registrada_en":"2026-11-07T15:27:45.695913+00:00"}]';

const String _respuestaInexistente =
    '[{"resultado":"inexistente","reserva":null,"persona":null,'
    '"documento":null,"hora_inicio":null,"hora_fin":null,"zona":null,'
    '"registrada_en":null}]';

const String _respuestaBusqueda =
    '[{"reserva_id":1,"persona":"Ana Usuaria","documento":"300",'
    '"hora_inicio":"10:00:00","hora_fin":"11:00:00","zona":"Cardiovascular",'
    '"estado":"asistida","validada":true}]';

// ---------------------------------------------------------------------
// Dobles de prueba
// ---------------------------------------------------------------------

class _ReservasFalsas implements RepositorioReservas {
  _ReservasFalsas({this.reservas = const <Reserva>[]});

  final List<Reserva> reservas;

  /// Lo que responde la base al validar, por código o por id.
  RespuestaValidacion respuesta = const RespuestaValidacion(
    resultado: ResultadoValidacion.valido,
    persona: 'Ana Usuaria',
    horaInicio: '10:00:00',
    horaFin: '11:00:00',
    zona: 'Cardiovascular',
  );

  /// Si no es null, validar falla con este error.
  ErrorDeDatos? error;

  List<ReservaDeHoy> deHoy = <ReservaDeHoy>[];

  final List<String> codigosValidados = <String>[];
  final List<int> manuales = <int>[];

  @override
  Future<List<Reserva>> misReservas({DateTime? desde, DateTime? hasta}) async =>
      reservas;

  @override
  Future<RespuestaValidacion> validarIngreso(String codigo) async {
    codigosValidados.add(codigo);
    if (error != null) throw error!;
    return respuesta;
  }

  @override
  Future<List<ReservaDeHoy>> reservasDeHoyPorDocumento(String documento) async =>
      deHoy;

  @override
  Future<RespuestaValidacion> validarIngresoManual(int reservaId) async {
    manuales.add(reservaId);
    return respuesta;
  }

  // Lo demás no se usa en estas pruebas.
  @override
  Future<List<FranjaDisponible>> disponibilidad({
    required DateTime desde,
    required DateTime hasta,
  }) =>
      throw UnimplementedError();

  @override
  Future<Reserva> reservar({required int franjaId, required int zonaId}) =>
      throw UnimplementedError();

  @override
  Future<List<ResultadoPorFranja>> reservarFranjas({
    required List<int> franjaIds,
    required int zonaId,
  }) =>
      throw UnimplementedError();

  @override
  Future<RespuestaCancelacion> cancelar(int reservaId) =>
      throw UnimplementedError();

  @override
  Future<int> horasAntelacionCancelar() async => horasAntelacionPorDefecto;
}

class _PerfilFalso implements RepositorioPerfiles {
  _PerfilFalso(this.rol);

  final RolUsuario rol;

  @override
  Future<Perfil?> perfilActual() async => Perfil(
        id: 'yo',
        nombre: 'Ana',
        apellido: 'Usuaria',
        documento: '300',
        correo: 'ana@correo.uis.edu.co',
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

Future<void> _abrir(
  WidgetTester tester, {
  required _ReservasFalsas reservas,
  RolUsuario rol = RolUsuario.usuario,
  String? codigoEscaneado,
}) async {
  await tester.binding.setSurfaceSize(const Size(800, 2000));
  addTearDown(() => tester.binding.setSurfaceSize(null));

  Repositorios.reservas = reservas;
  Repositorios.perfiles = _PerfilFalso(rol);
  Repositorios.gimnasio = _GimnasioFalso();

  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.claro,
      home: PantallaAsistenciaQr(
        reloj: () => _ahora,
        abrirEscaner: (_) async => codigoEscaneado,
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  // -------------------------------------------------------------------
  // Reglas
  // -------------------------------------------------------------------

  group('estado del código', () {
    test('sirve desde 15 minutos antes hasta que termina la franja', () {
      final Reserva r = _reserva(hora: 10);
      expect(estadoDelCodigo(r, DateTime(2026, 11, 9, 9, 44)),
          EstadoDelCodigo.proximo);
      expect(estadoDelCodigo(r, DateTime(2026, 11, 9, 9, 45)),
          EstadoDelCodigo.vigente);
      expect(estadoDelCodigo(r, DateTime(2026, 11, 9, 10, 59)),
          EstadoDelCodigo.vigente);
      expect(estadoDelCodigo(r, DateTime(2026, 11, 9, 11, 0)),
          EstadoDelCodigo.vencido);
    });

    test('usado, cancelado', () {
      expect(
        estadoDelCodigo(_reserva(estado: EstadoReserva.asistida), _ahora),
        EstadoDelCodigo.usado,
      );
      expect(
        estadoDelCodigo(_reserva(estado: EstadoReserva.cancelada), _ahora),
        EstadoDelCodigo.cancelado,
      );
    });

    test('se muestra la de hoy antes que las de otros días', () {
      final Reserva manana = _reserva(id: 2, fecha: DateTime(2026, 11, 10));
      final Reserva hoy = _reserva(id: 1, hora: 18);
      expect(reservaParaElCodigo(<Reserva>[manana, hoy], _ahora)?.id, 1);
    });

    test('si la de hoy ya terminó, muestra la próxima', () {
      final Reserva temprano = _reserva(id: 1, hora: 6);
      final Reserva manana = _reserva(id: 2, fecha: DateTime(2026, 11, 10));
      expect(reservaParaElCodigo(<Reserva>[temprano, manana], _ahora)?.id, 2);
    });

    test('sin reservas no hay código', () {
      expect(reservaParaElCodigo(const <Reserva>[], _ahora), isNull);
    });

    test('las frases explican desde y hasta cuándo', () {
      expect(explicacionDelCodigo(_reserva(hora: 10), _ahora),
          contains('hasta las 11:00 a. m.'));
      expect(explicacionDelCodigo(_reserva(hora: 14), _ahora),
          contains('hoy a las 1:45 p. m.'));
      expect(
        explicacionDelCodigo(
          _reserva(
            estado: EstadoReserva.asistida,
            ingresoEn: DateTime(2026, 11, 9, 9, 52),
          ),
          _ahora,
        ),
        'Ingreso registrado a las 9:52 a. m.',
      );
    });

    test('documento para buscar', () {
      expect(validarDocumentoDeBusqueda(''), isNotNull);
      expect(validarDocumentoDeBusqueda('1.098.765'), isNotNull);
      expect(validarDocumentoDeBusqueda('1098765432'), isNull);
    });
  });

  // -------------------------------------------------------------------
  // Respuestas de la base
  // -------------------------------------------------------------------

  group('respuestas de la base', () {
    test('la reserva trae la hora del ingreso en hora de Colombia', () {
      final Reserva r = reservaDesdeFila(
          jsonDecode(_filaConAsistencia) as Map<String, dynamic>);
      expect(r.estado, EstadoReserva.asistida);
      expect(r.ingresoEn, DateTime(2026, 11, 7, 10, 27, 45));

      final Reserva s = reservaDesdeFila(
          jsonDecode(_filaSinAsistencia) as Map<String, dynamic>);
      expect(s.ingresoEn, isNull);
    });

    test('ya validado, con los datos de la persona', () {
      final RespuestaValidacion v =
          validacionDesdeRespuesta(jsonDecode(_respuestaYaValidado));
      expect(v.resultado, ResultadoValidacion.yaValidado);
      expect(v.esValido, isFalse);
      expect(v.persona, 'Ana Usuaria');
      expect(v.zona, 'Cardiovascular');
      expect(v.reserva?.id, 1);
      expect(v.registradaEn, DateTime(2026, 11, 7, 10, 27, 45));
      expect(v.titulo, 'Código ya validado');
    });

    test('inexistente y respuestas raras nunca son válidas', () {
      expect(validacionDesdeRespuesta(jsonDecode(_respuestaInexistente)).resultado,
          ResultadoValidacion.inexistente);
      expect(validacionDesdeRespuesta(null).esValido, isFalse);
      expect(
        validacionDesdeRespuesta(<dynamic>[
          <String, dynamic>{'resultado': 'otra_cosa'},
        ]).resultado,
        ResultadoValidacion.desconocido,
      );
    });

    test('búsqueda por documento', () {
      final List<ReservaDeHoy> r =
          reservasDeHoyDesdeRespuesta(jsonDecode(_respuestaBusqueda));
      expect(r, hasLength(1));
      expect(r.first.reservaId, 1);
      expect(r.first.validada, isTrue);
      expect(r.first.estado, EstadoReserva.asistida);
      expect(reservasDeHoyDesdeRespuesta(null), isEmpty);
    });
  });

  // -------------------------------------------------------------------
  // Pantalla
  // -------------------------------------------------------------------

  group('pantalla', () {
    testWidgets('el usuario ve el QR activo de su reserva de hoy',
        (WidgetTester tester) async {
      await _abrir(tester, reservas: _ReservasFalsas(reservas: <Reserva>[
        _reserva(hora: 10),
      ]));

      expect(find.byType(QrImageView), findsOneWidget);
      expect(find.text('Activo ahora'), findsOneWidget);
      // Un usuario no ve la pestaña del personal.
      expect(find.text('Validar ingresos'), findsNothing);
    });

    testWidgets('sin reservas lo explica y lleva a reservar',
        (WidgetTester tester) async {
      await _abrir(tester, reservas: _ReservasFalsas());

      expect(find.byType(QrImageView), findsNothing);
      expect(find.text('Reservar un cupo'), findsOneWidget);
    });

    testWidgets('el personal escanea y ve que el ingreso es válido',
        (WidgetTester tester) async {
      final _ReservasFalsas repo = _ReservasFalsas();
      await _abrir(
        tester,
        reservas: repo,
        rol: RolUsuario.instructor,
        codigoEscaneado: '11111111-1111-1111-1111-111111111111',
      );

      await tester.tap(find.text('Validar ingresos'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Escanear código QR'));
      await tester.pumpAndSettle();

      expect(repo.codigosValidados,
          <String>['11111111-1111-1111-1111-111111111111']);
      expect(find.text('Ingreso válido'), findsOneWidget);
      expect(find.text('Ana Usuaria'), findsOneWidget);
    });

    testWidgets('un código ya usado se rechaza (4a)',
        (WidgetTester tester) async {
      final _ReservasFalsas repo = _ReservasFalsas()
        ..respuesta = validacionDesdeRespuesta(jsonDecode(_respuestaYaValidado));
      await _abrir(
        tester,
        reservas: repo,
        rol: RolUsuario.administrador,
        codigoEscaneado: '11111111-1111-1111-1111-111111111111',
      );

      await tester.tap(find.text('Validar ingresos'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Escanear código QR'));
      await tester.pumpAndSettle();

      expect(find.text('Código ya validado'), findsOneWidget);
    });

    testWidgets('validación manual por documento (3a)',
        (WidgetTester tester) async {
      final _ReservasFalsas repo = _ReservasFalsas()
        ..deHoy = <ReservaDeHoy>[
          const ReservaDeHoy(
            reservaId: 7,
            persona: 'Beto Usuario',
            documento: '1098765432',
            horaInicio: '10:00:00',
            horaFin: '11:00:00',
            zona: 'Fuerza',
            estado: EstadoReserva.confirmada,
            validada: false,
          ),
        ];
      await _abrir(tester, reservas: repo, rol: RolUsuario.instructor);

      await tester.tap(find.text('Validar ingresos'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextFormField), '1098765432');
      await tester.tap(find.text('Buscar reserva de hoy'));
      await tester.pumpAndSettle();

      expect(find.text('Beto Usuario'), findsOneWidget);
      await tester.tap(find.text('Validar'));
      await tester.pumpAndSettle();

      expect(repo.manuales, <int>[7]);
      expect(find.text('Ingreso válido'), findsOneWidget);
    });
  });
}
