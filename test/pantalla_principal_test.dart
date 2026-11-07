import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ufit/app/pantalla_principal.dart';
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
import 'package:ufit/core/rutas.dart';
import 'package:ufit/core/tema/app_theme.dart';

/// "Ahora": lunes 9 de noviembre de 2026, 9:00 a. m.
final DateTime _ahora = DateTime(2026, 11, 9, 9);

Reserva _reserva(int id, DateTime fecha, EstadoReserva estado,
        {int hora = 10}) =>
    Reserva(
      id: id,
      perfilId: 'yo',
      franjaId: id,
      fecha: fecha,
      zonaId: 1,
      estado: estado,
      codigoQr: 'codigo-$id',
      horaInicio: '$hora:00:00',
      horaFin: '${hora + 1}:00:00',
    );

class _PerfilesFalsos implements RepositorioPerfiles {
  _PerfilesFalsos(this.rol);

  final RolUsuario rol;
  int cierres = 0;

  @override
  Future<Perfil?> perfilActual() async => Perfil(
        id: 'yo',
        nombre: 'Juliana',
        apellido: 'Martínez',
        documento: '2180234',
        correo: 'juliana@correo.uis.edu.co',
        rol: rol,
      );

  @override
  Future<List<MedicionAntropometrica>> misMediciones() async =>
      <MedicionAntropometrica>[
        MedicionAntropometrica(
          id: 1,
          registradaEn: DateTime(2026, 11, 2),
          pesoKg: 58,
          estaturaCm: 165,
        ),
      ];

  @override
  Future<void> cerrarSesion() async => cierres++;

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
  Future<Perfil> actualizarPerfil({
    required String nombre,
    required String apellido,
    String? telefono,
  }) =>
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

class _ReservasFalsas implements RepositorioReservas {
  @override
  Future<List<Reserva>> misReservas({DateTime? desde, DateTime? hasta}) async =>
      <Reserva>[
        _reserva(1, DateTime(2026, 11, 3), EstadoReserva.asistida),
        _reserva(2, DateTime(2026, 11, 5), EstadoReserva.asistida),
        _reserva(3, DateTime(2026, 11, 6), EstadoReserva.cancelada),
        _reserva(4, DateTime(2026, 11, 9), EstadoReserva.confirmada),
        _reserva(5, DateTime(2026, 11, 11), EstadoReserva.confirmada),
      ];

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

  @override
  Future<RespuestaValidacion> validarIngreso(String codigo) =>
      throw UnimplementedError();

  @override
  Future<List<ReservaDeHoy>> reservasDeHoyPorDocumento(String documento) =>
      throw UnimplementedError();

  @override
  Future<RespuestaValidacion> validarIngresoManual(int reservaId) =>
      throw UnimplementedError();
}

class _GimnasioFalso implements RepositorioGimnasio {
  @override
  Future<List<Zona>> zonas() async => const <Zona>[
        Zona(id: 1, nombre: 'Cardiovascular'),
        Zona(id: 2, nombre: 'Fuerza'),
      ];

  @override
  Future<List<Maquina>> maquinas({int? zonaId}) async => const <Maquina>[
        Maquina(id: 1, zonaId: 1, nombre: 'Trotadora', cantidad: 4),
        Maquina(id: 2, zonaId: 2, nombre: 'Banco plano', cantidad: 2),
        Maquina(
          id: 3,
          zonaId: 2,
          nombre: 'Vieja',
          estado: EstadoMaquina.retirada,
        ),
      ];

  @override
  Future<Normativa?> normativaVigente() async => Normativa(
        titulo: 'Normativa',
        contenido: '1. Toalla.\n2. No maletas.\n3. No alimentos.',
        version: 2,
        publicadaEn: DateTime(2026, 10, 13),
      );

