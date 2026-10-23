import 'package:flutter/material.dart';

import '../../../core/datos/errores.dart';
import '../../../core/datos/repositorios.dart';
import '../../../core/modelos/franja_disponible.dart';
import '../../../core/modelos/reserva.dart';
import '../../../core/modelos/zona.dart';
import '../../../core/rutas.dart';
import '../reglas_reservas.dart';
import 'rf02_hoja_reserva.dart';

/// RF2 - Gestión de reservas de cupos en franjas horarias
///
/// Módulo: reservas
///
/// La persona elige un día de la semana, ve las franjas con sus cupos y
/// reserva la que quiera, una sola vez o repetida cada semana. Cada día
/// lleva una marca (con cupo, sin cupo, con reserva) para no tener que
/// abrirlos todos.
///
/// Este archivo es el calendario. La confirmación de la reserva —zona,
/// repetición y resultado— está en rf02_hoja_reserva.dart.
///
/// Reglas que se ven aquí y las decide la base de datos
/// (supabase/schema.sql, reservar_cupos):
/// - el aforo es de 75 personas por franja, en total entre las tres zonas;
///   la zona se guarda con la reserva pero no reparte el cupo;
/// - solo se permite una reserva por persona y día;
/// - una franja en curso todavía se puede reservar.
class PantallaReservas extends StatefulWidget {
  const PantallaReservas({super.key, this.reloj = ahoraEnColombia});

  /// De dónde sale "ahora" (hora de Colombia). Las pruebas lo cambian para
  /// fijar la fecha.
  final DateTime Function() reloj;

  @override
  State<PantallaReservas> createState() => _PantallaReservasState();
}

class _PantallaReservasState extends State<PantallaReservas> {
  late final DateTime _hoy;

  /// Lunes de la semana que se está viendo.
  late DateTime _lunes;

  /// Día elegido dentro de esa semana.
  late DateTime _dia;

  bool _cargando = true;
  String? _error;

  /// Las franjas de la semana que se ve.
  List<FranjaDisponible> _franjas = <FranjaDisponible>[];

  /// Las reservas vivas de la persona esa semana, por fecha (AAAA-MM-DD).
  Map<String, Reserva> _reservasPorDia = <String, Reserva>{};

  List<Zona> _zonas = <Zona>[];

  @override
  void initState() {
    super.initState();
    _hoy = soloFecha(widget.reloj());
    _lunes = lunesDeLaSemana(_hoy);
    _dia = _hoy;
    _cargar();
  }

  // -------------------------------------------------------------------
  // Datos
  // -------------------------------------------------------------------

