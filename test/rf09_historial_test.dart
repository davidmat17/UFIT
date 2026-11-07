import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ufit/core/datos/errores.dart';
import 'package:ufit/core/datos/puertos/repositorio_entrenamiento.dart';
import 'package:ufit/core/datos/puertos/repositorio_gimnasio.dart';
import 'package:ufit/core/datos/puertos/repositorio_reservas.dart';
import 'package:ufit/core/datos/repositorios.dart';
import 'package:ufit/core/modelos/franja_con_instructor.dart';
import 'package:ufit/core/modelos/franja_disponible.dart';
import 'package:ufit/core/modelos/maquina.dart';
import 'package:ufit/core/modelos/normativa.dart';
import 'package:ufit/core/modelos/reserva.dart';
import 'package:ufit/core/modelos/resultado_cancelacion.dart';
import 'package:ufit/core/modelos/resultado_reserva.dart';
import 'package:ufit/core/modelos/rutina.dart';
import 'package:ufit/core/modelos/validacion_ingreso.dart';
import 'package:ufit/core/modelos/zona.dart';
import 'package:ufit/core/tema/app_theme.dart';
import 'package:ufit/features/reservas/pantallas/rf09_historial.dart';
import 'package:ufit/features/reservas/reglas_historial.dart';

/// "Ahora" en las pruebas: lunes 9 de noviembre de 2026, 12:00 m.
final DateTime _ahora = DateTime(2026, 11, 9, 12);

Reserva _reserva(
  int id,
  DateTime fecha, {
  int hora = 8,
  EstadoReserva estado = EstadoReserva.confirmada,
  DateTime? ingresoEn,
}) =>
    Reserva(
      id: id,
      perfilId: 'yo',
      franjaId: id,
      fecha: fecha,
      zonaId: 1,
      estado: estado,
      codigoQr: 'codigo-$id',
      horaInicio: '${hora.toString().padLeft(2, '0')}:00:00',
      horaFin: '${(hora + 1).toString().padLeft(2, '0')}:00:00',
      ingresoEn: ingresoEn,
    );

final List<Reserva> _noviembre = <Reserva>[
  // Lunes 2: asistida.
  _reserva(1, DateTime(2026, 11, 2),
      estado: EstadoReserva.asistida, ingresoEn: DateTime(2026, 11, 2, 7, 58)),
  // Miércoles 4: confirmada y ya pasó → no asistida.
  _reserva(2, DateTime(2026, 11, 4)),
  // Viernes 6: cancelada.
  _reserva(3, DateTime(2026, 11, 6), estado: EstadoReserva.cancelada),
  // Miércoles 11: próxima.
  _reserva(4, DateTime(2026, 11, 11)),
];

const Rutina _pierna = Rutina(
  id: 1,
  nombre: 'Pierna',
  ejercicios: <EjercicioDeRutina>[
    EjercicioDeRutina(
      ejercicioId: 1,
      nombreEjercicio: 'Sentadilla',
      dias: <int>[1, 3],
      repeticiones: 12,
    ),
  ],
);

class _ReservasFalsas implements RepositorioReservas {
  _ReservasFalsas(this.reservas, {this.falla = false});

  final List<Reserva> reservas;
  final bool falla;
  final List<(DateTime?, DateTime?)> consultas = <(DateTime?, DateTime?)>[];

  @override
  Future<List<Reserva>> misReservas({DateTime? desde, DateTime? hasta}) async {
    consultas.add((desde, hasta));
    if (falla) {
      throw const ErrorDeDatos(TipoDeError.sinConexion, 'Sin conexión.');
    }
    return reservas
        .where((Reserva r) =>
            (desde == null || !r.fecha.isBefore(desde)) &&
            (hasta == null || !r.fecha.isAfter(hasta)))
        .toList();
  }

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

class _EntrenamientoFalso implements RepositorioEntrenamiento {
  @override
  Future<List<Rutina>> misRutinas() async => const <Rutina>[_pierna];

  @override
  Future<RespuestaCrearRutina> crearRutina({
    required String nombre,
    required List<LineaNuevaRutina> ejercicios,
    required String solicitudId,
  }) =>
      throw UnimplementedError();

  @override
  Future<ResultadoEliminarRutina> eliminarRutina(int rutinaId) =>
      throw UnimplementedError();
}

class _GimnasioFalso implements RepositorioGimnasio {
  @override
  Future<List<Zona>> zonas() async =>
      const <Zona>[Zona(id: 1, nombre: 'Cardiovascular')];

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

Future<_ReservasFalsas> _abrir(
  WidgetTester tester,
  List<Reserva> reservas, {
  bool falla = false,
}) async {
  await tester.binding.setSurfaceSize(const Size(800, 2000));
  addTearDown(() => tester.binding.setSurfaceSize(null));

  final _ReservasFalsas repo = _ReservasFalsas(reservas, falla: falla);
  Repositorios.reservas = repo;
  Repositorios.gimnasio = _GimnasioFalso();
  Repositorios.entrenamiento = _EntrenamientoFalso();

  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.claro,
      home: PantallaHistorial(reloj: () => _ahora),
    ),
  );
  await tester.pumpAndSettle();
  return repo;
}

