import 'package:flutter/material.dart';

import '../../../core/datos/errores.dart';
import '../../../core/datos/repositorios.dart';
import '../../../core/modelos/reserva.dart';
import '../../../core/modelos/resultado_cancelacion.dart';
import '../../../core/modelos/zona.dart';
import '../../../core/rutas.dart';
import '../reglas_cancelacion.dart';
import '../reglas_reservas.dart';

/// RF3 - Cancelación de reservas
///
/// Módulo: reservas
///
/// Es la pantalla "Mis reservas" del CU03: la lista de reservas activas
/// de la persona, de la más próxima a la más lejana. Cada una dice hasta
/// cuándo se puede cancelar o por qué ya no; al cancelar se pide
/// confirmación y el cupo queda libre en ese mismo momento.
///
/// Reglas que decide la base de datos (supabase/schema.sql,
/// cancelar_reserva):
/// - se cancela hasta 3 horas antes de que empiece la franja; el número lo
///   configura el administrador (tabla configuracion);
/// - una reserva con el ingreso ya registrado por QR no se cancela;
/// - cancelar dos veces no hace daño: la segunda avisa que ya estaba
///   cancelada.
class PantallaCancelarReserva extends StatefulWidget {
  const PantallaCancelarReserva({super.key, this.reloj = ahoraEnColombia});

  /// De dónde sale "ahora" (hora de Colombia). Las pruebas lo cambian para
  /// fijar la fecha.
  final DateTime Function() reloj;

  @override
  State<PantallaCancelarReserva> createState() =>
      _PantallaCancelarReservaState();
}

class _PantallaCancelarReservaState extends State<PantallaCancelarReserva> {
  bool _cargando = true;
  String? _error;

  List<Reserva> _reservas = <Reserva>[];
  List<Zona> _zonas = <Zona>[];
  int _horas = horasAntelacionPorDefecto;

  /// La reserva que se está cancelando en este momento, si hay una.
  int? _cancelando;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  // -------------------------------------------------------------------
  // Datos
  // -------------------------------------------------------------------

  /// Trae las reservas desde hoy, el plazo para cancelar y, la primera
  /// vez, las zonas. Con [silencioso] no tapa la pantalla con el indicador
  /// de carga; si falla, avisa con un mensaje y deja lo que ya había.
  Future<void> _cargar({bool silencioso = false}) async {
    if (!silencioso) {
      setState(() {
        _cargando = true;
        _error = null;
      });
    }

    List<Reserva> reservas = <Reserva>[];
    int horas = _horas;
    List<Zona> zonas = _zonas;
    String? fallo;

    try {
      await Future.wait<void>(<Future<void>>[
        Repositorios.reservas
            .misReservas(desde: soloFecha(widget.reloj()))
            .then((List<Reserva> v) => reservas = v),
        Repositorios.reservas
            .horasAntelacionCancelar()
            .then((int v) => horas = v),
        if (_zonas.isEmpty)
          Repositorios.gimnasio.zonas().then((List<Zona> v) => zonas = v),
      ]);
    } on ErrorDeDatos catch (e) {
      fallo = e.mensaje;
    } catch (_) {
      fallo = 'No se pudieron cargar tus reservas. Inténtalo de nuevo.';
    }

    if (!mounted) return;

    if (fallo != null) {
      if (silencioso) {
        _avisar(fallo);
      } else {
        setState(() {
          _cargando = false;
          _error = fallo;
        });
      }
      return;
    }

    setState(() {
      _reservas = reservas;
      _horas = horas;
      _zonas = zonas;
      _cargando = false;
      _error = null;
    });
  }

  String _nombreDeZona(int id) {
    for (final Zona z in _zonas) {
      if (z.id == id) return z.nombre;
    }
    return 'Zona $id';
  }