  @override
  Future<List<FranjaConInstructor>> agendaInstructores({
    required DateTime desde,
    required DateTime hasta,
  }) async =>
      const <FranjaConInstructor>[];
}

Future<_PerfilesFalsos> _abrir(
  WidgetTester tester, {
  RolUsuario rol = RolUsuario.usuario,
}) async {
  await tester.binding.setSurfaceSize(const Size(420, 1400));
  addTearDown(() => tester.binding.setSurfaceSize(null));

  final _PerfilesFalsos perfiles = _PerfilesFalsos(rol);
  Repositorios.perfiles = perfiles;
  Repositorios.reservas = _ReservasFalsas();
  Repositorios.gimnasio = _GimnasioFalso();

  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.oscuro,
      routes: <String, WidgetBuilder>{
        Rutas.rf11Rutinas: (_) => const Scaffold(body: Text('PANTALLA RF11')),
      },
      home: PantallaPrincipal(reloj: () => _ahora),
    ),
  );
  await tester.pumpAndSettle();
  return perfiles;
}

void main() {
  test('saludo según la hora', () {
    expect(saludo(DateTime(2026, 11, 9, 7)), '¡Buenos días');
    expect(saludo(DateTime(2026, 11, 9, 15)), '¡Buenas tardes');
    expect(saludo(DateTime(2026, 11, 9, 20)), '¡Buenas noches');
  });

  testWidgets('el inicio saluda y cuenta asistencias y reservas activas',
      (WidgetTester tester) async {
    await _abrir(tester);

    expect(find.text('¡Buenos días 👋'), findsOneWidget);
    expect(find.text('Juliana Martínez'), findsOneWidget);
    // Dos asistencias en noviembre y dos reservas que no han terminado.
    expect(find.text('2'), findsNWidgets(2));
    expect(find.text('Reservar cupo'), findsOneWidget);
    expect(find.text('Mis rutinas'), findsOneWidget);
    // Un usuario no ve las opciones del personal ni del administrador.
    expect(find.text('Validar ingresos'), findsNothing);
    expect(find.text('Contenidos'), findsNothing);
  });

  testWidgets('el administrador ve sus atajos', (WidgetTester tester) async {
    await _abrir(tester, rol: RolUsuario.administrador);

    expect(find.text('Validar ingresos'), findsOneWidget);
    expect(find.text('Contenidos'), findsOneWidget);
    expect(find.text('Estadísticas'), findsOneWidget);
  });

  testWidgets('un atajo abre su pantalla', (WidgetTester tester) async {
    await _abrir(tester);

    await tester.tap(find.text('Mis rutinas'));
    await tester.pumpAndSettle();
    expect(find.text('PANTALLA RF11'), findsOneWidget);
  });

  testWidgets('la pestaña Info muestra normativa, inventario y zonas',
      (WidgetTester tester) async {
    await _abrir(tester);

    await tester.tap(find.text('Info'));
    await tester.pumpAndSettle();

    expect(find.text('Gimnasio UIS'), findsOneWidget);
    expect(find.text('3 normas de uso · versión 2'), findsOneWidget);
    // La máquina dada de baja no cuenta.
    expect(find.text('6 equipos registrados'), findsOneWidget);
    expect(find.text('Cardiovascular'), findsOneWidget);
  });

  testWidgets('el perfil muestra las medidas y cierra sesión',
      (WidgetTester tester) async {
    final _PerfilesFalsos perfiles = await _abrir(tester);

    await tester.tap(find.text('Perfil'));
    await tester.pumpAndSettle();

    expect(find.text('Mi perfil'), findsOneWidget);
    expect(find.text('JM'), findsOneWidget);
    expect(find.text('58 kg'), findsOneWidget);
    expect(find.text('1,65 m'), findsOneWidget);
    expect(find.text('21,3'), findsOneWidget);

    await tester.ensureVisible(find.text('Cerrar sesión'));
    await tester.tap(find.text('Cerrar sesión'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cerrar sesión').last);
    await tester.pumpAndSettle();
    expect(perfiles.cierres, 1);
  });
}