  /// Trae las franjas, las reservas de la persona y, la primera vez, las
  /// zonas. Con [silencioso] no tapa la pantalla con el indicador de carga
  /// (al deslizar para actualizar y al volver de reservar); si falla, avisa
  /// con un mensaje y deja lo que ya había.
  Future<void> _cargar({bool silencioso = false}) async {
    final DateTime lunes = _lunes;
    final DateTime domingo = DateTime(lunes.year, lunes.month, lunes.day + 6);

    if (!silencioso) {
      setState(() {
        _cargando = true;
        _error = null;
      });
    }

    List<FranjaDisponible> franjas = <FranjaDisponible>[];
    List<Reserva> reservas = <Reserva>[];
    List<Zona> zonas = _zonas;
    String? fallo;

    try {
      await Future.wait<void>(<Future<void>>[
        Repositorios.reservas
            .disponibilidad(desde: lunes, hasta: domingo)
            .then((List<FranjaDisponible> v) => franjas = v),
        Repositorios.reservas
            .misReservas(desde: lunes, hasta: domingo)
            .then((List<Reserva> v) => reservas = v),
        if (_zonas.isEmpty)
          Repositorios.gimnasio.zonas().then((List<Zona> v) => zonas = v),
      ]);
    } on ErrorDeDatos catch (e) {
      fallo = e.mensaje;
    } catch (_) {
      fallo = 'No se pudo cargar el calendario. Inténtalo de nuevo.';
    }

    if (!mounted) return;
    // La persona pudo cambiar de semana mientras esperaba: esta respuesta
    // ya no es la que se necesita.
    if (!mismoDia(lunes, _lunes)) return;

    if (fallo != null) {
      if (silencioso) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(fallo)));
      } else {
        setState(() {
          _cargando = false;
          _error = fallo;
        });
      }
      return;
    }

    setState(() {
      _franjas = franjas;
      _reservasPorDia = reservasVivasPorDia(reservas);
      _zonas = zonas;
      _cargando = false;
      _error = null;
    });
  }

  List<FranjaDisponible> _franjasDe(DateTime dia) =>
      _franjas.where((FranjaDisponible f) => mismoDia(f.fecha, dia)).toList();

  String _nombreDeZona(int id) {
    for (final Zona z in _zonas) {
      if (z.id == id) return z.nombre;
    }
    return 'Zona $id';
  }

  // -------------------------------------------------------------------
  // Navegación entre semanas y días
  // -------------------------------------------------------------------

  DateTime get _lunesMinimo => lunesDeLaSemana(_hoy);

  DateTime get _lunesMaximo => DateTime(
        _lunesMinimo.year,
        _lunesMinimo.month,
        _lunesMinimo.day + 7 * (horizonteEnSemanas - 1),
      );

  bool get _hayAnterior => _lunes.isAfter(_lunesMinimo);

  bool get _haySiguiente => _lunes.isBefore(_lunesMaximo);

  void _irASemana(int cambio) {
    final DateTime nuevo =
        DateTime(_lunes.year, _lunes.month, _lunes.day + 7 * cambio);

    setState(() {
      _lunes = nuevo;
      // En la semana actual se queda en hoy; en las demás, en el lunes.
      _dia = nuevo.isAfter(_hoy) ? nuevo : _hoy;
      _franjas = <FranjaDisponible>[];
      _reservasPorDia = <String, Reserva>{};
    });
    _cargar();
  }

  void _elegirDia(DateTime dia) => setState(() => _dia = dia);

  // -------------------------------------------------------------------
  // Reservar
  // -------------------------------------------------------------------

  Future<void> _abrirFranja(FranjaDisponible franja) async {
    final SalidaDeLaHoja? salida = await mostrarHojaDeReserva(
      context,
      franja: franja,
      franjasDelDia: _franjasDe(franja.fecha),
      zonas: _zonas,
      reloj: widget.reloj,
      reservaDelDia: _reservasPorDia[fechaIso(franja.fecha)],
      alTerminarUnIntento: () {
        if (mounted) _cargar(silencioso: true);
      },
    );

    if (salida == SalidaDeLaHoja.verMisReservas && mounted) {
      _abrirMisReservas();
    }
  }

  /// "Mis reservas" (RF3). Al volver se recarga: pudo haber cancelado.
  Future<void> _abrirMisReservas() async {
    await Navigator.of(context).pushNamed(Rutas.rf03CancelarReserva);
    if (mounted) _cargar(silencioso: true);
  }

  // -------------------------------------------------------------------
  // Pantalla
  // -------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final DateTime ahora = widget.reloj();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Reservar cupo'),
        actions: <Widget>[
          IconButton(
            tooltip: 'Mis reservas',
            icon: const Icon(Icons.event_note),
            onPressed: _abrirMisReservas,
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => _cargar(silencioso: true),
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
          children: <Widget>[
            _encabezadoDeSemana(context),
            const SizedBox(height: 8),
            _tiraDeSemana(ahora),
            const SizedBox(height: 12),
            const _Leyenda(),
            const SizedBox(height: 20),
            ..._contenidoDelDia(context, ahora),
          ],
        ),
      ),
    );
  }

  Widget _encabezadoDeSemana(BuildContext context) {
    final TextTheme textos = Theme.of(context).textTheme;

    return Row(
      children: <Widget>[
        IconButton(
          tooltip: 'Semana anterior',
          icon: const Icon(Icons.chevron_left),
          onPressed: _hayAnterior ? () => _irASemana(-1) : null,
        ),
        Expanded(
          child: Text(
            formatearSemana(_lunes),
            textAlign: TextAlign.center,
            style: textos.titleSmall,
          ),
        ),
        IconButton(
          tooltip: 'Semana siguiente',
          icon: const Icon(Icons.chevron_right),
          onPressed: _haySiguiente ? () => _irASemana(1) : null,
        ),
      ],
    );
  }

  Widget _tiraDeSemana(DateTime ahora) {
    return Row(
      children: <Widget>[
        for (final DateTime d in semanaDesde(_lunes))
          Expanded(
            child: _CeldaDeDia(
              dia: d,
              estado: estadoDelDia(
                franjasDelDia: _franjasDe(d),
                ahora: ahora,
                reservaDelDia: _reservasPorDia[fechaIso(d)],
              ),
              seleccionado: mismoDia(d, _dia),
              esHoy: mismoDia(d, _hoy),
              alTocar: () => _elegirDia(d),
            ),
          ),
      ],
    );
  }

  List<Widget> _contenidoDelDia(BuildContext context, DateTime ahora) {
    final TextTheme textos = Theme.of(context).textTheme;

    final String nombreDelDia = capitalizar(formatearDiaLargo(_dia));
    final Widget titulo = Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        mismoDia(_dia, _hoy) ? 'Hoy · $nombreDelDia' : nombreDelDia,
        style: textos.titleMedium,
      ),
    );

    if (_cargando) {
      return <Widget>[
        titulo,
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 40),
          child: Center(
            child: CircularProgressIndicator(semanticsLabel: 'Cargando franjas'),
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

    final List<FranjaDisponible> delDia = _franjasDe(_dia);
    if (delDia.isEmpty) {
      return <Widget>[titulo, const _SinFranjas()];
    }

    final Reserva? propia = _reservasPorDia[fechaIso(_dia)];

    return <Widget>[
      titulo,
      if (propia != null) ...<Widget>[
        _AvisoDeReserva(texto: _textoDeReservaDelDia(propia)),
        const SizedBox(height: 12),
      ],
      for (final FranjaDisponible f in delDia) _tarjeta(f, ahora, propia),
    ];
  }

  String _textoDeReservaDelDia(Reserva propia) {
    FranjaDisponible? reservada;
    for (final FranjaDisponible f in _franjas) {
      if (f.franjaId == propia.franjaId) reservada = f;
    }
    final String cuando = reservada == null
        ? ''
        : ', de ${horaCorta(reservada.horaInicio)} a '
            '${horaCorta(reservada.horaFin)}';

    return 'Ya tienes una reserva este día$cuando. Solo se permite una por '
        'día; cancélala si quieres cambiarla.';
  }

  Widget _tarjeta(FranjaDisponible franja, DateTime ahora, Reserva? propia) {
    final EstadoDeFranja estado =
        estadoDeFranja(franja, ahora: ahora, reservaDelDia: propia);
    final bool sePuedeTocar =
        estado == EstadoDeFranja.disponible || estado == EstadoDeFranja.llena;

    return _TarjetaDeFranja(
      franja: franja,
      estado: estado,
      enCurso: franjaEnCurso(franja, ahora),
      reserva: estado == EstadoDeFranja.tuya ? propia : null,
      nombreDeZona: estado == EstadoDeFranja.tuya && propia != null
          ? _nombreDeZona(propia.zonaId)
          : null,
      alTocar: sePuedeTocar ? () => _abrirFranja(franja) : null,
    );
  }
}

