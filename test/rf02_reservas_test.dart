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
import 'package:ufit/core/modelos/resultado_reserva.dart';
import 'package:ufit/core/modelos/zona.dart';
import 'package:ufit/core/rutas.dart';
import 'package:ufit/core/tema/app_theme.dart';
import 'package:ufit/features/reservas/datos/respuestas_de_reservas.dart';
import 'package:ufit/features/reservas/pantallas/rf02_reservas.dart';
import 'package:ufit/features/reservas/reglas_reservas.dart';

// ---------------------------------------------------------------------
// Datos de prueba
// ---------------------------------------------------------------------

/// "Ahora" en las pruebas: miércoles 7 de octubre de 2026, 9:30 a. m.
/// Esa semana va del lunes 5 al domingo 11.
final DateTime _ahoraDePrueba = DateTime(2026, 10, 7, 9, 30);
final DateTime _miercoles = DateTime(2026, 10, 7);

FranjaDisponible _franja(
  int id,
  DateTime fecha,
  int hora, {
  int ocupados = 0,
  bool abierta = true,
}) {
  String dosDigitos(int n) => n.toString().padLeft(2, '0');
  return FranjaDisponible(
    franjaId: id,
    fecha: fecha,
    horaInicio: '${dosDigitos(hora)}:00:00',
    horaFin: '${dosDigitos(hora + 1)}:00:00',
    cupoTotal: 75,
    cuposOcupados: ocupados,
    abierta: abierta,
  );
}

Reserva _reserva({
  int id = 1,
  int franjaId = 1,
  DateTime? fecha,
  int zonaId = 1,
  EstadoReserva estado = EstadoReserva.confirmada,
}) {
  return Reserva(
    id: id,
    perfilId: 'yo',
    franjaId: franjaId,
    fecha: fecha ?? _miercoles,
    zonaId: zonaId,
    estado: estado,
    // Con este formato, el código corto de la reserva 7 es "00000007".
    codigoQr: '${id.toString().padLeft(8, '0')}-0000-4000-8000-000000000000',
  );
}

/// El id de la franja: día del mes y hora. La del miércoles 7 a las 12:00
/// es la 712.
int _idDe(DateTime fecha, int hora) => fecha.day * 100 + hora;

/// Lo que ocupan las franjas que no están vacías (por id).
const Map<int, int> _ocupadosPorId = <int, int>{
  709: 20, // mié 7, 09:00: quedan 55
  710: 75, // mié 7, 10:00: llena
  712: 60, // mié 7, 12:00: quedan 15
  713: 74, // mié 7, 13:00: queda 1
  1612: 75, // vie 16, 12:00: llena
};

/// Franjas cerradas por el administrador.
const Set<int> _cerradas = <int>{
  711, // mié 7, 11:00
  2112, // mié 21, 12:00
};

/// Del lunes 5 al sábado 31 de octubre, de 06:00 a 14:00. Los domingos no
/// hay franjas.
List<FranjaDisponible> _franjasDePrueba() {
  final List<FranjaDisponible> lista = <FranjaDisponible>[];
  for (int dia = 0; dia < 27; dia++) {
    final DateTime fecha = DateTime(2026, 10, 5 + dia);
    if (fecha.weekday == DateTime.sunday) continue;

    for (int hora = 6; hora <= 13; hora++) {
      final int id = _idDe(fecha, hora);
      lista.add(_franja(
        id,
        fecha,
        hora,
        ocupados: _ocupadosPorId[id] ?? 0,
        abierta: !_cerradas.contains(id),
      ));
    }
  }
  return lista;
}

bool _dentro(DateTime fecha, DateTime? desde, DateTime? hasta) {
  final DateTime f = soloFecha(fecha);
  if (desde != null && f.isBefore(soloFecha(desde))) return false;
  if (hasta != null && f.isAfter(soloFecha(hasta))) return false;
  return true;
}

/// Repositorio de reservas falso. Aplica las mismas reglas que la función
/// reservar_cupos() de la base (supabase/schema.sql), en el mismo orden:
/// inexistente, cerrada, pasada, otra reserva ese día / ya reservada,
/// máximo 3 por semana, sin cupo y, si nada lo impide, creada.
class _ReservasFalsas implements RepositorioReservas {
  _ReservasFalsas({
    required List<FranjaDisponible> franjas,
    List<Reserva>? reservas,
  })  : franjas = List<FranjaDisponible>.of(franjas),
        reservas = List<Reserva>.of(reservas ?? <Reserva>[]);

  final List<FranjaDisponible> franjas;
  final List<Reserva> reservas;

  /// Si es true, disponibilidad() falla.
  bool fallaLaConsulta = false;

  /// Cuántas llamadas a reservarFranjas() fallan antes de funcionar.
  int fallosPorVenir = 0;

  /// En esos fallos, si la reserva alcanzó a quedar hecha en la base: es lo
  /// que pasa cuando se corta la red justo antes de que llegue la respuesta.
  bool aplicarAntesDeFallar = false;

  /// Las franjas que se pidieron en cada llamada a reservarFranjas().
  final List<List<int>> pedidos = <List<int>>[];

  /// Los rangos que se consultaron en disponibilidad().
  final List<(DateTime, DateTime)> consultas = <(DateTime, DateTime)>[];

  int _siguienteId = 1;

  /// Otra persona se queda con los cupos que quedaban.
  void llenar(int franjaId) {
    final int i =
        franjas.indexWhere((FranjaDisponible f) => f.franjaId == franjaId);
    final FranjaDisponible f = franjas[i];
    franjas[i] = FranjaDisponible(
      franjaId: f.franjaId,
      fecha: f.fecha,
      horaInicio: f.horaInicio,
      horaFin: f.horaFin,
      cupoTotal: f.cupoTotal,
      cuposOcupados: f.cupoTotal,
      abierta: f.abierta,
    );
  }

  @override
  Future<List<FranjaDisponible>> disponibilidad({
    required DateTime desde,
    required DateTime hasta,
  }) async {
    consultas.add((desde, hasta));
    if (fallaLaConsulta) {
      throw const ErrorDeDatos(
        TipoDeError.sinConexion,
        'No se pudo consultar la disponibilidad. '
        'Revisa tu conexión a internet e inténtalo de nuevo.',
      );
    }
    return franjas
        .where((FranjaDisponible f) => _dentro(f.fecha, desde, hasta))
        .toList();
  }

  @override
  Future<List<Reserva>> misReservas({DateTime? desde, DateTime? hasta}) async =>
      reservas.where((Reserva r) => _dentro(r.fecha, desde, hasta)).toList();

  @override
  Future<List<ResultadoPorFranja>> reservarFranjas({
    required List<int> franjaIds,
    required int zonaId,
  }) async {
    pedidos.add(List<int>.of(franjaIds));

    final bool fallar = fallosPorVenir > 0;
    if (fallar) fallosPorVenir--;
    if (fallar && !aplicarAntesDeFallar) throw _errorDeRed();

    final List<ResultadoPorFranja> salida = <ResultadoPorFranja>[
      for (final int id in franjaIds.toSet()) _procesar(id, zonaId),
    ];

    if (fallar) throw _errorDeRed();
    return salida;
  }

  ErrorDeDatos _errorDeRed() => const ErrorDeDatos(
        TipoDeError.sinConexion,
        'No se pudo confirmar la reserva. '
        'Revisa tu conexión a internet e inténtalo de nuevo.',
      );

