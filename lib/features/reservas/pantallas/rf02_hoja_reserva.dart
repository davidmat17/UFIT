import 'package:flutter/material.dart';

import '../../../core/datos/errores.dart';
import '../../../core/datos/repositorios.dart';
import '../../../core/modelos/franja_disponible.dart';
import '../../../core/modelos/reserva.dart';
import '../../../core/modelos/resultado_reserva.dart';
import '../../../core/modelos/zona.dart';
import '../reglas_reservas.dart';

/// Qué quiere hacer la persona al cerrar la hoja de reserva.
enum SalidaDeLaHoja { cerrada, verMisReservas }

/// Abre la hoja donde se confirma una reserva (RF2): zona, repetición
/// semanal y el resultado, todo en el mismo sitio.
///
/// Se abre desde el calendario con una franja con cupo, o con una franja
/// llena para ofrecer las más cercanas. Devuelve null si la persona la
/// cerró deslizando.
///
/// [alTerminarUnIntento] se llama cada vez que termina un intento de
/// reservar, salga bien o mal, y aunque la hoja ya se haya cerrado: así el
/// calendario siempre se actualiza con lo que de verdad quedó en la base.
Future<SalidaDeLaHoja?> mostrarHojaDeReserva(
  BuildContext context, {
  required FranjaDisponible franja,
  required List<FranjaDisponible> franjasDelDia,
  required List<Zona> zonas,
  required DateTime Function() reloj,
  required VoidCallback alTerminarUnIntento,
  Reserva? reservaDelDia,
}) {
  return showModalBottomSheet<SalidaDeLaHoja>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (BuildContext _) => _HojaDeReserva(
      franja: franja,
      franjasDelDia: franjasDelDia,
      zonas: zonas,
      reloj: reloj,
      alTerminarUnIntento: alTerminarUnIntento,
      reservaDelDia: reservaDelDia,
    ),
  );
}

/// Opciones de duración de una reserva recurrente. El máximo es
/// [maximoDeSemanas].
const List<int> _opcionesDeSemanas = <int>[2, 4, 6, 8];

/// Cuántas fechas se listan antes de resumir el resto ("y 2 más").
const int _fechasVisibles = 6;

enum _Fase {
  /// Eligiendo zona y repetición.
  formulario,

  /// Esperando la respuesta de la base.
  enviando,

  /// La base respondió y hay algo que mostrar: la reserva confirmada o, si
  /// fue recurrente, el resultado de cada fecha.
  terminada,

  /// No se pudo reservar.
  fallida,
}

class _HojaDeReserva extends StatefulWidget {
  const _HojaDeReserva({
    required this.franja,
    required this.franjasDelDia,
    required this.zonas,
    required this.reloj,
    required this.alTerminarUnIntento,
    this.reservaDelDia,
  });

  final FranjaDisponible franja;
  final List<FranjaDisponible> franjasDelDia;
  final List<Zona> zonas;
  final DateTime Function() reloj;
  final VoidCallback alTerminarUnIntento;
  final Reserva? reservaDelDia;

  @override
  State<_HojaDeReserva> createState() => _HojaDeReservaState();
}

class _HojaDeReservaState extends State<_HojaDeReserva> {
  late FranjaDisponible _franja;
  late List<FranjaDisponible> _delDia;

  /// Días de la semana de la repetición (1 = lunes … 7 = domingo).
  late Set<int> _dias;

  Zona? _zona;
  bool _repetir = false;
  int _semanas = semanasPorDefecto;

  _Fase _fase = _Fase.formulario;

  /// Texto del fallo, listo para mostrar.
  String? _mensaje;

  /// Si el fallo fue una respuesta de la base. Es null cuando fue otra cosa
  /// (sin conexión, por ejemplo) y por eso tiene sentido reintentar.
  ResultadoReserva? _motivo;

  /// Si ya se intentó reservar. Distingue "esta franja está llena" (al
  /// abrir la hoja) de "no se pudo reservar" (después de intentar).
  bool _huboIntento = false;

  Reserva? _reserva;
  bool _yaLaTenia = false;
  List<LineaDeResultado> _lineas = <LineaDeResultado>[];
  List<FranjaDisponible> _alternativas = <FranjaDisponible>[];