// ---------------------------------------------------------------------
// La tira de la semana
// ---------------------------------------------------------------------

/// El icono, el color y la frase que lleva cada día en la tira. El color
/// nunca va solo: siempre hay un icono distinto y una frase para quien
/// lee la pantalla con un lector.
(IconData, Color, String) _marcaDelDia(EstadoDelDia estado, ColorScheme esquema) {
  return switch (estado) {
    EstadoDelDia.conCupo => (Icons.check_circle, esquema.primary, 'hay cupos'),
    EstadoDelDia.sinCupo => (Icons.cancel, esquema.error, 'sin cupos'),
    EstadoDelDia.conReserva => (
        Icons.event_available,
        esquema.primary,
        'tienes una reserva',
      ),
    EstadoDelDia.pasado => (Icons.history, esquema.outline, 'ya terminó'),
    EstadoDelDia.sinFranjas => (
        Icons.remove,
        esquema.outline,
        'sin franjas publicadas',
      ),
  };
}

class _CeldaDeDia extends StatelessWidget {
  const _CeldaDeDia({
    required this.dia,
    required this.estado,
    required this.seleccionado,
    required this.esHoy,
    required this.alTocar,
  });

  final DateTime dia;
  final EstadoDelDia estado;
  final bool seleccionado;
  final bool esHoy;
  final VoidCallback alTocar;

