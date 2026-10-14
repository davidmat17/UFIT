import 'package:flutter/material.dart';

import '../../../core/datos/errores.dart';
import '../../../core/datos/repositorios.dart';
import '../../../core/modelos/franja_con_instructor.dart';
import '../reglas_instructores.dart';

/// RF7 - Visualización de disponibilidad de instructores
///
/// Módulo: gimnasio
///
/// Sigue el CU07 (HU15): muestra el horario semanal por día y franja; la
/// persona elige un día y ve, en cada franja, el instructor asignado y su
/// especialidad. Al tocar una franja se ve el detalle.
/// - 4a: cada vez que se abre, se cambia de semana o se desliza para
///   actualizar, se consulta la base, así que se ve la asignación más
///   reciente que hizo el administrador.
/// - 4b: si una franja no tiene instructor, dice "Sin instructor asignado"
///   en lugar de dejar el campo vacío.
///
/// Solo muestra de lunes a viernes, que es cuando abre el gimnasio.
class PantallaInstructores extends StatefulWidget {
  const PantallaInstructores({super.key, this.reloj = ahoraEnColombia});

  /// De dónde sale "ahora" (hora de Colombia). Las pruebas lo cambian para
  /// fijar la fecha.
  final DateTime Function() reloj;

  @override
  State<PantallaInstructores> createState() => _PantallaInstructoresState();
}

class _PantallaInstructoresState extends State<PantallaInstructores> {
  /// Lunes de la primera semana que se puede ver.
  late final DateTime _primerLunes;

  /// Lunes de la semana que se está viendo.
  late DateTime _lunes;

  /// Día elegido dentro de esa semana.
  late DateTime _dia;

  bool _cargando = true;
  String? _error;
  List<FranjaConInstructor> _agenda = <FranjaConInstructor>[];

  @override
  void initState() {
    super.initState();
    final DateTime inicio = primerDiaAMostrar(widget.reloj());
    _primerLunes = lunesDeLaSemana(inicio);
    _lunes = _primerLunes;
    _dia = inicio;
    _cargar();
  }

  // -------------------------------------------------------------------
  // Datos
  // -------------------------------------------------------------------