  @override
  void initState() {
    super.initState();
    _franja = widget.franja;
    _delDia = widget.franjasDelDia;
    _dias = <int>{_franja.fecha.weekday};

    // Con una sola zona no hay nada que elegir.
    final List<Zona> zonas = _zonasActivas;
    if (zonas.length == 1) _zona = zonas.first;

    // Una franja llena no se reserva: se ofrecen las más cercanas.
    if (_estadoDe(_franja) == EstadoDeFranja.llena) {
      _fase = _Fase.fallida;
      _motivo = ResultadoReserva.sinCupo;
      _mensaje = ResultadoReserva.sinCupo.mensaje;
      _alternativas = _alternativasPara(_franja, _delDia);
    }
  }

  // -------------------------------------------------------------------
  // Datos derivados
  // -------------------------------------------------------------------

  List<Zona> get _zonasActivas =>
      widget.zonas.where((Zona z) => z.activa).toList();

  EstadoDeFranja _estadoDe(FranjaDisponible f) => estadoDeFranja(
        f,
        ahora: widget.reloj(),
        reservaDelDia: widget.reservaDelDia,
      );

  List<FranjaDisponible> _alternativasPara(
    FranjaDisponible llena,
    List<FranjaDisponible> delDia,
  ) =>
      sugerirAlternativas(
        llena,
        delDia,
        ahora: widget.reloj(),
        reservaDelDia: widget.reservaDelDia,
      );

  /// Las fechas que se van a reservar: solo la elegida o toda la serie.
  List<DateTime> get _fechas => _repetir
      ? fechasDeRepeticion(
          inicio: _franja.fecha,
          diasSemana: _dias,
          semanas: _semanas,
        )
      : <DateTime>[soloFecha(_franja.fecha)];

  String? _nombreDeZona(int? id) {
    if (id == null) return null;
    for (final Zona z in widget.zonas) {
      if (z.id == id) return z.nombre;
    }
    return 'Zona $id';
  }

  // -------------------------------------------------------------------
  // Acciones
  // -------------------------------------------------------------------

  Future<void> _reservar() async {
    final Zona? zona = _zona;
    if (zona == null) return;

    setState(() {
      _fase = _Fase.enviando;
      _huboIntento = true;
      _mensaje = null;
      _motivo = null;
    });

    final List<DateTime> fechas = _fechas;

    try {
      if (fechas.length > 1) {
        await _reservarSerie(fechas, zona);
      } else {
        await _reservarUna(zona);
      }
    } on ErrorDeDatos catch (e) {
      if (mounted) {
        setState(() {
          _fase = _Fase.fallida;
          _mensaje = e.mensaje;
          _motivo = null;
          _alternativas = <FranjaDisponible>[];
        });
      }
    } catch (_) {
      // Un fallo inesperado no debe dejar la hoja cargando para siempre.
      if (mounted) {
        setState(() {
          _fase = _Fase.fallida;
          _mensaje = ResultadoReserva.desconocido.mensaje;
          _motivo = null;
          _alternativas = <FranjaDisponible>[];
        });
      }
    } finally {
      widget.alTerminarUnIntento();
    }
  }

  Future<void> _reservarUna(Zona zona) async {
    final List<ResultadoPorFranja> respuesta =
        await Repositorios.reservas.reservarFranjas(
      franjaIds: <int>[_franja.franjaId],
      zonaId: zona.id,
    );
    final ResultadoPorFranja r = respuesta.isEmpty
        ? ResultadoPorFranja(
            franjaId: _franja.franjaId,
            resultado: ResultadoReserva.desconocido,
          )
        : respuesta.first;
    if (!mounted) return;

    if (r.exitoso) {
      setState(() {
        _fase = _Fase.terminada;
        _reserva = r.reserva;
        _yaLaTenia = r.resultado == ResultadoReserva.yaReservada;
        _lineas = <LineaDeResultado>[];
      });
      return;
    }

    // Si se llenó mientras la persona decidía, se buscan alternativas con
    // lo que hay ahora en la base, no con lo que se veía en el calendario.
    List<FranjaDisponible> delDia = _delDia;
    if (r.resultado == ResultadoReserva.sinCupo) {
      delDia = await _consultarElDia() ?? delDia;
      if (!mounted) return;
    }

    setState(() {
      _fase = _Fase.fallida;
      _motivo = r.resultado;
      _mensaje = r.resultado.mensaje;
      _delDia = delDia;
      _alternativas = r.resultado == ResultadoReserva.sinCupo
          ? _alternativasPara(_franja, delDia)
          : <FranjaDisponible>[];
    });
  }