  ResultadoPorFranja _procesar(int id, int zonaId) {
    ResultadoPorFranja sin(ResultadoReserva motivo) =>
        ResultadoPorFranja(franjaId: id, resultado: motivo);

    final int i = franjas.indexWhere((FranjaDisponible f) => f.franjaId == id);
    if (i < 0) return sin(ResultadoReserva.franjaInexistente);

    final FranjaDisponible f = franjas[i];
    if (!f.abierta) return sin(ResultadoReserva.franjaCerrada);
    if (franjaTermino(f, _ahoraDePrueba)) {
      return sin(ResultadoReserva.franjaPasada);
    }

    for (final Reserva previa in reservas) {
      if (previa.estaViva && mismoDia(previa.fecha, f.fecha)) {
        if (previa.franjaId != id) return sin(ResultadoReserva.otraReservaEseDia);
        return ResultadoPorFranja(
          franjaId: id,
          resultado: ResultadoReserva.yaReservada,
          reserva: previa,
        );
      }
    }

    // Máximo 3 por semana, de lunes a domingo; las canceladas no cuentan.
    final DateTime lunes = lunesDeLaSemana(f.fecha);
    final int enLaSemana = reservas
        .where((Reserva r) =>
            r.estado != EstadoReserva.cancelada &&
            mismoDia(lunesDeLaSemana(r.fecha), lunes))
        .length;
    if (enLaSemana >= maximoReservasPorSemana) {
      return sin(ResultadoReserva.limiteSemanal);
    }

    if (f.cuposDisponibles <= 0) return sin(ResultadoReserva.sinCupo);

    final Reserva nueva = _reserva(
      id: _siguienteId++,
      franjaId: id,
      fecha: f.fecha,
      zonaId: zonaId,
    );
    reservas.add(nueva);
    franjas[i] = FranjaDisponible(
      franjaId: f.franjaId,
      fecha: f.fecha,
      horaInicio: f.horaInicio,
      horaFin: f.horaFin,
      cupoTotal: f.cupoTotal,
      cuposOcupados: f.cuposOcupados + 1,
      abierta: f.abierta,
    );
    return ResultadoPorFranja(
      franjaId: id,
      resultado: ResultadoReserva.creada,
      reserva: nueva,
    );
  }

  // Lo que no es del RF2 no se usa en estas pruebas.
  @override
  Future<Reserva> reservar({required int franjaId, required int zonaId}) =>
      throw UnimplementedError();

  @override
  Future<void> cancelar(int reservaId) => throw UnimplementedError();

  @override
  Future<Reserva> registrarAsistencia(String codigoQr) =>
      throw UnimplementedError();
}