  /// Trae la agenda de la semana que se ve. Con [silencioso] no tapa la
  /// pantalla con el indicador de carga (al deslizar para actualizar); si
  /// falla, avisa con un mensaje y deja lo que ya había.
  Future<void> _cargar({bool silencioso = false}) async {
    final DateTime lunes = _lunes;
    final DateTime viernes = DateTime(lunes.year, lunes.month, lunes.day + 4);

    if (!silencioso) {
      setState(() {
        _cargando = true;
        _error = null;
      });
    }

    List<FranjaConInstructor> agenda = <FranjaConInstructor>[];
    String? fallo;
    try {
      agenda = await Repositorios.gimnasio
          .agendaInstructores(desde: lunes, hasta: viernes);
    } on ErrorDeDatos catch (e) {
      fallo = e.mensaje;
    } catch (_) {
      fallo = 'No se pudo cargar el horario de instructores. '
          'Inténtalo de nuevo.';
    }

    if (!mounted) return;
    // La persona pudo cambiar de semana mientras esperaba.
    if (!mismoDia(lunes, _lunes)) return;

    if (fallo != null && silencioso) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(fallo)));
      return;
    }

    setState(() {
      _cargando = false;
      _error = fallo;
      if (fallo == null) _agenda = agenda;
    });
  }

  bool get _puedeRetroceder => _lunes.isAfter(_primerLunes);

  bool get _puedeAvanzar {
    final DateTime ultimo = DateTime(
      _primerLunes.year,
      _primerLunes.month,
      _primerLunes.day + 7 * horizonteEnSemanas,
    );
    return _lunes.isBefore(ultimo);
  }

  void _cambiarDeSemana(int semanas) {
    setState(() {
      // El mismo día de la semana en la otra semana.
      final int posicion = _dia.weekday - 1;
      _lunes = DateTime(_lunes.year, _lunes.month, _lunes.day + 7 * semanas);
      _dia = DateTime(_lunes.year, _lunes.month, _lunes.day + posicion);
      _agenda = <FranjaConInstructor>[];
    });
    _cargar();
  }

  // -------------------------------------------------------------------
  // Pantalla
  // -------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Instructores')),
      body: Column(
        children: <Widget>[
          _BarraDeSemana(
            texto: semanaDeServicio(_lunes),
            alRetroceder: _puedeRetroceder ? () => _cambiarDeSemana(-1) : null,
            alAvanzar: _puedeAvanzar ? () => _cambiarDeSemana(1) : null,
          ),
          _TiraDeDias(
            dias: diasDeServicio(_lunes),
            elegido: _dia,
            hoy: soloFecha(widget.reloj()),
            alElegir: (DateTime d) => setState(() => _dia = d),
          ),
          const Divider(height: 1),
          Expanded(child: _cuerpo(context)),
        ],
      ),
    );
  }

  Widget _cuerpo(BuildContext context) {
    if (_cargando) return const Center(child: CircularProgressIndicator());

    if (_error != null) {
      return ListView(
        padding: const EdgeInsets.all(24),
        children: <Widget>[
          Text(_error!, textAlign: TextAlign.center),
          const SizedBox(height: 16),
          FilledButton(onPressed: _cargar, child: const Text('Reintentar')),
        ],
      );
    }

    final TextTheme textos = Theme.of(context).textTheme;
    final ColorScheme esquema = Theme.of(context).colorScheme;
    final List<FranjaConInstructor> delDia = agendaDelDia(_agenda, _dia);
    final DateTime ahora = widget.reloj();

    return RefreshIndicator(
      onRefresh: () => _cargar(silencioso: true),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: <Widget>[
          Text(diaLargo(_dia), style: textos.titleLarge),
          const SizedBox(height: 4),
          if (delDia.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 24),
              child: Text(
                'No hay franjas publicadas para este día.',
                textAlign: TextAlign.center,
                style: textos.bodyMedium
                    ?.copyWith(color: esquema.onSurfaceVariant),
              ),
            )
          else ...<Widget>[
            Text(
              resumenDelDia(delDia),
              style:
                  textos.bodyMedium?.copyWith(color: esquema.onSurfaceVariant),
            ),
            const SizedBox(height: 8),
            for (final FranjaConInstructor f in delDia)
              _FilaDeFranja(
                franja: f,
                termino: franjaTermino(f, ahora),
                alTocar: () => _mostrarDetalle(f),
              ),
          ],
        ],
      ),
    );
  }

  /// CU07, pasos 3 y 4: la persona elige una franja y ve el detalle.
  void _mostrarDetalle(FranjaConInstructor f) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (BuildContext context) => _DetalleDeFranja(franja: f),
    );
  }
}

// ---------------------------------------------------------------------
// Piezas de esta pantalla
// ---------------------------------------------------------------------

class _BarraDeSemana extends StatelessWidget {
  const _BarraDeSemana({
    required this.texto,
    required this.alRetroceder,
    required this.alAvanzar,
  });

  final String texto;
  final VoidCallback? alRetroceder;
  final VoidCallback? alAvanzar;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      child: Row(
        children: <Widget>[
          IconButton(
            icon: const Icon(Icons.chevron_left),
            tooltip: 'Semana anterior',
            onPressed: alRetroceder,
          ),
          Expanded(
            child: Text(
              texto,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleSmall,
            ),
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right),
            tooltip: 'Semana siguiente',
            onPressed: alAvanzar,
          ),
        ],
      ),
    );
  }
}

class _TiraDeDias extends StatelessWidget {
  const _TiraDeDias({
    required this.dias,
    required this.elegido,
    required this.hoy,
    required this.alElegir,
  });

  final List<DateTime> dias;
  final DateTime elegido;
  final DateTime hoy;
  final ValueChanged<DateTime> alElegir;