  /// Una reserva recurrente son varias reservas normales: se busca la
  /// franja de la misma hora en cada fecha y se piden todas juntas. La base
  /// decide fecha por fecha, así que algunas pueden quedar y otras no.
  Future<void> _reservarSerie(List<DateTime> fechas, Zona zona) async {
    final List<FranjaDisponible> publicadas =
        await Repositorios.reservas.disponibilidad(
      desde: fechas.first,
      hasta: fechas.last,
    );

    final List<ItemDeRepeticion> items = <ItemDeRepeticion>[
      for (final ItemDeRepeticion i in armarRepeticion(
        fechas: fechas,
        horaInicio: _franja.horaInicio,
        franjas: publicadas,
      ))
        // La fecha de la franja que la persona tocó se usa tal cual.
        mismoDia(i.fecha, _franja.fecha)
            ? ItemDeRepeticion(fecha: i.fecha, franja: _franja)
            : i,
    ];

    final List<int> ids = <int>[
      for (final ItemDeRepeticion i in items)
        if (i.franja != null) i.franja!.franjaId,
    ];

    final List<ResultadoPorFranja> respuesta = await Repositorios.reservas
        .reservarFranjas(franjaIds: ids, zonaId: zona.id);
    if (!mounted) return;

    setState(() {
      _fase = _Fase.terminada;
      _reserva = null;
      _lineas = unirResultados(items, respuesta);
    });
  }

  Future<List<FranjaDisponible>?> _consultarElDia() async {
    try {
      return await Repositorios.reservas.disponibilidad(
        desde: _franja.fecha,
        hasta: _franja.fecha,
      );
    } on ErrorDeDatos {
      return null;
    }
  }

  void _cambiarA(FranjaDisponible otra) {
    setState(() {
      _franja = otra;
      _fase = _Fase.formulario;
      _mensaje = null;
      _motivo = null;
      _alternativas = <FranjaDisponible>[];
      _dias = <int>{otra.fecha.weekday};
    });
  }

  void _cerrar([SalidaDeLaHoja salida = SalidaDeLaHoja.cerrada]) {
    Navigator.of(context).pop(salida);
  }

