import 'package:flutter/material.dart';

import '../../../core/datos/errores.dart';
import '../../../core/datos/repositorios.dart';
import '../../../core/modelos/reserva.dart';
import '../../../core/modelos/rutina.dart';
import '../../../core/modelos/zona.dart';
import '../reglas_cancelacion.dart';
import '../reglas_historial.dart';
import '../reglas_reservas.dart';

/// RF9 - Consulta de historial de asistencia y reservas
///
/// Módulo: reservas
///
/// CU09: muestra las reservas del mes en curso, de la más reciente a la
/// más antigua, con su estado (asistida, no asistida, cancelada o
/// próxima), la hora del ingreso y las rutinas que tocaban ese día. Se
/// puede pasar de mes o filtrar por un rango de fechas. Arriba va un
/// resumen con el porcentaje de asistencia.
///
/// No modifica nada: es solo lectura sobre las mismas reservas y
/// asistencias que registran el RF2 y el RF4.
class PantallaHistorial extends StatefulWidget {
  const PantallaHistorial({super.key, this.reloj = ahoraEnColombia});

  /// De dónde sale "ahora" (hora de Colombia). Las pruebas lo cambian.
  final DateTime Function() reloj;

  @override
  State<PantallaHistorial> createState() => _PantallaHistorialState();
}

class _PantallaHistorialState extends State<PantallaHistorial> {
  late RangoDeFechas _rango = RangoDeFechas.mes(widget.reloj());

  bool _cargando = true;
  String? _error;

  List<Reserva> _reservas = <Reserva>[];
  List<Zona> _zonas = <Zona>[];
  List<Rutina> _rutinas = <Rutina>[];

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    setState(() {
      _cargando = true;
      _error = null;
    });

    List<Reserva> reservas = <Reserva>[];
    List<Zona> zonas = _zonas;
    List<Rutina> rutinas = _rutinas;
    String? fallo;

    try {
      await Future.wait<void>(<Future<void>>[
        Repositorios.reservas
            .misReservas(desde: _rango.desde, hasta: _rango.hasta)
            .then((List<Reserva> v) => reservas = v),
        if (_zonas.isEmpty)
          Repositorios.gimnasio.zonas().then((List<Zona> v) => zonas = v),
      ]);
      // Las rutinas son un complemento: si fallan, el historial igual se
      // muestra.
      try {
        rutinas = await Repositorios.entrenamiento.misRutinas();
      } catch (_) {
        rutinas = _rutinas;
      }
    } on ErrorDeDatos catch (e) {
      fallo = e.mensaje;
    } catch (_) {
      fallo = 'No se pudo cargar tu historial. Inténtalo de nuevo.';
    }