  void _avisar(String texto) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(texto)));
  }

  // -------------------------------------------------------------------
  // Cancelar
  // -------------------------------------------------------------------

  Future<void> _cancelar(Reserva reserva) async {
    final bool confirmo = await _confirmar(reserva);
    // 5a: no confirmó; se vuelve a la lista sin cambios.
    if (!confirmo || !mounted) return;

    setState(() => _cancelando = reserva.id);

    String mensaje;
    int horas = _horas;
    try {
      final RespuestaCancelacion respuesta =
          await Repositorios.reservas.cancelar(reserva.id);
      mensaje = respuesta.mensaje;
      horas = respuesta.horasAntelacion;
    } on ErrorDeDatos catch (e) {
      mensaje = e.mensaje;
    } catch (_) {
      mensaje = 'No se pudo cancelar la reserva. Inténtalo de nuevo.';
    }

    if (!mounted) return;
    setState(() {
      _cancelando = null;
      _horas = horas;
    });
    _avisar(mensaje);

    // Pase lo que pase, la lista se pone al día con lo que dice la base
    // (por ejemplo, si se canceló desde otro dispositivo).
    await _cargar(silencioso: true);
  }

  Future<bool> _confirmar(Reserva reserva) async {
    final String rango = rangoDeReserva(reserva);
    final String cuando = capitalizar(formatearDiaLargo(reserva.fecha)) +
        (rango.isEmpty ? '' : ', $rango');

    final bool? respuesta = await showDialog<bool>(
      context: context,
      builder: (BuildContext contexto) => AlertDialog(
        title: const Text('¿Cancelar esta reserva?'),
        content: Text(
          '$cuando · ${_nombreDeZona(reserva.zonaId)}.\n\n'
          'El cupo quedará libre para otra persona. Si cambias de idea, '
          'tendrás que reservar de nuevo.',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(contexto).pop(false),
            child: const Text('No, conservarla'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(contexto).pop(true),
            child: const Text('Sí, cancelar'),
          ),
        ],
      ),
    );
    return respuesta ?? false;
  }

  // -------------------------------------------------------------------
  // Pantalla
  // -------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Mis reservas')),
      body: RefreshIndicator(
        onRefresh: () => _cargar(silencioso: true),
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
          children: _contenido(context),
        ),
      ),
    );
  }

  List<Widget> _contenido(BuildContext context) {
    final TextTheme textos = Theme.of(context).textTheme;

    if (_cargando) {
      return const <Widget>[
        Padding(
          padding: EdgeInsets.symmetric(vertical: 40),
          child: Center(
            child:
                CircularProgressIndicator(semanticsLabel: 'Cargando reservas'),
          ),
        ),
      ];
    }

    if (_error != null) {
      return <Widget>[
        _Aviso(texto: _error!),
        const SizedBox(height: 16),
        FilledButton(
          onPressed: () => _cargar(),
          child: const Text('Reintentar'),
        ),
      ];
    }

    final DateTime ahora = widget.reloj();
    final List<Reserva> activas = reservasActivas(_reservas, ahora);

    final Widget regla = Text(
      'Puedes cancelar una reserva hasta ${textoDeHoras(_horas)} antes de '
      'que empiece. Al cancelarla, el cupo queda libre para otra persona.',
      style: textos.bodyMedium,
    );

    if (activas.isEmpty) {
      return <Widget>[
        regla,
        const SizedBox(height: 32),
        const _SinReservas(),
      ];
    }

    return <Widget>[
      regla,
      const SizedBox(height: 16),
      for (final Reserva r in activas)
        _TarjetaDeReserva(
          reserva: r,
          esHoy: mismoDia(r.fecha, ahora),
          nombreDeZona: _nombreDeZona(r.zonaId),
          estado: estadoDeCancelacion(r, ahora: ahora, horas: _horas),
          explicacion:
              explicacionDeCancelacion(r, ahora: ahora, horas: _horas),
          cancelando: _cancelando == r.id,
          // Mientras se cancela una, las demás esperan.
          alCancelar: _cancelando == null ? () => _cancelar(r) : null,
        ),
    ];
  }
}

// ---------------------------------------------------------------------
// Piezas de la pantalla
// ---------------------------------------------------------------------

class _TarjetaDeReserva extends StatelessWidget {
  const _TarjetaDeReserva({
    required this.reserva,
    required this.esHoy,
    required this.nombreDeZona,
    required this.estado,
    required this.explicacion,
    required this.cancelando,
    required this.alCancelar,
  });

  final Reserva reserva;
  final bool esHoy;
  final String nombreDeZona;
  final EstadoDeCancelacion estado;
  final String explicacion;
  final bool cancelando;
  final VoidCallback? alCancelar;

  @override
  Widget build(BuildContext context) {
    final ColorScheme esquema = Theme.of(context).colorScheme;
    final TextTheme textos = Theme.of(context).textTheme;

    final String dia = capitalizar(formatearDiaLargo(reserva.fecha));
    final String rango = rangoDeReserva(reserva);
    final bool sePuede = estado == EstadoDeCancelacion.sePuede;

    final (IconData icono, Color color) = switch (estado) {
      EstadoDeCancelacion.sePuede => (Icons.event_available, esquema.primary),
      EstadoDeCancelacion.fueraDePlazo => (Icons.schedule, esquema.outline),
      EstadoDeCancelacion.yaAsistida => (Icons.how_to_reg, esquema.primary),
    };

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Row(
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
                        esHoy ? 'Hoy · $dia' : dia,
                        style: textos.titleMedium,
                      ),
                      if (rango.isNotEmpty)
                        Text(rango, style: textos.titleSmall),
                      const SizedBox(height: 4),
                      Text(
                        '$nombreDeZona · código '
                        '${codigoCorto(reserva.codigoQr)}',
                        style: textos.bodyMedium
                            ?.copyWith(color: esquema.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(explicacion, style: textos.bodySmall),
            if (estado != EstadoDeCancelacion.yaAsistida) ...<Widget>[
              const SizedBox(height: 10),
              Align(
                alignment: Alignment.centerRight,
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: esquema.error,
                    minimumSize: const Size(0, 44),
                  ),
                  onPressed: sePuede && !cancelando ? alCancelar : null,
                  icon: cancelando
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.event_busy),
                  label:
                      Text(cancelando ? 'Cancelando…' : 'Cancelar reserva'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _SinReservas extends StatelessWidget {
  const _SinReservas();

  @override
  Widget build(BuildContext context) {
    final ColorScheme esquema = Theme.of(context).colorScheme;
    final TextTheme textos = Theme.of(context).textTheme;

    return Column(
      children: <Widget>[
        Icon(Icons.event_note, size: 48, color: esquema.outline),
        const SizedBox(height: 12),
        Text(
          'No tienes reservas próximas.',
          style: textos.titleMedium,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 16),
        FilledButton(
          onPressed: () => Navigator.of(context).pushNamed(Rutas.rf02Reservas),
          child: const Text('Reservar un cupo'),
        ),
      ],
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