  @override
  Widget build(BuildContext context) {
    final TextTheme textos = Theme.of(context).textTheme;
    final ColorScheme esquema = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
      child: Row(
        children: <Widget>[
          for (final DateTime d in dias)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 3),
                child: Material(
                  color: mismoDia(d, elegido)
                      ? esquema.primaryContainer
                      : Colors.transparent,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: mismoDia(d, hoy)
                        ? BorderSide(color: esquema.primary)
                        : BorderSide.none,
                  ),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () => alElegir(d),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Column(
                        children: <Widget>[
                          Text(diaCorto(d), style: textos.labelMedium),
                          const SizedBox(height: 2),
                          Text('${d.day}', style: textos.titleMedium),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _FilaDeFranja extends StatelessWidget {
  const _FilaDeFranja({
    required this.franja,
    required this.termino,
    required this.alTocar,
  });

  final FranjaConInstructor franja;
  final bool termino;
  final VoidCallback alTocar;

  @override
  Widget build(BuildContext context) {
    final TextTheme textos = Theme.of(context).textTheme;
    final ColorScheme esquema = Theme.of(context).colorScheme;
    final bool tiene = franja.tieneInstructor;
    final String? detalle = detalleDelInstructor(franja);
    final Color apagado = esquema.onSurfaceVariant;

    final List<String> avisos = <String>[
      if (!franja.abierta) 'Cerrada',
      if (termino) 'Ya terminó',
    ];

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        onTap: alTocar,
        leading: Icon(
          tiene ? Icons.person_outline : Icons.person_off_outlined,
          color: tiene && !termino ? esquema.primary : apagado,
        ),
        title: Text(rangoDe(franja)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              textoDelInstructor(franja),
              style: tiene
                  ? textos.bodyMedium?.copyWith(fontWeight: FontWeight.w600)
                  : textos.bodyMedium?.copyWith(color: apagado),
            ),
            if (detalle != null) Text(detalle),
            if (avisos.isNotEmpty)
              Text(
                avisos.join(' · '),
                style: textos.bodySmall?.copyWith(color: apagado),
              ),
          ],
        ),
        trailing: const Icon(Icons.chevron_right),
      ),
    );
  }
}

class _DetalleDeFranja extends StatelessWidget {
  const _DetalleDeFranja({required this.franja});

  final FranjaConInstructor franja;

  @override
  Widget build(BuildContext context) {
    final TextTheme textos = Theme.of(context).textTheme;
    final ColorScheme esquema = Theme.of(context).colorScheme;

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Text(
              '${diaLargo(franja.fecha)} · ${rangoDe(franja)}',
              style: textos.titleMedium,
            ),
            const SizedBox(height: 16),
            if (franja.tieneInstructor) ...<Widget>[
              _Dato(
                icono: Icons.person_outline,
                titulo: 'Instructor',
                valor: franja.instructor!,
              ),
              _Dato(
                icono: Icons.workspace_premium_outlined,
                titulo: 'Especialidad',
                valor: franja.especialidad ?? 'No registrada',
              ),
              Text(
                'Durante esta franja está a cargo de todo el gimnasio: '
                'puedes buscarlo en cualquier zona.',
                style:
                    textos.bodyMedium?.copyWith(color: esquema.onSurfaceVariant),
              ),
            ] else ...<Widget>[
              const _Dato(
                icono: Icons.person_off_outlined,
                titulo: 'Instructor',
                valor: textoSinInstructor,
              ),
              const SizedBox(height: 8),
              Text(
                'En esta franja no hay un instructor acompañando. Puedes '
                'entrenar igual; si necesitas acompañamiento, busca otra '
                'franja.',
                style:
                    textos.bodyMedium?.copyWith(color: esquema.onSurfaceVariant),
              ),
            ],
            if (!franja.abierta) ...<Widget>[
              const SizedBox(height: 8),
              Text(
                'La administración cerró esta franja.',
                style: textos.bodyMedium?.copyWith(color: esquema.error),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _Dato extends StatelessWidget {
  const _Dato({required this.icono, required this.titulo, required this.valor});

  final IconData icono;
  final String titulo;
  final String valor;

  @override
  Widget build(BuildContext context) {
    final TextTheme textos = Theme.of(context).textTheme;
    final ColorScheme esquema = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(icono, color: esquema.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  titulo,
                  style:
                      textos.labelMedium?.copyWith(color: esquema.onSurfaceVariant),
                ),
                Text(valor, style: textos.bodyLarge),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