  // -------------------------------------------------------------------
  // Pantallas de la hoja
  // -------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: switch (_fase) {
          _Fase.formulario || _Fase.enviando => _formulario(context),
          _Fase.terminada => _terminada(context),
          _Fase.fallida => _fallida(context),
        },
      ),
    );
  }

  Widget _formulario(BuildContext context) {
    final TextTheme textos = Theme.of(context).textTheme;
    final ColorScheme esquema = Theme.of(context).colorScheme;
    final bool enviando = _fase == _Fase.enviando;
    final List<DateTime> fechas = _fechas;
    final List<Zona> zonas = _zonasActivas;
    final Zona? elegida = _zona;
    final String? descripcion = elegida?.descripcion;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Text('Confirmar reserva', style: textos.titleLarge),
        const SizedBox(height: 12),
        _ResumenDeFranja(franja: _franja),
        const SizedBox(height: 20),
        Text('Zona del gimnasio', style: textos.titleSmall),
        const SizedBox(height: 8),
        if (zonas.isEmpty)
          Text(
            'No hay zonas disponibles por ahora.',
            style: textos.bodyMedium?.copyWith(color: esquema.onSurfaceVariant),
          )
        else ...<Widget>[
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: <Widget>[
              for (final Zona z in zonas)
                FilterChip(
                  label: Text(z.nombre),
                  selected: elegida?.id == z.id,
                  onSelected: enviando
                      ? null
                      : (bool _) => setState(() => _zona = z),
                ),
            ],
          ),
          const SizedBox(height: 6),
          if (elegida == null)
            Text(
              'Elige una zona',
              style: textos.bodySmall?.copyWith(color: esquema.onSurfaceVariant),
            )
          else if (descripcion != null && descripcion.isNotEmpty)
            Text(
              descripcion,
              style: textos.bodySmall?.copyWith(color: esquema.onSurfaceVariant),
            ),
        ],
        const SizedBox(height: 8),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Repetir cada semana'),
          subtitle: const Text('Reserva la misma hora en los días que elijas.'),
          value: _repetir,
          onChanged: enviando ? null : (bool v) => setState(() => _repetir = v),
        ),
        if (_repetir) ..._opcionesDeRepeticion(context, fechas, enviando),
        const SizedBox(height: 20),
        FilledButton(
          onPressed: elegida != null && !enviando ? _reservar : null,
          child: enviando
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    semanticsLabel: 'Reservando',
                  ),
                )
              : Text(
                  fechas.length > 1
                      ? 'Reservar ${fechas.length} fechas'
                      : 'Reservar',
                ),
        ),
        const SizedBox(height: 8),
        TextButton(
          onPressed: enviando ? null : _cerrar,
          child: const Text('Cancelar'),
        ),
      ],
    );
  }

  List<Widget> _opcionesDeRepeticion(
    BuildContext context,
    List<DateTime> fechas,
    bool enviando,
  ) {
    final TextTheme textos = Theme.of(context).textTheme;
    final ColorScheme esquema = Theme.of(context).colorScheme;
    final int diaBase = _franja.fecha.weekday;

    final String lista =
        fechas.take(_fechasVisibles).map(formatearDiaCorto).join(', ');
    final int restantes = fechas.length - _fechasVisibles;

    return <Widget>[
      Text('Días de la semana', style: textos.titleSmall),
      const SizedBox(height: 8),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: <Widget>[
          for (int d = 1; d <= 7; d++)
            FilterChip(
              label: Text(nombreCortoDelDia(d)),
              tooltip: nombreLargoDelDia(d),
              selected: _dias.contains(d),
              // El día de la reserva siempre se incluye.
              onSelected: (enviando || d == diaBase)
                  ? null
                  : (bool marcado) => setState(() {
                        if (marcado) {
                          _dias.add(d);
                        } else {
                          _dias.remove(d);
                        }
                      }),
            ),
        ],
      ),
      const SizedBox(height: 4),
      Text(
        'El día de tu reserva siempre se incluye.',
        style: textos.bodySmall?.copyWith(color: esquema.onSurfaceVariant),
      ),
      const SizedBox(height: 12),
      Text('Durante', style: textos.titleSmall),
      const SizedBox(height: 8),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: <Widget>[
          for (final int s in _opcionesDeSemanas)
            FilterChip(
              label: Text('$s semanas'),
              selected: _semanas == s,
              onSelected:
                  enviando ? null : (bool _) => setState(() => _semanas = s),
            ),
        ],
      ),
      const SizedBox(height: 12),
      Text(
        restantes > 0
            ? 'Se reservarán ${fechas.length} fechas: $lista y $restantes más.'
            : 'Se reservarán ${fechas.length} fechas: $lista.',
        style: textos.bodyMedium,
      ),
    ];
  }

  Widget _terminada(BuildContext context) {
    final TextTheme textos = Theme.of(context).textTheme;
    final ColorScheme esquema = Theme.of(context).colorScheme;

    final bool esSerie = _lineas.isNotEmpty;
    final int confirmadas =
        _lineas.where((LineaDeResultado l) => l.exitoso).length;
    final bool huboExito = !esSerie || confirmadas > 0;

    final String titulo;
    if (!esSerie) {
      titulo = _yaLaTenia ? 'Ya tenías esta reserva' : 'Reserva confirmada';
    } else if (confirmadas == _lineas.length) {
      titulo = 'Reservas confirmadas';
    } else if (confirmadas == 0) {
      titulo = 'No se pudo reservar';
    } else {
      titulo = 'Reservas confirmadas en parte';
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Icon(
          huboExito ? Icons.check_circle : Icons.error_outline,
          size: 48,
          color: huboExito ? esquema.primary : esquema.error,
        ),
        const SizedBox(height: 12),
        Text(titulo, textAlign: TextAlign.center, style: textos.titleLarge),
        const SizedBox(height: 16),
        if (esSerie) ...<Widget>[
          Text(
            resumenDeResultados(_lineas),
            textAlign: TextAlign.center,
            style: textos.bodyMedium?.copyWith(color: esquema.onSurfaceVariant),
          ),
          const SizedBox(height: 12),
          Card(
            margin: EdgeInsets.zero,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              child: Column(
                children: <Widget>[
                  for (final LineaDeResultado l in _lineas) _FilaDeFecha(linea: l),
                ],
              ),
            ),
          ),
        ] else
          _DetalleDeReserva(
            fecha: _reserva?.fecha ?? _franja.fecha,
            franja: _franja,
            zona: _nombreDeZona(_reserva?.zonaId ?? _zona?.id),
            codigo: _reserva == null ? null : codigoCorto(_reserva!.codigoQr),
          ),
        const SizedBox(height: 20),
        FilledButton(
          onPressed: _cerrar,
          child: Text(huboExito ? 'Listo' : 'Cerrar'),
        ),
        if (huboExito) ...<Widget>[
          const SizedBox(height: 8),
          OutlinedButton(
            style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(48),
            ),
            onPressed: () => _cerrar(SalidaDeLaHoja.verMisReservas),
            child: const Text('Ver mis reservas'),
          ),
        ],
      ],
    );
  }

  Widget _fallida(BuildContext context) {
    final TextTheme textos = Theme.of(context).textTheme;
    final ColorScheme esquema = Theme.of(context).colorScheme;

    final bool sinCupo = _motivo == ResultadoReserva.sinCupo;
    final bool sePuedeReintentar = _motivo == null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Text(
          sinCupo && !_huboIntento ? 'Franja sin cupos' : 'No se pudo reservar',
          style: textos.titleLarge,
        ),
        const SizedBox(height: 12),
        _Aviso(texto: _mensaje ?? ResultadoReserva.desconocido.mensaje),
        if (sinCupo) ...<Widget>[
          const SizedBox(height: 20),
          Text('Franjas cercanas con cupo', style: textos.titleSmall),
          const SizedBox(height: 4),
          if (_alternativas.isEmpty)
            Text(
              'No quedan otras franjas con cupo este día.',
              style:
                  textos.bodyMedium?.copyWith(color: esquema.onSurfaceVariant),
            )
          else
            for (final FranjaDisponible a in _alternativas)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.schedule),
                title: Text(formatearRango(a)),
                subtitle: Text(textoDeCupos(a)),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => _cambiarA(a),
              ),
        ],
        const SizedBox(height: 20),
        if (sePuedeReintentar) ...<Widget>[
          FilledButton(
            onPressed: _zona == null ? null : _reservar,
            child: const Text('Reintentar'),
          ),
          const SizedBox(height: 8),
          TextButton(onPressed: _cerrar, child: const Text('Cerrar')),
        ] else
          FilledButton(onPressed: _cerrar, child: const Text('Cerrar')),
      ],
    );
  }
}