class _GimnasioFalso implements RepositorioGimnasio {
  @override
  Future<List<Zona>> zonas() async => const <Zona>[
        Zona(
          id: 1,
          nombre: 'Cardiovascular',
          descripcion: 'Trotadoras y bicicletas',
        ),
        Zona(id: 2, nombre: 'Fuerza', descripcion: 'Peso libre'),
        Zona(id: 3, nombre: 'Musculación', descripcion: 'Máquinas guiadas'),
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
// Ayudas para las pruebas de pantalla
// ---------------------------------------------------------------------

/// Pantalla alta para que el día completo quepa sin desplazarse.
Future<void> _abrir(
  WidgetTester tester,
  _ReservasFalsas repo, {
  Map<String, WidgetBuilder> rutas = const <String, WidgetBuilder>{},
}) async {
  await tester.binding.setSurfaceSize(const Size(800, 2400));
  addTearDown(() => tester.binding.setSurfaceSize(null));

  Repositorios.reservas = repo;
  Repositorios.gimnasio = _GimnasioFalso();

  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.claro,
      routes: rutas,
      home: PantallaReservas(reloj: () => _ahoraDePrueba),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _tocar(WidgetTester tester, Finder finder) async {
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

/// Busca solo dentro de la hoja de reserva: el calendario sigue ahí detrás
/// y repite varios textos (las horas, los cupos...).
Finder _enHoja(Finder buscado) =>
    find.descendant(of: find.byType(BottomSheet), matching: buscado);

FilledButton _boton(WidgetTester tester, String texto) =>
    tester.widget<FilledButton>(find.widgetWithText(FilledButton, texto));

// ---------------------------------------------------------------------
// Respuestas reales de reservar_cupos()
//
// Salen de ejecutar supabase/schema.sql en un Postgres de verdad y llamar
// la función como la llama la app. PostgREST entrega un arreglo de filas y
// la columna jsonb como un objeto.
// ---------------------------------------------------------------------

/// Una reserva nueva (zona 2, franja 32).
const String _respuestaUnaReserva =
    '[{"franja":32,"resultado":"creada","reserva":{"id":1,"fecha":"2026-10-08",'
    '"estado":"confirmada","zona_id":2,"codigo_qr":"d88b11e4-0de0-4215-88f0-598fd43389c6",'
    '"creada_en":"2026-10-06T18:52:28.438-05:00","franja_id":32,'
    '"perfil_id":"00000000-0000-0000-0000-000000000001","cancelada_en":null}}]';

/// Seis franjas con seis respuestas distintas.
const String _respuestaMezclada =
    '[{"franja":32,"resultado":"ya_reservada","reserva":{"id":1,"fecha":"2026-10-08",'
    '"estado":"confirmada","zona_id":2,"codigo_qr":"d88b11e4-0de0-4215-88f0-598fd43389c6",'
    '"creada_en":"2026-10-06T18:52:28.438-05:00","franja_id":32,'
    '"perfil_id":"00000000-0000-0000-0000-000000000001","cancelada_en":null}},'
    '{"franja":35,"resultado":"otra_reserva_ese_dia","reserva":null},'
    '{"franja":48,"resultado":"creada","reserva":{"id":3,"fecha":"2026-10-09",'
    '"estado":"confirmada","zona_id":3,"codigo_qr":"257eb660-807a-440f-ae8c-05fa2842c6ff",'
    '"creada_en":"2026-10-06T18:52:28.456-05:00","franja_id":48,'
    '"perfil_id":"00000000-0000-0000-0000-000000000001","cancelada_en":null}},'
    '{"franja":51,"resultado":"franja_cerrada","reserva":null},'
    '{"franja":52,"resultado":"otra_reserva_ese_dia","reserva":null},'
    '{"franja":999999,"resultado":"franja_inexistente","reserva":null}]';

/// Filas de la tabla reservas, como las lee misReservas().
const String _filasDeReservas =
    '[{"id":1,"perfil_id":"00000000-0000-0000-0000-000000000001","franja_id":32,'
    '"fecha":"2026-10-08","zona_id":2,"estado":"confirmada",'
    '"codigo_qr":"d88b11e4-0de0-4215-88f0-598fd43389c6"},'
    '{"id":3,"perfil_id":"00000000-0000-0000-0000-000000000001","franja_id":48,'
    '"fecha":"2026-10-09","zona_id":3,"estado":"cancelada",'
    '"codigo_qr":"257eb660-807a-440f-ae8c-05fa2842c6ff"}]';

void main() {
  // -------------------------------------------------------------------
  group('fechas y textos', () {
    test('ahoraEnColombia es la hora de Colombia (UTC-5) como reloj de pared',
        () {
      final DateTime a = ahoraEnColombia();
      final DateTime esperado =
          DateTime.now().toUtc().subtract(const Duration(hours: 5));
      final DateTime comoUtc =
          DateTime.utc(a.year, a.month, a.day, a.hour, a.minute, a.second);

      expect(comoUtc.difference(esperado).inSeconds.abs(), lessThanOrEqualTo(2));
    });

    test('fechaIso escribe AAAA-MM-DD', () {
      expect(fechaIso(DateTime(2026, 3, 5)), '2026-03-05');
      expect(fechaIso(DateTime(2026, 12, 31)), '2026-12-31');
    });

    test('diasEntre cuenta días de calendario', () {
      expect(diasEntre(DateTime(2026, 10, 5), DateTime(2026, 10, 12)), 7);
      expect(diasEntre(DateTime(2026, 3, 1), DateTime(2026, 2, 28)), -1);
      expect(diasEntre(DateTime(2026, 12, 30), DateTime(2027, 1, 6)), 7);
      // Las horas no cuentan: es de un día a otro.
      expect(
        diasEntre(DateTime(2026, 10, 7, 23, 59), DateTime(2026, 10, 8, 0, 1)),
        1,
      );
    });

    test('la semana va de lunes a domingo', () {
      expect(lunesDeLaSemana(DateTime(2026, 10, 7)), DateTime(2026, 10, 5));
      expect(lunesDeLaSemana(DateTime(2026, 10, 5)), DateTime(2026, 10, 5));
      expect(lunesDeLaSemana(DateTime(2026, 10, 11)), DateTime(2026, 10, 5));
      expect(lunesDeLaSemana(DateTime(2026, 11, 1)), DateTime(2026, 10, 26));
      expect(lunesDeLaSemana(DateTime(2027, 1, 3)), DateTime(2026, 12, 28));

      final List<DateTime> semana = semanaDesde(DateTime(2026, 10, 26));
      expect(semana, hasLength(7));
      expect(semana.first, DateTime(2026, 10, 26));
      expect(semana[5], DateTime(2026, 10, 31));
      expect(semana.last, DateTime(2026, 11, 1));
    });

    test('escribe los días en español', () {
      final DateTime lunes = DateTime(2026, 10, 12);

      expect(formatearDiaLargo(lunes), 'lunes 12 de octubre');
      expect(formatearDiaCompleto(lunes), 'lunes 12 de octubre de 2026');
      expect(formatearDiaCorto(lunes), 'lun 12 oct');
      expect(capitalizar('lunes 12 de octubre'), 'Lunes 12 de octubre');
      expect(capitalizar(''), '');
      expect(nombreCortoDelDia(3), 'mié');
      expect(nombreLargoDelDia(3), 'miércoles');
      expect(nombreLargoDelDia(7), 'domingo');
    });

    test('escribe la semana, también cuando cruza de mes o de año', () {
      expect(formatearSemana(DateTime(2026, 10, 5)), '5 – 11 de octubre de 2026');
      expect(
        formatearSemana(DateTime(2026, 10, 26)),
        '26 de octubre – 1 de noviembre de 2026',
      );
      expect(
        formatearSemana(DateTime(2026, 12, 28)),
        '28 de diciembre de 2026 – 3 de enero de 2027',
      );
    });

    test('lee las horas como las entrega Postgres', () {
      expect(minutosDe('06:00:00'), 360);
      expect(minutosDe('6:30'), 390);
      expect(minutosDe('15:00:00'), 900);
      expect(horaCorta('06:00:00'), '06:00');
      expect(horaCorta('6:05'), '06:05');
      expect(horaCorta('15:30:00'), '15:30');
      expect(formatearRango(_franja(1, _miercoles, 6)), '06:00 – 07:00');
      expect(formatearRango(_franja(1, _miercoles, 15)), '15:00 – 16:00');
    });

    test('cuenta los cupos con singular y plural', () {
      expect(
        textoDeCupos(_franja(1, _miercoles, 10, ocupados: 17)),
        'Quedan 58 cupos',
      );
      expect(
        textoDeCupos(_franja(1, _miercoles, 10, ocupados: 74)),
        'Queda 1 cupo',
      );
      expect(
        textoDeCupos(_franja(1, _miercoles, 10, ocupados: 75)),
        'Sin cupos',
      );
      expect(
        textoDeCupos(_franja(1, _miercoles, 10, ocupados: 80)),
        'Sin cupos',
      );
    });

    test('el código corto son los primeros 8 caracteres, en mayúsculas', () {
      expect(codigoCorto('682325ef-1234-4abc-8def-0123456789ab'), '682325EF');
      expect(codigoCorto('abc'), 'ABC');
    });
  });

  // -------------------------------------------------------------------
  group('estado de las franjas', () {
    test('una franja futura, abierta y con cupo se puede reservar', () {
      final FranjaDisponible f = _franja(1, _miercoles, 10, ocupados: 30);

      expect(estadoDeFranja(f, ahora: _ahoraDePrueba), EstadoDeFranja.disponible);
      expect(franjaTermino(f, _ahoraDePrueba), isFalse);
      expect(franjaEnCurso(f, _ahoraDePrueba), isFalse);
    });

    test('una franja que ya terminó está pasada', () {
      final FranjaDisponible f = _franja(1, _miercoles, 8);

      expect(estadoDeFranja(f, ahora: _ahoraDePrueba), EstadoDeFranja.pasada);
    });

    test('la franja en curso todavía se puede reservar', () {
      // 09:00 – 10:00 con la hora en 09:30.
      final FranjaDisponible f = _franja(1, _miercoles, 9);

      expect(franjaEnCurso(f, _ahoraDePrueba), isTrue);
      expect(estadoDeFranja(f, ahora: _ahoraDePrueba), EstadoDeFranja.disponible);
    });

    test('una franja que termina justo ahora ya se considera terminada', () {
      // Es la misma regla de la base: (fecha + hora_fin) <= ahora.
      final FranjaDisponible f = FranjaDisponible(
        franjaId: 1,
        fecha: DateTime(2026, 10, 7),
        horaInicio: '08:30:00',
        horaFin: '09:30:00',
        cupoTotal: 75,
        cuposOcupados: 0,
        abierta: true,
      );

      expect(franjaTermino(f, _ahoraDePrueba), isTrue);
      expect(franjaEnCurso(f, _ahoraDePrueba), isFalse);
      expect(estadoDeFranja(f, ahora: _ahoraDePrueba), EstadoDeFranja.pasada);
    });

    test('una franja que empieza justo ahora ya está en curso', () {
      final FranjaDisponible f = FranjaDisponible(
        franjaId: 1,
        fecha: DateTime(2026, 10, 7),
        horaInicio: '09:30:00',
        horaFin: '10:30:00',
        cupoTotal: 75,
        cuposOcupados: 0,
        abierta: true,
      );

      expect(franjaEnCurso(f, _ahoraDePrueba), isTrue);
    });

    test('cerrada y llena', () {
      expect(
        estadoDeFranja(
          _franja(1, _miercoles, 11, abierta: false),
          ahora: _ahoraDePrueba,
        ),
        EstadoDeFranja.cerrada,
      );
      expect(
        estadoDeFranja(
          _franja(1, _miercoles, 12, ocupados: 75),
          ahora: _ahoraDePrueba,
        ),
        EstadoDeFranja.llena,
      );
      // Más ocupados que el aforo tampoco deja reservar.
      expect(
        estadoDeFranja(
          _franja(1, _miercoles, 12, ocupados: 80),
          ahora: _ahoraDePrueba,
        ),
        EstadoDeFranja.llena,
      );
    });

    test('cuando se cumplen varias, manda la más definitiva', () {
      // Cerrada y llena a la vez: cerrada.
      expect(
        estadoDeFranja(
          _franja(1, _miercoles, 12, ocupados: 75, abierta: false),
          ahora: _ahoraDePrueba,
        ),
        EstadoDeFranja.cerrada,
      );
      // Cerrada pero ya terminó: pasada.
      expect(
        estadoDeFranja(
          _franja(1, _miercoles, 7, abierta: false),
          ahora: _ahoraDePrueba,
        ),
        EstadoDeFranja.pasada,
      );
    });

    test('con una reserva ese día: la suya es "tuya" y las demás no se tocan',
        () {
      final Reserva mia = _reserva(franjaId: 6);

      // La franja reservada es tuya aunque esté cerrada, llena o pasada.
      for (final FranjaDisponible f in <FranjaDisponible>[
        _franja(6, _miercoles, 12),
        _franja(6, _miercoles, 12, abierta: false),
        _franja(6, _miercoles, 12, ocupados: 75),
        _franja(6, _miercoles, 7),
      ]) {
        expect(
          estadoDeFranja(f, ahora: _ahoraDePrueba, reservaDelDia: mia),
          EstadoDeFranja.tuya,
        );
      }

      expect(
        estadoDeFranja(
          _franja(7, _miercoles, 13),
          ahora: _ahoraDePrueba,
          reservaDelDia: mia,
        ),
        EstadoDeFranja.conOtraReserva,
      );
      // Lo que ya no se puede reservar sigue diciendo por qué.
      expect(
        estadoDeFranja(
          _franja(8, _miercoles, 13, ocupados: 75),
          ahora: _ahoraDePrueba,
          reservaDelDia: mia,
        ),
        EstadoDeFranja.llena,
      );
      expect(
        estadoDeFranja(
          _franja(9, _miercoles, 7),
          ahora: _ahoraDePrueba,
          reservaDelDia: mia,
        ),
        EstadoDeFranja.pasada,
      );
    });

    test('la marca de un día resume sus franjas', () {
      EstadoDelDia de(List<FranjaDisponible> franjas, {Reserva? reserva}) =>
          estadoDelDia(
            franjasDelDia: franjas,
            ahora: _ahoraDePrueba,
            reservaDelDia: reserva,
          );

      expect(de(<FranjaDisponible>[]), EstadoDelDia.sinFranjas);

      // Todo terminó.
      expect(
        de(<FranjaDisponible>[_franja(1, _miercoles, 6), _franja(2, _miercoles, 7)]),
        EstadoDelDia.pasado,
      );
      // Una franja con cupo basta para decir "hay cupos".
      expect(
        de(<FranjaDisponible>[
          _franja(1, _miercoles, 6),
          _franja(2, _miercoles, 10, ocupados: 75),
          _franja(3, _miercoles, 11),
        ]),
        EstadoDelDia.conCupo,
      );
      // Lo que queda está lleno o cerrado.
      expect(
        de(<FranjaDisponible>[
          _franja(1, _miercoles, 6),
          _franja(2, _miercoles, 10, ocupados: 75),
          _franja(3, _miercoles, 11, abierta: false),
        ]),
        EstadoDelDia.sinCupo,
      );
      // Con una reserva propia el día es "con reserva", haya o no cupos.
      expect(
        de(
          <FranjaDisponible>[
            _franja(1, _miercoles, 10, ocupados: 75),
            _franja(2, _miercoles, 11),
          ],
          reserva: _reserva(franjaId: 2),
        ),
        EstadoDelDia.conReserva,
      );
    });

    test('solo las reservas vivas cuentan, una por día', () {
      final Map<String, Reserva> porDia = reservasVivasPorDia(<Reserva>[
        _reserva(id: 1, fecha: DateTime(2026, 10, 7)),
        _reserva(id: 2, fecha: DateTime(2026, 10, 8), estado: EstadoReserva.asistida),
        _reserva(id: 3, fecha: DateTime(2026, 10, 9), estado: EstadoReserva.cancelada),
        _reserva(id: 4, fecha: DateTime(2026, 10, 10), estado: EstadoReserva.noAsistida),
      ]);

      expect(porDia.keys, <String>['2026-10-07', '2026-10-08']);
      expect(porDia['2026-10-07']!.id, 1);
      expect(porDia['2026-10-08']!.id, 2);
    });
  });

  // -------------------------------------------------------------------
  group('franjas cercanas cuando una está llena', () {
    // Con la hora en las 6:00 todo es futuro. 08:00 está cerrada, y la de
    // las 10:00 es la llena.
    final DateTime temprano = DateTime(2026, 10, 7, 6, 0);
    final List<FranjaDisponible> dia = <FranjaDisponible>[
      for (int h = 6; h <= 13; h++)
        _franja(
          h,
          _miercoles,
          h,
          ocupados: h == 10 ? 75 : 0,
          abierta: h != 8,
        ),
    ];
    final FranjaDisponible llena = dia[4];

    List<int> horasDe(List<FranjaDisponible> franjas) => franjas
        .map((FranjaDisponible f) => minutosDe(f.horaInicio) ~/ 60)
        .toList();

    test('ofrece las más cercanas; a igual distancia, la más temprana', () {
      final List<FranjaDisponible> r =
          sugerirAlternativas(llena, dia, ahora: temprano);

      // 09:00 y 11:00 están a una hora (gana la 09:00), luego 12:00.
      expect(horasDe(r), <int>[9, 11, 12]);
    });

    test('respeta el máximo y se salta la cerrada y la propia llena', () {
      final List<FranjaDisponible> r =
          sugerirAlternativas(llena, dia, ahora: temprano, maximo: 5);

      // 7 y 13 están a la misma distancia (3 horas): primero la temprana.
      expect(horasDe(r), <int>[9, 11, 12, 7, 13]);
      expect(horasDe(r), isNot(contains(8)));
      expect(horasDe(r), isNot(contains(10)));
    });

    test('no ofrece franjas que ya terminaron', () {
      // A las 9:30: la de las 09:00 está en curso (sirve); las de antes no.
      final List<FranjaDisponible> r = sugerirAlternativas(
        llena,
        dia,
        ahora: _ahoraDePrueba,
        maximo: 10,
      );

      expect(horasDe(r), <int>[9, 11, 12, 13]);
    });

    test('con otra reserva ese día no queda nada que ofrecer', () {
      final List<FranjaDisponible> r = sugerirAlternativas(
        llena,
        dia,
        ahora: temprano,
        reservaDelDia: _reserva(franjaId: 12),
      );

      expect(r, isEmpty);
    });
  });

  // -------------------------------------------------------------------
  group('reservas recurrentes', () {
    List<String> fechas({
      required DateTime inicio,
      required Set<int> dias,
      required int semanas,
    }) =>
        fechasDeRepeticion(inicio: inicio, diasSemana: dias, semanas: semanas)
            .map(fechaIso)
            .toList();

    test('calcula las fechas desde el inicio, en orden', () {
      // Lunes 12, lunes y miércoles, 2 semanas.
      expect(
        fechas(inicio: DateTime(2026, 10, 12), dias: <int>{1, 3}, semanas: 2),
        <String>['2026-10-12', '2026-10-14', '2026-10-19', '2026-10-21'],
      );
      // Jueves 8, jueves y viernes, 2 semanas.
      expect(
        fechas(inicio: DateTime(2026, 10, 8), dias: <int>{4, 5}, semanas: 2),
        <String>['2026-10-08', '2026-10-09', '2026-10-15', '2026-10-16'],
      );
    });

    test('el día de inicio solo cuenta si su día de la semana está elegido', () {
      // Miércoles 7, pero solo lunes: arranca el lunes siguiente.
      expect(
        fechas(inicio: DateTime(2026, 10, 7), dias: <int>{1}, semanas: 2),
        <String>['2026-10-12', '2026-10-19'],
      );
      expect(
        fechas(inicio: DateTime(2026, 10, 7), dias: <int>{3, 5}, semanas: 4),
        <String>[
          '2026-10-07', '2026-10-09', '2026-10-14', '2026-10-16',
          '2026-10-21', '2026-10-23', '2026-10-28', '2026-10-30',
        ],
      );
    });

    test('las semanas se limitan entre 1 y $maximoDeSemanas', () {
      expect(
        fechas(inicio: DateTime(2026, 10, 7), dias: <int>{3}, semanas: 0),
        <String>['2026-10-07'],
      );
      expect(
        fechas(inicio: DateTime(2026, 10, 12), dias: <int>{1}, semanas: 20),
        hasLength(8),
      );
      expect(
        fechas(inicio: DateTime(2026, 10, 12), dias: <int>{1}, semanas: 20).last,
        '2026-11-30',
      );
    });

    test('cruza de mes y de año', () {
      expect(
        fechas(inicio: DateTime(2026, 12, 30), dias: <int>{3}, semanas: 2),
        <String>['2026-12-30', '2027-01-06'],
      );
    });

    test('el máximo posible cabe en una sola llamada a la base (60 franjas)', () {
      final List<String> todas = fechas(
        inicio: DateTime(2026, 10, 12),
        dias: <int>{1, 2, 3, 4, 5, 6, 7},
        semanas: maximoDeSemanas,
      );

      expect(todas, hasLength(56));
      expect(todas.length, lessThanOrEqualTo(60));
    });

    test('busca la franja de la misma hora en cada fecha', () {
      final DateTime d7 = DateTime(2026, 10, 7);
      final DateTime d14 = DateTime(2026, 10, 14);
      final DateTime d21 = DateTime(2026, 10, 21);
      final List<FranjaDisponible> publicadas = <FranjaDisponible>[
        _franja(710, d7, 10),
        _franja(712, d7, 12),
        _franja(1412, d14, 12),
        _franja(2112, d21, 12),
      ];

      List<int?> ids(String hora) => armarRepeticion(
            fechas: <DateTime>[d7, d14, d21],
            horaInicio: hora,
            franjas: publicadas,
          ).map((ItemDeRepeticion i) => i.franja?.franjaId).toList();

      expect(ids('12:00:00'), <int?>[712, 1412, 2112]);
      // Escrita a mano, sin segundos ni cero inicial, también se encuentra.
      expect(ids('12:00'), <int?>[712, 1412, 2112]);
      // La de las 10:00 solo está publicada el primer día.
      expect(ids('10:00:00'), <int?>[710, null, null]);
    });

    test('junta cada fecha con lo que respondió la base', () {
      final DateTime d7 = DateTime(2026, 10, 7);
      final DateTime d14 = DateTime(2026, 10, 14);
      final DateTime d21 = DateTime(2026, 10, 21);
      final List<ItemDeRepeticion> items = <ItemDeRepeticion>[
        ItemDeRepeticion(fecha: d7, franja: _franja(712, d7, 12)),
        ItemDeRepeticion(fecha: d14, franja: _franja(1412, d14, 12)),
        ItemDeRepeticion(fecha: d21), // ese día no hay franja
      ];

      final List<LineaDeResultado> lineas = unirResultados(items, <ResultadoPorFranja>[
        const ResultadoPorFranja(franjaId: 712, resultado: ResultadoReserva.creada),
        const ResultadoPorFranja(franjaId: 1412, resultado: ResultadoReserva.sinCupo),
      ]);

      expect(lineas.map((LineaDeResultado l) => l.resultado), <ResultadoReserva?>[
        ResultadoReserva.creada,
        ResultadoReserva.sinCupo,
        null,
      ]);
      expect(lineas.map((LineaDeResultado l) => l.exitoso), <bool>[true, false, false]);
      expect(lineas.map((LineaDeResultado l) => l.horaInicio), <String?>[
        '12:00:00',
        '12:00:00',
        null,
      ]);
      expect(resumenDeResultados(lineas), 'Se confirmaron 1 de 3 fechas.');
    });

    test('resume cuando todo salió bien y cuando nada', () {
      List<LineaDeResultado> con(List<ResultadoReserva> resultados) =>
          <LineaDeResultado>[
            for (final ResultadoReserva r in resultados)
              LineaDeResultado(fecha: _miercoles, resultado: r),
          ];

      expect(
        resumenDeResultados(
          con(<ResultadoReserva>[ResultadoReserva.creada, ResultadoReserva.yaReservada]),
        ),
        'Quedaron confirmadas las 2 reservas.',
      );
      expect(
        resumenDeResultados(
          con(<ResultadoReserva>[ResultadoReserva.sinCupo, ResultadoReserva.franjaCerrada]),
        ),
        'No se pudo confirmar ninguna de las 2 fechas.',
      );
    });

    test('dice con palabras qué pasó con cada fecha', () {
      String frase(ResultadoReserva? r) =>
          etiquetaDeLinea(LineaDeResultado(fecha: _miercoles, resultado: r));

      expect(frase(ResultadoReserva.creada), 'Reservada');
      expect(frase(ResultadoReserva.yaReservada), 'Ya la tenías reservada');
      expect(frase(ResultadoReserva.otraReservaEseDia), 'Ya tenías otra reserva ese día');
      expect(frase(ResultadoReserva.sinCupo), 'Sin cupos');
      expect(frase(ResultadoReserva.franjaCerrada), 'Franja cerrada');
      expect(frase(ResultadoReserva.franjaPasada), 'La franja ya terminó');
      expect(frase(ResultadoReserva.franjaInexistente), 'La franja ya no existe');
      expect(frase(ResultadoReserva.desconocido), 'No se pudo reservar');
      expect(frase(null), 'No hay franja publicada a esa hora');
    });
  });

  // -------------------------------------------------------------------
  group('lo que responde la base', () {
    test('el máximo de 3 por semana es un fallo con su propio mensaje', () {
      final ResultadoReserva r = resultadoReservaDesdeTexto('limite_semanal');

      expect(r, ResultadoReserva.limiteSemanal);
      expect(r.fueExitoso, isFalse);
      expect(r.mensaje, contains('máximo 3 por semana'));
      expect(
        etiquetaDeLinea(LineaDeResultado(
          fecha: DateTime(2026, 10, 14),
          horaInicio: '12:00:00',
          resultado: r,
        )),
        'Ya tenías 3 reservas esa semana',
      );
    });

    test('lee una reserva nueva', () {
      final List<ResultadoPorFranja> r = resultadosDesdeRespuesta(
        jsonDecode(_respuestaUnaReserva),
        <int>[32],
      );

      expect(r, hasLength(1));
      expect(r.single.franjaId, 32);
      expect(r.single.resultado, ResultadoReserva.creada);
      expect(r.single.exitoso, isTrue);

      final Reserva reserva = r.single.reserva!;
      expect(reserva.id, 1);
      expect(reserva.perfilId, '00000000-0000-0000-0000-000000000001');
      expect(reserva.franjaId, 32);
      expect(reserva.fecha, DateTime(2026, 10, 8));
      expect(reserva.zonaId, 2);
      expect(reserva.estado, EstadoReserva.confirmada);
      expect(reserva.codigoQr, 'd88b11e4-0de0-4215-88f0-598fd43389c6');
      expect(codigoCorto(reserva.codigoQr), 'D88B11E4');
    });

    test('devuelve una respuesta por franja pedida, en el orden pedido', () {
      // Se pide en otro orden y con una repetida (la 32).
      final List<ResultadoPorFranja> r = resultadosDesdeRespuesta(
        jsonDecode(_respuestaMezclada),
        <int>[999999, 48, 32, 51, 35, 52, 32],
      );

      expect(
        r.map((ResultadoPorFranja x) => x.franjaId),
        <int>[999999, 48, 32, 51, 35, 52],
      );
      expect(r.map((ResultadoPorFranja x) => x.resultado), <ResultadoReserva>[
        ResultadoReserva.franjaInexistente,
        ResultadoReserva.creada,
        ResultadoReserva.yaReservada,
        ResultadoReserva.franjaCerrada,
        ResultadoReserva.otraReservaEseDia,
        ResultadoReserva.otraReservaEseDia,
      ]);
      expect(r.map((ResultadoPorFranja x) => x.exitoso), <bool>[
        false, true, true, false, false, false,
      ]);
    });

    test('solo trae la reserva cuando hay una', () {
      final List<ResultadoPorFranja> r = resultadosDesdeRespuesta(
        jsonDecode(_respuestaMezclada),
        <int>[32, 35, 48, 51, 52, 999999],
      );

      expect(r[0].reserva!.id, 1); // ya_reservada: la misma de antes
      expect(r[1].reserva, isNull);
      expect(r[2].reserva!.id, 3);
      expect(r[2].reserva!.zonaId, 3);
      expect(r[3].reserva, isNull);
      expect(r[4].reserva, isNull);
      expect(r[5].reserva, isNull);
    });

    test('lo que la base no contestó es un fallo, nunca un éxito', () {
      for (final Object? vacio in <Object?>[null, <Object?>[], 'no es una lista']) {
        final List<ResultadoPorFranja> r =
            resultadosDesdeRespuesta(vacio, <int>[10, 11]);

        expect(r, hasLength(2));
        expect(
          r.map((ResultadoPorFranja x) => x.resultado),
          everyElement(ResultadoReserva.desconocido),
        );
        expect(r.any((ResultadoPorFranja x) => x.exitoso), isFalse);
      }
    });

    test('un código que la app no conoce es un fallo', () {
      final List<ResultadoPorFranja> r = resultadosDesdeRespuesta(
        jsonDecode('[{"franja":5,"resultado":"algo_nuevo","reserva":null}]'),
        <int>[5],
      );

      expect(r.single.resultado, ResultadoReserva.desconocido);
      expect(r.single.exitoso, isFalse);
    });

    test('ignora las franjas que no se pidieron y los números con decimales', () {
      final List<ResultadoPorFranja> r = resultadosDesdeRespuesta(
        jsonDecode(
          '[{"franja":7.0,"resultado":"sin_cupo","reserva":null},'
          '{"franja":8,"resultado":"creada","reserva":null}]',
        ),
        <int>[7],
      );

      expect(r, hasLength(1));
      expect(r.single.franjaId, 7);
      expect(r.single.resultado, ResultadoReserva.sinCupo);
    });

    test('una reserva con forma inesperada no vuelve un éxito en un error', () {
      final List<ResultadoPorFranja> r = resultadosDesdeRespuesta(
        jsonDecode('[{"franja":5,"resultado":"creada","reserva":{"id":"x"}}]'),
        <int>[5],
      );

      expect(r.single.resultado, ResultadoReserva.creada);
      expect(r.single.exitoso, isTrue);
      expect(r.single.reserva, isNull);
    });

    test('lee las filas de la tabla reservas', () {
      final List<Reserva> reservas = (jsonDecode(_filasDeReservas) as List<dynamic>)
          .map((dynamic f) => reservaDesdeFila(f as Map<String, dynamic>))
          .toList();

      expect(reservas, hasLength(2));
      expect(reservas[0].franjaId, 32);
      expect(reservas[0].estado, EstadoReserva.confirmada);
      expect(reservas[0].estaViva, isTrue);
      expect(reservas[1].fecha, DateTime(2026, 10, 9));
      expect(reservas[1].estado, EstadoReserva.cancelada);
      expect(reservas[1].estaViva, isFalse);
    });
  });

  // -------------------------------------------------------------------
  group('pantalla del RF2', () {
    testWidgets('muestra la semana y las franjas de hoy con su estado',
        (WidgetTester tester) async {
      await _abrir(tester, _ReservasFalsas(franjas: _franjasDePrueba()));

      expect(find.text('Reservar cupo'), findsOneWidget);
      expect(find.text('5 – 11 de octubre de 2026'), findsOneWidget);
      expect(find.text('Hoy · Miércoles 7 de octubre'), findsOneWidget);

      // Las tres de la mañana ya terminaron.
      expect(find.text('Ya terminó'), findsNWidgets(3));
      // La de las 9:00 está en curso y todavía se puede reservar.
      expect(find.text('En curso · Quedan 55 cupos'), findsOneWidget);
      expect(find.text('Sin cupos'), findsOneWidget);
      expect(find.text('Cerrada'), findsOneWidget);
      expect(find.text('Quedan 15 cupos'), findsOneWidget);
      expect(find.text('Queda 1 cupo'), findsOneWidget);
    });

    testWidgets('cambia de día dentro de la semana', (WidgetTester tester) async {
      await _abrir(tester, _ReservasFalsas(franjas: _franjasDePrueba()));

      await _tocar(tester, find.text('jue'));

      expect(find.text('Jueves 8 de octubre'), findsOneWidget);
      // Nada ha empezado: las 8 franjas están vacías.
      expect(find.text('Quedan 75 cupos'), findsNWidgets(8));
      expect(find.text('Ya terminó'), findsNothing);
    });

    testWidgets('un día sin franjas lo dice', (WidgetTester tester) async {
      await _abrir(tester, _ReservasFalsas(franjas: _franjasDePrueba()));

      await _tocar(tester, find.text('dom'));

      expect(find.text('Domingo 11 de octubre'), findsOneWidget);
      expect(find.text('No hay franjas publicadas para este día.'), findsOneWidget);
    });

    testWidgets('navega entre semanas hasta el límite', (WidgetTester tester) async {
      final _ReservasFalsas repo = _ReservasFalsas(franjas: _franjasDePrueba());
      await _abrir(tester, repo);

      bool activo(IconData icono) => tester
          .widget<IconButton>(find.widgetWithIcon(IconButton, icono))
          .onPressed != null;

      // No se puede ir a semanas que ya pasaron.
      expect(activo(Icons.chevron_left), isFalse);
      expect(activo(Icons.chevron_right), isTrue);

      await _tocar(tester, find.byTooltip('Semana siguiente'));

      expect(find.text('12 – 18 de octubre de 2026'), findsOneWidget);
      // En otra semana se queda en el lunes.
      expect(find.text('Lunes 12 de octubre'), findsOneWidget);
      expect(repo.consultas.last, (DateTime(2026, 10, 12), DateTime(2026, 10, 18)));
      expect(activo(Icons.chevron_left), isTrue);

      await _tocar(tester, find.byTooltip('Semana anterior'));

      expect(find.text('5 – 11 de octubre de 2026'), findsOneWidget);
      expect(find.text('Hoy · Miércoles 7 de octubre'), findsOneWidget);

      // Ocho semanas en total: la semana de hoy y siete más.
      for (int i = 0; i < 7; i++) {
        await _tocar(tester, find.byTooltip('Semana siguiente'));
      }
      expect(find.text('23 – 29 de noviembre de 2026'), findsOneWidget);
      expect(activo(Icons.chevron_right), isFalse);
    });

    testWidgets('si no carga, muestra el motivo y se puede reintentar',
        (WidgetTester tester) async {
      final _ReservasFalsas repo = _ReservasFalsas(franjas: _franjasDePrueba())
        ..fallaLaConsulta = true;
      await _abrir(tester, repo);

      expect(find.textContaining('No se pudo consultar la disponibilidad'), findsOneWidget);
      expect(find.text('Quedan 15 cupos'), findsNothing);

      repo.fallaLaConsulta = false;
      await _tocar(tester, find.text('Reintentar'));

      expect(find.text('Hoy · Miércoles 7 de octubre'), findsOneWidget);
      expect(find.text('Quedan 15 cupos'), findsOneWidget);
    });

    testWidgets('reserva una franja eligiendo la zona', (WidgetTester tester) async {
      final _ReservasFalsas repo = _ReservasFalsas(franjas: _franjasDePrueba());
      await _abrir(tester, repo);

      await _tocar(tester, find.text('12:00 – 13:00'));

      expect(find.text('Confirmar reserva'), findsOneWidget);
      expect(find.text('Zona del gimnasio'), findsOneWidget);
      // Sin zona no se puede reservar.
      expect(find.text('Elige una zona'), findsOneWidget);
      expect(_boton(tester, 'Reservar').onPressed, isNull);

      await _tocar(tester, find.text('Fuerza'));

      expect(find.text('Elige una zona'), findsNothing);
      expect(_boton(tester, 'Reservar').onPressed, isNotNull);

      await _tocar(tester, find.widgetWithText(FilledButton, 'Reservar'));

      expect(find.text('Reserva confirmada'), findsOneWidget);
      expect(find.text('Código 00000001'), findsOneWidget);
      expect(repo.reservas, hasLength(1));
      expect(repo.reservas.single.franjaId, 712);
      expect(repo.reservas.single.zonaId, 2);
      expect(repo.pedidos, <List<int>>[<int>[712]]);

      await _tocar(tester, find.text('Listo'));

      // El calendario ya refleja la reserva.
      expect(find.text('Confirmar reserva'), findsNothing);
      expect(find.text('Tu reserva · Fuerza · código 00000001'), findsOneWidget);
      expect(find.textContaining('Ya tienes una reserva este día'), findsOneWidget);
    });

    testWidgets('con una reserva ese día, las otras franjas no se pueden reservar',
        (WidgetTester tester) async {
      final _ReservasFalsas repo = _ReservasFalsas(
        franjas: _franjasDePrueba(),
        reservas: <Reserva>[_reserva(id: 7, franjaId: 712, zonaId: 1)],
      );
      await _abrir(tester, repo);

      expect(
        find.textContaining('Ya tienes una reserva este día, de 12:00 a 13:00.'),
        findsOneWidget,
      );
      expect(
        find.text('Tu reserva · Cardiovascular · código 00000007'),
        findsOneWidget,
      );

      await _tocar(tester, find.text('13:00 – 14:00'));

      expect(find.text('Confirmar reserva'), findsNothing);
      expect(repo.pedidos, isEmpty);
    });

    testWidgets('una franja llena ofrece las más cercanas con cupo',
        (WidgetTester tester) async {
      await _abrir(tester, _ReservasFalsas(franjas: _franjasDePrueba()));

      // La de las 10:00 está llena.
      await _tocar(tester, find.text('10:00 – 11:00'));

      expect(find.text('Franja sin cupos'), findsOneWidget);
      expect(_enHoja(find.text('Esta franja ya no tiene cupos.')), findsOneWidget);
      expect(find.text('Franjas cercanas con cupo'), findsOneWidget);
      // Las tres más cercanas que sí se pueden reservar.
      expect(_enHoja(find.text('09:00 – 10:00')), findsOneWidget);
      expect(_enHoja(find.text('12:00 – 13:00')), findsOneWidget);
      expect(_enHoja(find.text('13:00 – 14:00')), findsOneWidget);
      // No: ya terminó, o está cerrada.
      expect(_enHoja(find.text('08:00 – 09:00')), findsNothing);
      expect(_enHoja(find.text('11:00 – 12:00')), findsNothing);

      // Elegir una lleva a reservarla.
      await _tocar(tester, _enHoja(find.text('12:00 – 13:00')));

      expect(find.text('Confirmar reserva'), findsOneWidget);
      expect(_enHoja(find.text('12:00 – 13:00')), findsOneWidget);
      expect(_enHoja(find.text('Quedan 15 cupos')), findsOneWidget);
    });

    testWidgets('si la franja se llena mientras se decide, lo dice y ofrece otras',
        (WidgetTester tester) async {
      final _ReservasFalsas repo = _ReservasFalsas(franjas: _franjasDePrueba());
      await _abrir(tester, repo);

      // En el calendario "queda 1 cupo"...
      await _tocar(tester, find.text('13:00 – 14:00'));
      await _tocar(tester, find.text('Musculación'));
      // ...pero alguien lo toma antes de confirmar.
      repo.llenar(713);

      await _tocar(tester, find.widgetWithText(FilledButton, 'Reservar'));

      expect(_enHoja(find.text('No se pudo reservar')), findsOneWidget);
      expect(_enHoja(find.text('Esta franja ya no tiene cupos.')), findsOneWidget);
      expect(_enHoja(find.text('12:00 – 13:00')), findsOneWidget);
      expect(_enHoja(find.text('09:00 – 10:00')), findsOneWidget);
      // Reintentar no serviría de nada.
      expect(_enHoja(find.text('Reintentar')), findsNothing);
      expect(repo.reservas, isEmpty);
    });

    testWidgets('si falla la red permite reintentar', (WidgetTester tester) async {
      final _ReservasFalsas repo = _ReservasFalsas(franjas: _franjasDePrueba())
        ..fallosPorVenir = 1;
      await _abrir(tester, repo);

      await _tocar(tester, find.text('12:00 – 13:00'));
      await _tocar(tester, find.text('Fuerza'));
      await _tocar(tester, find.widgetWithText(FilledButton, 'Reservar'));

      expect(_enHoja(find.text('No se pudo reservar')), findsOneWidget);
      expect(_enHoja(find.textContaining('Revisa tu conexión')), findsOneWidget);
      expect(repo.reservas, isEmpty);

      await _tocar(tester, find.text('Reintentar'));

      expect(find.text('Reserva confirmada'), findsOneWidget);
      expect(repo.reservas, hasLength(1));
    });

    testWidgets('reintentar una reserva que sí se hizo no la duplica',
        (WidgetTester tester) async {
      // Se corta la red justo después de que la base guardó la reserva.
      final _ReservasFalsas repo = _ReservasFalsas(franjas: _franjasDePrueba())
        ..fallosPorVenir = 1
        ..aplicarAntesDeFallar = true;
      await _abrir(tester, repo);

      await _tocar(tester, find.text('12:00 – 13:00'));
      await _tocar(tester, find.text('Fuerza'));
      await _tocar(tester, find.widgetWithText(FilledButton, 'Reservar'));

      expect(_enHoja(find.text('No se pudo reservar')), findsOneWidget);
      expect(repo.reservas, hasLength(1));

      await _tocar(tester, find.text('Reintentar'));

      expect(find.text('Ya tenías esta reserva'), findsOneWidget);
      expect(find.text('Código 00000001'), findsOneWidget);
      expect(repo.reservas, hasLength(1));
    });

    testWidgets('reserva recurrente: confirma lo que puede y explica el resto',
        (WidgetTester tester) async {
      final _ReservasFalsas repo = _ReservasFalsas(franjas: _franjasDePrueba());
      await _abrir(tester, repo);

      await _tocar(tester, find.text('12:00 – 13:00'));
      await _tocar(tester, find.text('Fuerza'));

      // Sin repetir es una sola fecha.
      expect(_boton(tester, 'Reservar').onPressed, isNotNull);

      await _tocar(tester, find.text('Repetir cada semana'));

      // Cuatro semanas, solo los miércoles.
      expect(
        find.text('Se reservarán 4 fechas: mié 7 oct, mié 14 oct, mié 21 oct, mié 28 oct.'),
        findsOneWidget,
      );

      // También los viernes.
      await _tocar(tester, _enHoja(find.text('vie')));

      expect(
        find.text(
          'Se reservarán 8 fechas: mié 7 oct, vie 9 oct, mié 14 oct, '
          'vie 16 oct, mié 21 oct, vie 23 oct y 2 más.',
        ),
        findsOneWidget,
      );

      await _tocar(tester, find.widgetWithText(FilledButton, 'Reservar 8 fechas'));

      // Una sola llamada a la base, con las 8 franjas de las 12:00.
      expect(repo.pedidos, hasLength(1));
      expect(
        repo.pedidos.single,
        <int>[712, 912, 1412, 1612, 2112, 2312, 2812, 3012],
      );

      // El viernes 16 está lleno y el miércoles 21 cerrado; las otras 6 salen.
      expect(_enHoja(find.text('Reservas confirmadas en parte')), findsOneWidget);
      expect(_enHoja(find.text('Se confirmaron 6 de 8 fechas.')), findsOneWidget);
      expect(_enHoja(find.text('Reservada')), findsNWidgets(6));
      expect(_enHoja(find.text('vie 16 oct · 12:00')), findsOneWidget);
      expect(_enHoja(find.text('Sin cupos')), findsOneWidget);
      expect(_enHoja(find.text('mié 21 oct · 12:00')), findsOneWidget);
      expect(_enHoja(find.text('Franja cerrada')), findsOneWidget);

      expect(repo.reservas, hasLength(6));
      expect(
        repo.reservas.map((Reserva r) => r.franjaId),
        <int>[712, 912, 1412, 2312, 2812, 3012],
      );
      expect(repo.reservas.every((Reserva r) => r.zonaId == 2), isTrue);
    });

    testWidgets('el día de la reserva no se puede quitar de la repetición',
        (WidgetTester tester) async {
      await _abrir(tester, _ReservasFalsas(franjas: _franjasDePrueba()));

      await _tocar(tester, find.text('12:00 – 13:00'));
      await _tocar(tester, find.text('Repetir cada semana'));

      final FilterChip miercoles =
          tester.widget<FilterChip>(find.widgetWithText(FilterChip, 'mié'));
      expect(miercoles.selected, isTrue);
      expect(miercoles.onSelected, isNull);

      // Otro día se puede marcar y desmarcar.
      await _tocar(tester, _enHoja(find.text('vie')));
      expect(find.textContaining('Se reservarán 8 fechas'), findsOneWidget);
      await _tocar(tester, _enHoja(find.text('vie')));
      expect(find.textContaining('Se reservarán 4 fechas'), findsOneWidget);

      // Menos semanas, menos fechas.
      await _tocar(tester, find.text('2 semanas'));
      expect(
        find.text('Se reservarán 2 fechas: mié 7 oct, mié 14 oct.'),
        findsOneWidget,
      );
    });

    testWidgets('"Ver mis reservas" lleva al historial', (WidgetTester tester) async {
      await _abrir(
        tester,
        _ReservasFalsas(franjas: _franjasDePrueba()),
        rutas: <String, WidgetBuilder>{
          Rutas.rf09Historial: (_) =>
              const Scaffold(body: Text('Pantalla del historial')),
        },
      );

      await _tocar(tester, find.text('12:00 – 13:00'));
      await _tocar(tester, find.text('Fuerza'));
      await _tocar(tester, find.widgetWithText(FilledButton, 'Reservar'));
      await _tocar(tester, find.text('Ver mis reservas'));

      expect(find.text('Pantalla del historial'), findsOneWidget);
    });

    testWidgets('la repetición ofrece solo de lunes a viernes y máximo 3 días',
        (WidgetTester tester) async {
      await _abrir(tester, _ReservasFalsas(franjas: _franjasDePrueba()));

      await _tocar(tester, find.text('12:00 – 13:00'));
      await _tocar(tester, find.text('Repetir cada semana'));

      // El fin de semana no abre el gimnasio.
      expect(_enHoja(find.widgetWithText(FilterChip, 'sáb')), findsNothing);
      expect(_enHoja(find.widgetWithText(FilterChip, 'dom')), findsNothing);
      for (final String dia in <String>['lun', 'mar', 'mié', 'jue', 'vie']) {
        expect(_enHoja(find.widgetWithText(FilterChip, dia)), findsOneWidget);
      }

      FilterChip chip(String dia) =>
          tester.widget<FilterChip>(_enHoja(find.widgetWithText(FilterChip, dia)));

      // Miércoles (el de la reserva) + lunes + viernes = 3: ya no caben más.
      await _tocar(tester, _enHoja(find.text('lun')));
      await _tocar(tester, _enHoja(find.text('vie')));

      expect(chip('mar').onSelected, isNull);
      expect(chip('jue').onSelected, isNull);
      // Los marcados sí se pueden quitar (menos el día de la reserva).
      expect(chip('lun').onSelected, isNotNull);

      await _tocar(tester, _enHoja(find.text('lun')));
      expect(chip('mar').onSelected, isNotNull);
    });

    testWidgets('reserva recurrente: la semana que ya tiene 3 no tumba las demás',
        (WidgetTester tester) async {
      // La semana del 12 de octubre ya tiene 3 reservas (lun, mar y jue).
      final _ReservasFalsas repo = _ReservasFalsas(
        franjas: _franjasDePrueba(),
        reservas: <Reserva>[
          _reserva(id: 101, franjaId: 1208, fecha: DateTime(2026, 10, 12)),
          _reserva(id: 102, franjaId: 1308, fecha: DateTime(2026, 10, 13)),
          _reserva(id: 103, franjaId: 1508, fecha: DateTime(2026, 10, 15)),
        ],
      );
      await _abrir(tester, repo);

      await _tocar(tester, find.text('12:00 – 13:00'));
      await _tocar(tester, find.text('Fuerza'));
      await _tocar(tester, find.text('Repetir cada semana'));
      await _tocar(tester, find.widgetWithText(FilledButton, 'Reservar 4 fechas'));

      // Se piden las 4 en una sola llamada. El 14 choca con el máximo de 3
      // por semana y el 21 a las 12:00 está cerrada (ver _cerradas); el 7
      // y el 28 sí quedan.
      expect(repo.pedidos.single, <int>[712, 1412, 2112, 2812]);
      expect(_enHoja(find.text('Se confirmaron 2 de 4 fechas.')), findsOneWidget);
      expect(_enHoja(find.text('mié 14 oct · 12:00')), findsOneWidget);
      expect(
        _enHoja(find.text('Ya tenías 3 reservas esa semana')),
        findsOneWidget,
      );
      expect(_enHoja(find.text('Franja cerrada')), findsOneWidget);
      expect(repo.reservas, hasLength(3 + 2));
      expect(
        repo.reservas.skip(3).map((Reserva r) => r.franjaId),
        <int>[712, 2812],
      );
    });

    testWidgets('cancelar cierra la hoja sin reservar', (WidgetTester tester) async {
      final _ReservasFalsas repo = _ReservasFalsas(franjas: _franjasDePrueba());
      await _abrir(tester, repo);

      await _tocar(tester, find.text('12:00 – 13:00'));
      await _tocar(tester, find.text('Cancelar'));

      expect(find.text('Confirmar reserva'), findsNothing);
      expect(repo.pedidos, isEmpty);
      expect(repo.reservas, isEmpty);
    });
  });
}