    if (!mounted) return;
    setState(() {
      _cargando = false;
      _error = fallo;
      if (fallo == null) {
        _reservas = ordenarParaHistorial(reservas);
        _zonas = zonas;
        _rutinas = rutinas;
      }
    });
  }

  void _cambiarRango(RangoDeFechas nuevo) {
    final String? problema = validarRango(nuevo.desde, nuevo.hasta);
    if (problema != null) {
      // CU09, 3a: no aplica el filtro.
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(problema)));
      return;
    }
    setState(() => _rango = nuevo);
    _cargar();
  }

  Future<void> _elegirFechas() async {
    final DateTime hoy = soloFecha(widget.reloj());
    final DateTimeRange? elegido = await showDateRangePicker(
      context: context,
      firstDate: DateTime(hoy.year - 1),
      lastDate: DateTime(hoy.year, hoy.month + 3),
      initialDateRange: DateTimeRange(start: _rango.desde, end: _rango.hasta),
      helpText: 'Filtrar historial',
      saveText: 'Aplicar',
    );
    if (elegido == null || !mounted) return;
    _cambiarRango(RangoDeFechas(elegido.start, elegido.end));
  }

  String _nombreDeZona(int id) {
    for (final Zona z in _zonas) {
      if (z.id == id) return z.nombre;
    }
    return 'Zona $id';
  }

  @override
  Widget build(BuildContext context) {
    final TextTheme textos = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mi historial'),
        actions: <Widget>[
          IconButton(
            tooltip: 'Filtrar por fechas',
            icon: const Icon(Icons.date_range),
            onPressed: _cargando ? null : _elegirFechas,
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _cargar,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
          children: <Widget>[
            Row(
              children: <Widget>[
                IconButton(
                  tooltip: 'Mes anterior',
                  icon: const Icon(Icons.chevron_left),
                  onPressed: _cargando
                      ? null
                      : () => _cambiarRango(_rango.esUnMes
                          ? _rango.mesAnterior()
                          : RangoDeFechas.mes(_rango.desde)),
                ),
                Expanded(
                  child: Text(
                    _rango.titulo,
                    style: textos.titleMedium,
                    textAlign: TextAlign.center,
                  ),
                ),
                IconButton(
                  tooltip: 'Mes siguiente',
                  icon: const Icon(Icons.chevron_right),
                  onPressed: _cargando
                      ? null
                      : () => _cambiarRango(_rango.esUnMes
                          ? _rango.mesSiguiente()
                          : RangoDeFechas.mes(_rango.hasta)),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ..._contenido(context),
          ],
        ),
      ),
    );
  }

  List<Widget> _contenido(BuildContext context) {
    if (_cargando) {
      return const <Widget>[
        Padding(
          padding: EdgeInsets.symmetric(vertical: 40),
          child: Center(
            child: CircularProgressIndicator(
              semanticsLabel: 'Cargando historial',
            ),
          ),
        ),
      ];
    }

    if (_error != null) {
      return <Widget>[
        _Aviso(texto: _error!),
        const SizedBox(height: 16),
        FilledButton(onPressed: _cargar, child: const Text('Reintentar')),
      ];
    }

    if (_reservas.isEmpty) {
      // CU09, 2b: un mensaje en lugar de una pantalla vacía.
      return const <Widget>[_SinRegistros()];
    }

    final DateTime ahora = widget.reloj();
    return <Widget>[
      _Resumen(resumen: resumir(_reservas, ahora)),
      const SizedBox(height: 16),
      for (final Reserva r in _reservas)
        _FilaDeHistorial(
          reserva: r,
          estado: estadoEnHistorial(r, ahora),
          zona: _nombreDeZona(r.zonaId),
          rutinas: rutinasDelDia(r, _rutinas),
        ),
    ];
  }
}

// ---------------------------------------------------------------------
// Piezas de la pantalla
// ---------------------------------------------------------------------

class _Resumen extends StatelessWidget {
  const _Resumen({required this.resumen});

  final ResumenDeHistorial resumen;

  @override
  Widget build(BuildContext context) {
    final ColorScheme esquema = Theme.of(context).colorScheme;
    final TextTheme textos = Theme.of(context).textTheme;
    final int? porcentaje = resumen.porcentajeDeAsistencia;

    final List<_Parte> partes = <_Parte>[
      _Parte('Asistidas', resumen.asistidas, esquema.primary),
      _Parte('No asistidas', resumen.noAsistidas, esquema.error),
      _Parte('Canceladas', resumen.canceladas, esquema.outline),
      _Parte('Próximas', resumen.proximas, esquema.tertiary),
    ];

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              porcentaje == null
                  ? 'Todavía no tienes reservas pasadas en este periodo'
                  : 'Asististe al $porcentaje % de tus reservas',
              style: textos.titleMedium,
            ),
            const SizedBox(height: 12),
            // Barra apilada: cada parte ocupa lo que le corresponde.
            Semantics(
              label: partes
                  .map((_Parte p) => '${p.nombre}: ${p.cantidad}')
                  .join(', '),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: SizedBox(
                  height: 14,
                  child: Row(
                    children: <Widget>[
                      for (final _Parte p in partes)
                        if (p.cantidad > 0)
                          Expanded(
                            flex: p.cantidad,
                            child: Container(color: p.color),
                          ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 16,
              runSpacing: 6,
              children: <Widget>[
                for (final _Parte p in partes)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          color: p.color,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '${p.nombre}: ${p.cantidad}',
                        style: textos.bodyMedium,
                      ),
                    ],
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Una parte del resumen: nombre, cantidad y color.
class _Parte {
  const _Parte(this.nombre, this.cantidad, this.color);

  final String nombre;
  final int cantidad;
  final Color color;
}

class _FilaDeHistorial extends StatelessWidget {
  const _FilaDeHistorial({
    required this.reserva,
    required this.estado,
    required this.zona,
    required this.rutinas,
  });

  final Reserva reserva;
  final EstadoEnHistorial estado;
  final String zona;
  final List<String> rutinas;

  @override
  Widget build(BuildContext context) {
    final ColorScheme esquema = Theme.of(context).colorScheme;
    final TextTheme textos = Theme.of(context).textTheme;

    final (IconData icono, Color color) = switch (estado) {
      EstadoEnHistorial.asistida => (Icons.how_to_reg, esquema.primary),
      EstadoEnHistorial.noAsistida => (Icons.person_off_outlined, esquema.error),
      EstadoEnHistorial.cancelada => (Icons.event_busy, esquema.outline),
      EstadoEnHistorial.proxima => (Icons.event, esquema.tertiary),
    };

    final String rango = rangoDeReserva(reserva);
    final DateTime? ingreso = reserva.ingresoEn;

    final List<String> lineas = <String>[
      <String>[if (rango.isNotEmpty) rango, zona].join(' · '),
      if (ingreso != null) 'Ingreso a las ${horaDelReloj(ingreso)}',
      if (rutinas.isNotEmpty)
        '${rutinas.length == 1 ? 'Rutina' : 'Rutinas'}: ${rutinas.join(', ')}',
    ];

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Icon(icono, color: color),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    capitalizar(formatearDiaLargo(reserva.fecha)),
                    style: textos.titleSmall,
                  ),
                  for (final String linea in lineas)
                    Text(
                      linea,
                      style: textos.bodyMedium
                          ?.copyWith(color: esquema.onSurfaceVariant),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Text(
              nombreDeEstado(estado),
              style: textos.labelLarge?.copyWith(color: color),
            ),
          ],
        ),
      ),
    );
  }
}

class _SinRegistros extends StatelessWidget {
  const _SinRegistros();

  @override
  Widget build(BuildContext context) {
    final ColorScheme esquema = Theme.of(context).colorScheme;
    final TextTheme textos = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.only(top: 32),
      child: Column(
        children: <Widget>[
          Icon(Icons.history, size: 48, color: esquema.outline),
          const SizedBox(height: 12),
          Text(
            'No tienes reservas en este periodo.',
            style: textos.titleMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 6),
          Text(
            'Aquí aparecerán tus reservas, tus ingresos al gimnasio y las '
            'rutinas de cada día. Prueba con otro mes o con otro rango de '
            'fechas.',
            style: textos.bodyMedium,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _Aviso extends StatelessWidget {
  const _Aviso({required this.texto});

  final String texto;

  @override
  Widget build(BuildContext context) {
    final ColorScheme esquema = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: esquema.errorContainer,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(Icons.info_outline, size: 20, color: esquema.onErrorContainer),
          const SizedBox(width: 10),
          Expanded(
            child:
                Text(texto, style: TextStyle(color: esquema.onErrorContainer)),
          ),
        ],
      ),
    );
  }
}