  @override
  Widget build(BuildContext context) {
    final ColorScheme esquema = Theme.of(context).colorScheme;
    final TextTheme textos = Theme.of(context).textTheme;
    final (IconData icono, Color color, String frase) =
        _marcaDelDia(estado, esquema);

    final Color colorDelTexto =
        seleccionado ? esquema.onPrimaryContainer : esquema.onSurface;

    return Semantics(
      button: true,
      selected: seleccionado,
      excludeSemantics: true,
      label: '${capitalizar(formatearDiaLargo(dia))}'
          '${esHoy ? ', hoy' : ''}. $frase',
      onTap: alTocar,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 2),
        child: Material(
          color: seleccionado ? esquema.primaryContainer : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: alTocar,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Column(
                children: <Widget>[
                  Text(
                    nombreCortoDelDia(dia.weekday),
                    style: textos.labelSmall?.copyWith(color: colorDelTexto),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${dia.day}',
                    style: textos.titleMedium?.copyWith(
                      color: colorDelTexto,
                      fontWeight: esHoy ? FontWeight.w700 : FontWeight.w400,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Icon(icono, size: 16, color: color),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Leyenda extends StatelessWidget {
  const _Leyenda();

  @override
  Widget build(BuildContext context) {
    final ColorScheme esquema = Theme.of(context).colorScheme;
    final TextStyle? estilo = Theme.of(context).textTheme.bodySmall;

    Widget elemento(IconData icono, Color color, String texto) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(icono, size: 16, color: color),
          const SizedBox(width: 4),
          Text(texto, style: estilo),
        ],
      );
    }

    return Wrap(
      spacing: 16,
      runSpacing: 4,
      children: <Widget>[
        elemento(Icons.check_circle, esquema.primary, 'Con cupo'),
        elemento(Icons.cancel, esquema.error, 'Sin cupo'),
        elemento(Icons.remove_circle_outline, esquema.outline, 'Cerrada o terminada'),
      ],
    );
  }
}

// ---------------------------------------------------------------------
// Las franjas del día
// ---------------------------------------------------------------------

class _TarjetaDeFranja extends StatelessWidget {
  const _TarjetaDeFranja({
    required this.franja,
    required this.estado,
    required this.enCurso,
    this.reserva,
    this.nombreDeZona,
    this.alTocar,
  });

  final FranjaDisponible franja;
  final EstadoDeFranja estado;
  final bool enCurso;

  /// La reserva de la persona, solo cuando la franja es la suya.
  final Reserva? reserva;
  final String? nombreDeZona;

  /// null cuando la franja no se puede tocar (cerrada, terminada...).
  final VoidCallback? alTocar;

  String _detalleDeTuya() {
    final Reserva? r = reserva;
    if (r == null) return 'Tu reserva';
    return 'Tu reserva · ${nombreDeZona ?? 'Zona ${r.zonaId}'} · '
        'código ${codigoCorto(r.codigoQr)}';
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme esquema = Theme.of(context).colorScheme;
    final TextTheme textos = Theme.of(context).textTheme;

    final String cupos = textoDeCupos(franja);
    final String detalleDisponible = enCurso ? 'En curso · $cupos' : cupos;
    final bool esTuya = estado == EstadoDeFranja.tuya;

    final (IconData icono, Color color, String detalle, String? accion) =
        switch (estado) {
      EstadoDeFranja.disponible => (
          Icons.check_circle_outline,
          esquema.primary,
          detalleDisponible,
          'Reservar',
        ),
      EstadoDeFranja.llena => (
          Icons.block,
          esquema.error,
          'Sin cupos',
          'Ver cercanas',
        ),
      EstadoDeFranja.cerrada => (
          Icons.lock_outline,
          esquema.outline,
          'Cerrada',
          null,
        ),
      EstadoDeFranja.pasada => (
          Icons.history,
          esquema.outline,
          'Ya terminó',
          null,
        ),
      EstadoDeFranja.tuya => (
          Icons.event_available,
          esquema.onPrimaryContainer,
          _detalleDeTuya(),
          null,
        ),
      EstadoDeFranja.conOtraReserva => (
          Icons.remove_circle_outline,
          esquema.outline,
          cupos,
          null,
        ),
    };

    final bool apagada = estado == EstadoDeFranja.cerrada ||
        estado == EstadoDeFranja.pasada ||
        estado == EstadoDeFranja.conOtraReserva;

    final Color colorDelTitulo = esTuya
        ? esquema.onPrimaryContainer
        : (apagada ? esquema.onSurfaceVariant : esquema.onSurface);
    final Color colorDelDetalle =
        esTuya ? esquema.onPrimaryContainer : esquema.onSurfaceVariant;

    return Semantics(
      button: alTocar != null,
      excludeSemantics: true,
      label: '${formatearRango(franja)}. $detalle',
      onTap: alTocar,
      child: Card(
        clipBehavior: Clip.antiAlias,
        color: esTuya ? esquema.primaryContainer : null,
        margin: const EdgeInsets.only(bottom: 8),
        child: InkWell(
          onTap: alTocar,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: <Widget>[
                Icon(icono, color: color),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        formatearRango(franja),
                        style: textos.titleMedium?.copyWith(color: colorDelTitulo),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        detalle,
                        style: textos.bodySmall?.copyWith(color: colorDelDetalle),
                      ),
                    ],
                  ),
                ),
                if (accion != null) ...<Widget>[
                  const SizedBox(width: 8),
                  Text(
                    accion,
                    style: textos.labelLarge?.copyWith(color: color),
                  ),
                  Icon(Icons.chevron_right, color: color),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SinFranjas extends StatelessWidget {
  const _SinFranjas();

  @override
  Widget build(BuildContext context) {
    final ColorScheme esquema = Theme.of(context).colorScheme;
    final TextTheme textos = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 32),
      child: Column(
        children: <Widget>[
          Icon(Icons.event_busy, size: 40, color: esquema.outline),
          const SizedBox(height: 12),
          Text(
            'No hay franjas publicadas para este día.',
            textAlign: TextAlign.center,
            style: textos.bodyMedium?.copyWith(color: esquema.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------
// Avisos
// ---------------------------------------------------------------------

/// "Ya tienes una reserva este día": explica por qué las otras franjas no
/// se pueden tocar, sin repetirlo en cada una.
class _AvisoDeReserva extends StatelessWidget {
  const _AvisoDeReserva({required this.texto});

  final String texto;

  @override
  Widget build(BuildContext context) {
    final ColorScheme esquema = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: esquema.primaryContainer,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(Icons.event_available, size: 20, color: esquema.onPrimaryContainer),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              texto,
              style: TextStyle(color: esquema.onPrimaryContainer),
            ),
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
            child: Text(texto, style: TextStyle(color: esquema.onErrorContainer)),
          ),
        ],
      ),
    );
  }
}