void main() {
  group('reglas del historial', () {
    test('estado de cada reserva', () {
      expect(estadoEnHistorial(_noviembre[0], _ahora), EstadoEnHistorial.asistida);
      expect(
          estadoEnHistorial(_noviembre[1], _ahora), EstadoEnHistorial.noAsistida);
      expect(
          estadoEnHistorial(_noviembre[2], _ahora), EstadoEnHistorial.cancelada);
      expect(estadoEnHistorial(_noviembre[3], _ahora), EstadoEnHistorial.proxima);
    });

    test('resumen y porcentaje de asistencia', () {
      final ResumenDeHistorial r = resumir(_noviembre, _ahora);
      expect(r.asistidas, 1);
      expect(r.noAsistidas, 1);
      expect(r.canceladas, 1);
      expect(r.proximas, 1);
      // Una de dos reservas pasadas: 50 %.
      expect(r.porcentajeDeAsistencia, 50);
      expect(resumir(const <Reserva>[], _ahora).porcentajeDeAsistencia, isNull);
    });

    test('de la más reciente a la más antigua', () {
      expect(
        ordenarParaHistorial(_noviembre).map((Reserva r) => r.id),
        <int>[4, 3, 2, 1],
      );
    });

    test('el mes completo y sus vecinos', () {
      final RangoDeFechas nov = RangoDeFechas.mes(_ahora);
      expect(nov.desde, DateTime(2026, 11, 1));
      expect(nov.hasta, DateTime(2026, 11, 30));
      expect(nov.esUnMes, isTrue);
      expect(nov.titulo, 'Noviembre de 2026');
      expect(nov.mesAnterior().titulo, 'Octubre de 2026');
      expect(nov.mesSiguiente().hasta, DateTime(2026, 12, 31));
      expect(RangoDeFechas.mes(DateTime(2026, 12, 5)).mesSiguiente().titulo,
          'Enero de 2027');
    });

    test('rangos que no son un mes', () {
      final RangoDeFechas r =
          RangoDeFechas(DateTime(2026, 11, 2), DateTime(2026, 11, 15));
      expect(r.esUnMes, isFalse);
      expect(r.titulo, '2 – 15 de noviembre de 2026');
    });

    test('rango inválido (3a)', () {
      expect(validarRango(DateTime(2026, 11, 10), DateTime(2026, 11, 2)),
          isNotNull);
      expect(validarRango(DateTime(2026, 11, 2), DateTime(2026, 11, 2)), isNull);
    });

    test('rutinas que tocaban ese día', () {
      // Lunes 2 sí (día 1), viernes 6 no, y una cancelada nunca.
      expect(rutinasDelDia(_noviembre[0], const <Rutina>[_pierna]),
          <String>['Pierna']);
      expect(
          rutinasDelDia(
              _reserva(9, DateTime(2026, 11, 6)), const <Rutina>[_pierna]),
          isEmpty);
      expect(rutinasDelDia(_noviembre[2], const <Rutina>[_pierna]), isEmpty);
    });
  });

  group('pantalla', () {
    testWidgets('muestra el mes en curso con estados y resumen',
        (WidgetTester tester) async {
      final _ReservasFalsas repo = await _abrir(tester, _noviembre);

      expect(repo.consultas.first,
          (DateTime(2026, 11, 1), DateTime(2026, 11, 30)));
      expect(find.text('Noviembre de 2026'), findsOneWidget);
      expect(find.text('Asististe al 50 % de tus reservas'), findsOneWidget);
      expect(find.text('Asistida'), findsOneWidget);
      expect(find.text('No asistida'), findsOneWidget);
      expect(find.text('Cancelada'), findsOneWidget);
      expect(find.text('Próxima'), findsOneWidget);
      expect(find.text('Ingreso a las 7:58 a. m.'), findsOneWidget);
      expect(find.text('Rutina: Pierna'), findsWidgets);
    });

    testWidgets('sin registros lo explica (2b)', (WidgetTester tester) async {
      await _abrir(tester, const <Reserva>[]);
      expect(find.text('No tienes reservas en este periodo.'), findsOneWidget);
    });

    testWidgets('pasa al mes anterior (2a)', (WidgetTester tester) async {
      final _ReservasFalsas repo = await _abrir(tester, _noviembre);

      await tester.tap(find.byTooltip('Mes anterior'));
      await tester.pumpAndSettle();

      expect(find.text('Octubre de 2026'), findsOneWidget);
      expect(repo.consultas.last,
          (DateTime(2026, 10, 1), DateTime(2026, 10, 31)));
      expect(find.text('No tienes reservas en este periodo.'), findsOneWidget);
    });

    testWidgets('si falla la consulta, ofrece reintentar',
        (WidgetTester tester) async {
      await _abrir(tester, _noviembre, falla: true);
      expect(find.text('Sin conexión.'), findsOneWidget);
      expect(find.text('Reintentar'), findsOneWidget);
    });
  });
}
