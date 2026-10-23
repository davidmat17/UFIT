import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ufit/core/datos/errores.dart';
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
import 'package:ufit/core/modelos/zona.dart';
import 'package:ufit/core/rutas.dart';
import 'package:ufit/core/tema/app_theme.dart';
import 'package:ufit/features/reservas/datos/respuestas_de_reservas.dart';
import 'package:ufit/features/reservas/pantallas/rf03_cancelar_reserva.dart';
import 'package:ufit/features/reservas/reglas_cancelacion.dart';
import 'package:ufit/features/reservas/reglas_reservas.dart';

// ---------------------------------------------------------------------
// Datos de prueba
// ---------------------------------------------------------------------

/// "Ahora" en las pruebas: miércoles 21 de octubre de 2026, 9:30 a. m.
final DateTime _ahoraDePrueba = DateTime(2026, 10, 21, 9, 30);

Reserva _reserva({
  required int id,
  required DateTime fecha,
  required int hora,
  int zonaId = 1,
  EstadoReserva estado = EstadoReserva.confirmada,
  bool conHora = true,
}) {
  String dosDigitos(int n) => n.toString().padLeft(2, '0');
  return Reserva(
    id: id,
    perfilId: 'yo',
    franjaId: fecha.day * 100 + hora,
    fecha: fecha,
    zonaId: zonaId,
    estado: estado,
    // Con este formato, el código corto de la reserva 7 es "00000007".
    codigoQr: '${id.toString().padLeft(8, '0')}-0000-4000-8000-000000000000',
    horaInicio: conHora ? '${dosDigitos(hora)}:00:00' : null,
    horaFin: conHora ? '${dosDigitos(hora + 1)}:00:00' : null,
  );
}

/// Hoy a las 12:00 (faltan 2 h 30 min: ya no se puede), el viernes 23 a
/// las 8:00 y el lunes 26 a las 7:00 (se pueden), y una cancelada el
/// martes 27 que no debe aparecer.
List<Reserva> _reservasDePrueba() => <Reserva>[
      _reserva(id: 4, fecha: DateTime(2026, 10, 26), hora: 7, zonaId: 3),
      _reserva(id: 2, fecha: DateTime(2026, 10, 21), hora: 12),
      _reserva(id: 3, fecha: DateTime(2026, 10, 23), hora: 8, zonaId: 2),
      _reserva(
        id: 5,
        fecha: DateTime(2026, 10, 27),
        hora: 9,
        estado: EstadoReserva.cancelada,
      ),
    ];

/// Repositorio de reservas falso. Cancela con las mismas reglas que la
/// función cancelar_reserva() de la base (supabase/schema.sql), en el
/// mismo orden: inexistente, ya cancelada, ya asistida, fuera de plazo y,
/// si nada lo impide, cancelada.
class _ReservasFalsas implements RepositorioReservas {
  _ReservasFalsas({List<Reserva>? reservas, this.horas = 3})
      : reservas = List<Reserva>.of(reservas ?? <Reserva>[]);

  final List<Reserva> reservas;
  int horas;

  /// Si es true, misReservas() falla.
  bool fallaLaConsulta = false;

  /// Si es true, cancelar() falla como cuando no hay conexión.
  bool fallaCancelar = false;

  /// Los ids que se pidieron cancelar, en orden.
  final List<int> cancelaciones = <int>[];

  /// Otra sesión (otro celular) cancela la reserva sin que esta pantalla
  /// se entere (CU03, 4c).
  void cancelarDesdeOtroDispositivo(int id) {
    final int i = reservas.indexWhere((Reserva r) => r.id == id);
    reservas[i] = _conEstado(reservas[i], EstadoReserva.cancelada);
  }

  Reserva _conEstado(Reserva r, EstadoReserva estado) => Reserva(
        id: r.id,
        perfilId: r.perfilId,
        franjaId: r.franjaId,
        fecha: r.fecha,
        zonaId: r.zonaId,
        estado: estado,
        codigoQr: r.codigoQr,
        horaInicio: r.horaInicio,
        horaFin: r.horaFin,
      );