// ---------------------------------------------------------------------
// Piezas de la hoja
// ---------------------------------------------------------------------

/// El día, la hora y los cupos de la franja que se va a reservar.
class _ResumenDeFranja extends StatelessWidget {
  const _ResumenDeFranja({required this.franja});

  final FranjaDisponible franja;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          children: <Widget>[
            _FilaDeDetalle(
              icono: Icons.event,
              texto: capitalizar(formatearDiaCompleto(franja.fecha)),
            ),
            _FilaDeDetalle(icono: Icons.schedule, texto: formatearRango(franja)),
            _FilaDeDetalle(
              icono: Icons.group_outlined,
              texto: textoDeCupos(franja),
            ),
          ],
        ),
      ),
    );
  }
}

/// Lo que se muestra cuando una reserva quedó confirmada.
class _DetalleDeReserva extends StatelessWidget {
  const _DetalleDeReserva({
    required this.fecha,
    required this.franja,
    required this.zona,
    required this.codigo,
  });

  final DateTime fecha;
  final FranjaDisponible franja;
  final String? zona;
  final String? codigo;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          children: <Widget>[
            _FilaDeDetalle(
              icono: Icons.event,
              texto: capitalizar(formatearDiaCompleto(fecha)),
            ),
            _FilaDeDetalle(icono: Icons.schedule, texto: formatearRango(franja)),
            if (zona != null)
              _FilaDeDetalle(icono: Icons.fitness_center, texto: zona!),
            if (codigo != null)
              _FilaDeDetalle(
                icono: Icons.confirmation_number_outlined,
                texto: 'Código $codigo',
              ),
          ],
        ),
      ),
    );
  }
}

class _FilaDeDetalle extends StatelessWidget {
  const _FilaDeDetalle({required this.icono, required this.texto});

  final IconData icono;
  final String texto;

  @override
  Widget build(BuildContext context) {
    final ColorScheme esquema = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: <Widget>[
          Icon(icono, size: 20, color: esquema.onSurfaceVariant),
          const SizedBox(width: 12),
          Expanded(child: Text(texto)),
        ],
      ),
    );
  }
}

/// Una fecha de la serie y lo que pasó con ella.
class _FilaDeFecha extends StatelessWidget {
  const _FilaDeFecha({required this.linea});

  final LineaDeResultado linea;

  @override
  Widget build(BuildContext context) {
    final ColorScheme esquema = Theme.of(context).colorScheme;
    final bool bien = linea.exitoso;
    final String? hora = linea.horaInicio;

    return ListTile(
      contentPadding: EdgeInsets.zero,
      dense: true,
      leading: Icon(
        bien ? Icons.check_circle_outline : Icons.cancel_outlined,
        color: bien ? esquema.primary : esquema.error,
      ),
      title: Text(
        hora == null
            ? formatearDiaCorto(linea.fecha)
            : '${formatearDiaCorto(linea.fecha)} · ${horaCorta(hora)}',
      ),
      subtitle: Text(etiquetaDeLinea(linea)),
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