  @override
  Future<List<Reserva>> misReservas({DateTime? desde, DateTime? hasta}) async {
    if (fallaLaConsulta) {
      throw const ErrorDeDatos(
        TipoDeError.sinConexion,
        'No se pudieron cargar tus reservas. '
        'Revisa tu conexión a internet e inténtalo de nuevo.',
      );
    }
    return reservas
        .where((Reserva r) =>
            (desde == null || !r.fecha.isBefore(soloFecha(desde))) &&
            (hasta == null || !r.fecha.isAfter(soloFecha(hasta))))
        .toList();
  }

  @override
  Future<int> horasAntelacionCancelar() async => horas;

  @override
  Future<RespuestaCancelacion> cancelar(int reservaId) async {
    cancelaciones.add(reservaId);
    if (fallaCancelar) {
      throw const ErrorDeDatos(
        TipoDeError.sinConexion,
        'No se pudo cancelar la reserva. '
        'Revisa tu conexión a internet e inténtalo de nuevo.',
      );
    }

    RespuestaCancelacion con(ResultadoCancelacion r, [Reserva? reserva]) =>
        RespuestaCancelacion(resultado: r, reserva: reserva, horasAntelacion: horas);

    final int i = reservas.indexWhere((Reserva r) => r.id == reservaId);
    if (i < 0) return con(ResultadoCancelacion.inexistente);

    final Reserva r = reservas[i];
    if (r.estado == EstadoReserva.cancelada) {
      return con(ResultadoCancelacion.yaCancelada, r);
    }
    if (r.estado == EstadoReserva.asistida) {
      return con(ResultadoCancelacion.yaAsistida, r);
    }
    final DateTime? limite = limiteParaCancelar(r, horas);
    if (r.estado != EstadoReserva.confirmada ||
        (limite != null && _ahoraDePrueba.isAfter(limite))) {
      return con(ResultadoCancelacion.fueraDePlazo, r);
    }

    reservas[i] = _conEstado(r, EstadoReserva.cancelada);
    return con(ResultadoCancelacion.cancelada, reservas[i]);
  }

  // Lo que no es del RF3 no se usa en estas pruebas.
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
  Future<Reserva> registrarAsistencia(String codigoQr) =>
      throw UnimplementedError();
}

class _GimnasioFalso implements RepositorioGimnasio {
  @override
  Future<List<Zona>> zonas() async => const <Zona>[
        Zona(id: 1, nombre: 'Cardiovascular', descripcion: ''),
        Zona(id: 2, nombre: 'Fuerza', descripcion: ''),
        Zona(id: 3, nombre: 'Musculación', descripcion: ''),
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

// ---------------------------------------------------------------------
// Respuestas reales
//
// Salen de correr supabase/schema.sql y la migración 012 en un Postgres
// de verdad y pedirlas a través de PostgREST, como las pide la app.
// ---------------------------------------------------------------------

const String _respuestaCancelada =
    '[{"resultado":"cancelada","reserva":{"id": 5, "fecha": "2026-10-29", '
    '"estado": "cancelada", "zona_id": 1, "codigo_qr": '
    '"bd6d57f3-a75b-419e-98d8-ebadaa0703cd", "creada_en": '
    '"2026-10-23T10:09:35.232917-05:00", "franja_id": 59, "perfil_id": '
    '"00000000-0000-0000-0000-000000000001", "cancelada_en": '
    '"2026-10-23T10:09:55.695825-05:00"},"horas_antelacion":1}]';

const String _respuestaYaCancelada =
    '[{"resultado":"ya_cancelada","reserva":{"id": 5, "fecha": "2026-10-29", '
    '"estado": "cancelada", "zona_id": 1, "codigo_qr": '
    '"bd6d57f3-a75b-419e-98d8-ebadaa0703cd", "creada_en": '
    '"2026-10-23T10:09:35.232917-05:00", "franja_id": 59, "perfil_id": '
    '"00000000-0000-0000-0000-000000000001", "cancelada_en": '
    '"2026-10-23T10:09:55.695825-05:00"},"horas_antelacion":1}]';

const String _respuestaInexistente =
    '[{"resultado":"inexistente","reserva":null,"horas_antelacion":3}]';

/// Una fila de misReservas, con la franja embebida.
const String _filaConFranja =
    '{"id":4,"perfil_id":"00000000-0000-0000-0000-000000000001",'
    '"franja_id":45,"fecha":"2026-10-28","zona_id":1,"estado":"confirmada",'
    '"codigo_qr":"9a68cf62-fbaa-4db6-8f1a-deb67d2b7eae",'
    '"franjas":{"hora_fin": "09:00:00", "hora_inicio": "08:00:00"}}';

// ---------------------------------------------------------------------
// Ayudas para las pruebas de pantalla
// ---------------------------------------------------------------------

Future<void> _abrir(
  WidgetTester tester,
  _ReservasFalsas repo, {
  Map<String, WidgetBuilder> rutas = const <String, WidgetBuilder>{},
}) async {
  await tester.binding.setSurfaceSize(const Size(800, 2000));
  addTearDown(() => tester.binding.setSurfaceSize(null));

  Repositorios.reservas = repo;
  Repositorios.gimnasio = _GimnasioFalso();

  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.claro,
      routes: rutas,
      home: PantallaCancelarReserva(reloj: () => _ahoraDePrueba),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _tocar(WidgetTester tester, Finder finder) async {
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

/// La tarjeta cuyo título contiene [titulo].
Finder _tarjeta(String titulo) => find.ancestor(
      of: find.textContaining(titulo),
      matching: find.byType(Card),
    );

/// El botón de cancelar de esa tarjeta. Se busca por la clase base porque
/// OutlinedButton.icon construye una subclase privada.
Finder _botonDe(String titulo) => find.descendant(
      of: _tarjeta(titulo),
      matching: find.byWidgetPredicate((Widget w) => w is ButtonStyleButton),
    );

bool _activo(WidgetTester tester, String titulo) =>
    tester.widget<ButtonStyleButton>(_botonDe(titulo)).enabled;

void main() {
  group('plazo para cancelar', () {
    final Reserva viernes8 =
        _reserva(id: 1, fecha: DateTime(2026, 10, 23), hora: 8);

    test('el límite es la hora de inicio menos las horas de antelación', () {
      expect(inicioDeReserva(viernes8), DateTime(2026, 10, 23, 8));
      expect(limiteParaCancelar(viernes8, 3), DateTime(2026, 10, 23, 5));
      expect(limiteParaCancelar(viernes8, 1), DateTime(2026, 10, 23, 7));
    });

    test('se puede justo en el límite y ya no un minuto después', () {
      expect(
        estadoDeCancelacion(viernes8, ahora: DateTime(2026, 10, 23, 5), horas: 3),
        EstadoDeCancelacion.sePuede,
      );
      expect(
        estadoDeCancelacion(viernes8,
            ahora: DateTime(2026, 10, 23, 5, 1), horas: 3),
        EstadoDeCancelacion.fueraDePlazo,
      );
    });

    test('el plazo lo pone la configuración', () {
      final DateTime seisYMedia = DateTime(2026, 10, 23, 6, 30);
      expect(
        estadoDeCancelacion(viernes8, ahora: seisYMedia, horas: 3),
        EstadoDeCancelacion.fueraDePlazo,
      );
      expect(
        estadoDeCancelacion(viernes8, ahora: seisYMedia, horas: 1),
        EstadoDeCancelacion.sePuede,
      );
    });

    test('con el ingreso registrado no se puede, aunque falte mucho', () {
      final Reserva asistida = _reserva(
        id: 1,
        fecha: DateTime(2026, 10, 23),
        hora: 8,
        estado: EstadoReserva.asistida,
      );
      expect(
        estadoDeCancelacion(asistida, ahora: _ahoraDePrueba, horas: 3),
        EstadoDeCancelacion.yaAsistida,
      );
    });

    test('sin la hora de la franja decide la base', () {
      final Reserva sinHora = _reserva(
        id: 1,
        fecha: DateTime(2026, 10, 21),
        hora: 10,
        conHora: false,
      );
      expect(limiteParaCancelar(sinHora, 3), isNull);
      expect(
        estadoDeCancelacion(sinHora, ahora: _ahoraDePrueba, horas: 3),
        EstadoDeCancelacion.sePuede,
      );
    });
  });

  group('lista de reservas activas', () {
    test('solo confirmadas o asistidas que no han terminado, en orden', () {
      final List<Reserva> lista = <Reserva>[
        ..._reservasDePrueba(),
        // Hoy a las 8: ya terminó.
        _reserva(id: 6, fecha: DateTime(2026, 10, 21), hora: 8),
        // Hoy a las 9, en curso y con ingreso: sí se muestra.
        _reserva(
          id: 7,
          fecha: DateTime(2026, 10, 21),
          hora: 9,
          estado: EstadoReserva.asistida,
        ),
        _reserva(
          id: 8,
          fecha: DateTime(2026, 10, 28),
          hora: 9,
          estado: EstadoReserva.noAsistida,
        ),
      ];

      expect(
        reservasActivas(lista, _ahoraDePrueba).map((Reserva r) => r.id),
        <int>[7, 2, 3, 4],
      );
    });
  });

  group('textos', () {
    test('dice la hora como en Colombia', () {
      expect(horaDelReloj(DateTime(2026, 1, 1, 5)), '5:00 a. m.');
      expect(horaDelReloj(DateTime(2026, 1, 1, 0, 30)), '12:30 a. m.');
      expect(horaDelReloj(DateTime(2026, 1, 1, 12)), '12:00 p. m.');
      expect(horaDelReloj(DateTime(2026, 1, 1, 17, 5)), '5:05 p. m.');
    });

    test('explica hasta cuándo se puede cancelar o por qué no', () {
      final List<Reserva> r = _reservasDePrueba();
      String explicar(int id, {int horas = 3}) => explicacionDeCancelacion(
            r.firstWhere((Reserva x) => x.id == id),
            ahora: _ahoraDePrueba,
            horas: horas,
          );

      expect(
        explicar(3),
        'Puedes cancelarla hasta el viernes 23 de octubre a las 5:00 a. m.',
      );
      expect(
        explicar(2),
        'Ya no se puede cancelar: faltan menos de 3 horas para que empiece.',
      );
      expect(explicar(2, horas: 1), 'Puedes cancelarla hasta hoy a las 11:00 a. m.');
      expect(
        explicar(2, horas: 3).contains('3 horas'),
        isTrue,
      );
      expect(textoDeHoras(1), '1 hora');
    });

    test('el mensaje de fuera de plazo usa el plazo que dio la base', () {
      const RespuestaCancelacion r = RespuestaCancelacion(
        resultado: ResultadoCancelacion.fueraDePlazo,
        horasAntelacion: 1,
      );
      expect(r.mensaje, contains('hasta 1 hora antes'));
      expect(r.fueCancelada, isFalse);
    });
  });

  group('lo que responde la base', () {
    test('lee una cancelación', () {
      final RespuestaCancelacion r =
          cancelacionDesdeRespuesta(jsonDecode(_respuestaCancelada));
      expect(r.resultado, ResultadoCancelacion.cancelada);
      expect(r.fueCancelada, isTrue);
      expect(r.horasAntelacion, 1);
      expect(r.reserva?.id, 5);
      expect(r.reserva?.estado, EstadoReserva.cancelada);
    });

    test('cancelar dos veces responde ya_cancelada, sin error', () {
      final RespuestaCancelacion r =
          cancelacionDesdeRespuesta(jsonDecode(_respuestaYaCancelada));
      expect(r.resultado, ResultadoCancelacion.yaCancelada);
      expect(r.fueCancelada, isFalse);
    });

    test('inexistente no trae reserva', () {
      final RespuestaCancelacion r =
          cancelacionDesdeRespuesta(jsonDecode(_respuestaInexistente));
      expect(r.resultado, ResultadoCancelacion.inexistente);
      expect(r.reserva, isNull);
      expect(r.horasAntelacion, 3);
    });

    test('lo que no se entiende es un fallo, nunca un éxito', () {
      for (final Object? datos in <Object?>[
        null,
        <Object?>[],
        'texto',
        <Object?>[
          <String, Object?>{'resultado': 'otra_cosa'},
        ],
      ]) {
        final RespuestaCancelacion r = cancelacionDesdeRespuesta(datos);
        expect(r.resultado, ResultadoCancelacion.desconocido);
        expect(r.fueCancelada, isFalse);
        expect(r.horasAntelacion, horasAntelacionPorDefecto);
      }
    });

    test('lee la hora de la franja cuando viene embebida', () {
      final Reserva r = reservaDesdeFila(
          jsonDecode(_filaConFranja) as Map<String, dynamic>);
      expect(r.horaInicio, '08:00:00');
      expect(r.horaFin, '09:00:00');
      expect(limiteParaCancelar(r, 3), DateTime(2026, 10, 28, 5));

      final Map<String, dynamic> sinFranja =
          jsonDecode(_filaConFranja) as Map<String, dynamic>
            ..remove('franjas');
      expect(reservaDesdeFila(sinFranja).horaInicio, isNull);
    });
  });

  group('pantalla del RF3', () {
    testWidgets('muestra las reservas activas con lo que se puede hacer',
        (WidgetTester tester) async {
      await _abrir(tester, _ReservasFalsas(reservas: _reservasDePrueba()));

      expect(find.text('Mis reservas'), findsOneWidget);
      expect(
        find.textContaining('hasta 3 horas antes de que empiece'),
        findsOneWidget,
      );

      expect(find.text('Hoy · Miércoles 21 de octubre'), findsOneWidget);
      expect(find.text('Viernes 23 de octubre'), findsOneWidget);
      expect(find.text('Lunes 26 de octubre'), findsOneWidget);
      // La cancelada no aparece.
      expect(find.textContaining('27 de octubre'), findsNothing);

      expect(find.text('08:00 – 09:00'), findsOneWidget);
      expect(find.text('Fuerza · código 00000003'), findsOneWidget);

      // Hoy a las 12 ya no se puede (faltan 2 h 30 min); las demás sí.
      expect(_activo(tester, 'Miércoles 21'), isFalse);
      expect(
        find.text(
            'Ya no se puede cancelar: faltan menos de 3 horas para que empiece.'),
        findsOneWidget,
      );
      expect(_activo(tester, 'Viernes 23'), isTrue);
      expect(_activo(tester, 'Lunes 26'), isTrue);

      // El orden es por fecha: hoy, viernes, lunes.
      final double yHoy = tester.getTopLeft(find.textContaining('Miércoles 21')).dy;
      final double yViernes = tester.getTopLeft(find.text('Viernes 23 de octubre')).dy;
      final double yLunes = tester.getTopLeft(find.text('Lunes 26 de octubre')).dy;
      expect(yHoy < yViernes && yViernes < yLunes, isTrue);
    });

    testWidgets('si no confirma, no cambia nada (5a)',
        (WidgetTester tester) async {
      final _ReservasFalsas repo = _ReservasFalsas(reservas: _reservasDePrueba());
      await _abrir(tester, repo);

      await _tocar(tester, _botonDe('Viernes 23'));
      expect(find.text('¿Cancelar esta reserva?'), findsOneWidget);
      expect(
        find.textContaining('Viernes 23 de octubre, 08:00 – 09:00 · Fuerza'),
        findsOneWidget,
      );

      await _tocar(tester, find.text('No, conservarla'));

      expect(find.text('¿Cancelar esta reserva?'), findsNothing);
      expect(repo.cancelaciones, isEmpty);
      expect(find.text('Viernes 23 de octubre'), findsOneWidget);
    });

    testWidgets('al confirmar cancela, avisa y la quita de la lista',
        (WidgetTester tester) async {
      final _ReservasFalsas repo = _ReservasFalsas(reservas: _reservasDePrueba());
      await _abrir(tester, repo);

      await _tocar(tester, _botonDe('Viernes 23'));
      await _tocar(tester, find.text('Sí, cancelar'));

      expect(repo.cancelaciones, <int>[3]);
      expect(
        find.text('Reserva cancelada. El cupo quedó libre para otra persona.'),
        findsOneWidget,
      );
      expect(find.text('Viernes 23 de octubre'), findsNothing);
      expect(find.text('Lunes 26 de octubre'), findsOneWidget);
    });

    testWidgets('si ya se canceló en otro dispositivo, lo dice y refresca (4c)',
        (WidgetTester tester) async {
      final _ReservasFalsas repo = _ReservasFalsas(reservas: _reservasDePrueba());
      await _abrir(tester, repo);

      repo.cancelarDesdeOtroDispositivo(4);
      expect(find.text('Lunes 26 de octubre'), findsOneWidget);

      await _tocar(tester, _botonDe('Lunes 26'));
      await _tocar(tester, find.text('Sí, cancelar'));

      expect(
        find.text('Esta reserva ya estaba cancelada. Actualizamos tu lista.'),
        findsOneWidget,
      );
      expect(find.text('Lunes 26 de octubre'), findsNothing);
    });

    testWidgets('con el ingreso registrado no ofrece cancelar (4b)',
        (WidgetTester tester) async {
      await _abrir(
        tester,
        _ReservasFalsas(reservas: <Reserva>[
          _reserva(
            id: 9,
            fecha: DateTime(2026, 10, 21),
            hora: 9,
            estado: EstadoReserva.asistida,
          ),
        ]),
      );

      expect(find.text('Hoy · Miércoles 21 de octubre'), findsOneWidget);
      expect(
        find.text('Ya registraste el ingreso: esta reserva no se puede cancelar.'),
        findsOneWidget,
      );
      expect(_botonDe('Miércoles 21'), findsNothing);
    });

    testWidgets('respeta el plazo que configura el administrador',
        (WidgetTester tester) async {
      await _abrir(
        tester,
        _ReservasFalsas(reservas: _reservasDePrueba(), horas: 1),
      );

      expect(find.textContaining('hasta 1 hora antes'), findsOneWidget);
      expect(_activo(tester, 'Miércoles 21'), isTrue);
      expect(
        find.text('Puedes cancelarla hasta hoy a las 11:00 a. m.'),
        findsOneWidget,
      );
    });

    testWidgets('sin conexión al cancelar, avisa y deja la reserva',
        (WidgetTester tester) async {
      final _ReservasFalsas repo = _ReservasFalsas(reservas: _reservasDePrueba())
        ..fallaCancelar = true;
      await _abrir(tester, repo);

      await _tocar(tester, _botonDe('Viernes 23'));
      await _tocar(tester, find.text('Sí, cancelar'));

      expect(find.textContaining('No se pudo cancelar la reserva'), findsOneWidget);
      expect(find.text('Viernes 23 de octubre'), findsOneWidget);
      expect(_activo(tester, 'Viernes 23'), isTrue);
    });

    testWidgets('sin reservas, lo dice y lleva a reservar',
        (WidgetTester tester) async {
      await _abrir(
        tester,
        _ReservasFalsas(),
        rutas: <String, WidgetBuilder>{
          Rutas.rf02Reservas: (_) =>
              const Scaffold(body: Text('Pantalla de reservar')),
        },
      );

      expect(find.text('No tienes reservas próximas.'), findsOneWidget);
      await _tocar(tester, find.text('Reservar un cupo'));
      expect(find.text('Pantalla de reservar'), findsOneWidget);
    });

    testWidgets('si no carga, avisa y deja reintentar',
        (WidgetTester tester) async {
      final _ReservasFalsas repo = _ReservasFalsas(reservas: _reservasDePrueba())
        ..fallaLaConsulta = true;
      await _abrir(tester, repo);

      expect(find.textContaining('No se pudieron cargar tus reservas'),
          findsOneWidget);

      repo.fallaLaConsulta = false;
      await _tocar(tester, find.text('Reintentar'));

      expect(find.text('Viernes 23 de octubre'), findsOneWidget);
    });
  });
}
