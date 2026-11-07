import 'package:flutter/material.dart';

import '../../../core/datos/errores.dart';
import '../../../core/datos/repositorios.dart';
import '../../../core/modelos/perfil.dart';
import '../reglas_admin.dart';
import 'piezas_admin.dart';

/// RF13 - Pestaña "Turnos" del panel de contenidos.
///
/// Asigna un instructor a varios días y horas de una vez, o quita la
/// asignación. Lo que se guarda aquí es lo que el usuario ve en el RF7; una
/// franja sin asignación sale como "sin instructor asignado".
class PestanaTurnos extends StatefulWidget {
  const PestanaTurnos({super.key, this.reloj = ahoraEnColombia});

  final DateTime Function() reloj;

  @override
  State<PestanaTurnos> createState() => _PestanaTurnosState();
}

class _PestanaTurnosState extends State<PestanaTurnos> {
  bool _cargando = true;
  bool _guardando = false;
  String? _error;
  List<Perfil> _instructores = <Perfil>[];

  /// null = quitar la asignación.
  String? _instructorId;
  bool _quitar = false;
  final Set<int> _dias = <int>{1, 2, 3, 4, 5};
  int _horaDesde = horaApertura;
  int _horaHasta = 12;
  late DateTime _desde = soloFecha(widget.reloj());
  late DateTime _hasta = _desde.add(const Duration(days: 27));

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
    try {
      final List<Perfil> personas = await Repositorios.admin.personas();
      if (!mounted) return;
      setState(() {
        _instructores = personas
            .where((Perfil p) => p.rol == RolUsuario.instructor && p.activo)
            .toList();
        if (_instructores.every((Perfil p) => p.id != _instructorId)) {
          _instructorId =
              _instructores.isEmpty ? null : _instructores.first.id;
        }
        _cargando = false;
      });
    } on ErrorDeDatos catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.mensaje;
        _cargando = false;
      });
    }
  }

  Future<void> _elegirFechas() async {
    final DateTime hoy = soloFecha(widget.reloj());
    final DateTimeRange? r = await showDateRangePicker(
      context: context,
      firstDate: hoy,
      lastDate: hoy.add(const Duration(days: 180)),
      initialDateRange: DateTimeRange(start: _desde, end: _hasta),
      helpText: 'Fechas del turno',
      saveText: 'Aplicar',
    );
    if (r == null || !mounted) return;
    setState(() {
      _desde = r.start;
      _hasta = r.end;
    });
  }

  Future<void> _aplicar() async {
    final String? problema = validarTurno(
          dias: _dias,
          horaDesde: _horaDesde,
          horaHasta: _horaHasta,
        ) ??
        validarRangoDeFechas(_desde, _hasta, maximoDias: 62) ??
        (!_quitar && _instructorId == null ? 'Elige un instructor.' : null);
    if (problema != null) {
      mostrarMensaje(context, problema);
      return;
    }

    setState(() => _guardando = true);
    try {
      final int n = await Repositorios.admin.asignarTurno(
        instructorId: _quitar ? null : _instructorId,
        dias: _dias.toList()..sort(),
        horaDesde: _horaDesde,
        horaHasta: _horaHasta,
        desde: _desde,
        hasta: _hasta,
      );
      if (!mounted) return;
      mostrarMensaje(
        context,
        n == 0
            ? 'No hubo cambios: esas franjas ya estaban así o no están '
                'publicadas.'
            : (_quitar
                ? 'Se quitó el instructor de $n franjas.'
                : 'Se asignó el instructor a $n franjas. Ya se ve en el '
                    'horario de instructores.'),
      );
    } on ErrorDeDatos catch (e) {
      if (mounted) mostrarMensaje(context, e.mensaje);
    }
    if (mounted) setState(() => _guardando = false);
  }

  @override
  Widget build(BuildContext context) {
    if (_cargando) return const CargandoAdmin();
    if (_error != null) {
      return ErrorConReintento(mensaje: _error!, alReintentar: _cargar);
    }

    final TextTheme textos = Theme.of(context).textTheme;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      children: <Widget>[
        Text('Asignar turnos de instructores', style: textos.titleMedium),
        const SizedBox(height: 4),
        Text(
          'Un instructor por franja, a cargo de todo el gimnasio. Si la '
          'franja ya tenía otro, se reemplaza.',
          style: textos.bodyMedium,
        ),
        const SizedBox(height: 12),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Quitar la asignación'),
          subtitle: const Text('Las franjas quedan sin instructor asignado.'),
          value: _quitar,
          onChanged: (bool v) => setState(() => _quitar = v),
        ),
        if (!_quitar) ...<Widget>[
          if (_instructores.isEmpty)
            const AvisoAdmin(
              texto: 'No hay instructores activos. Dale el rol de instructor '
                  'a alguien en la pestaña Personas.',
              esError: false,
            )
          else
            DropdownButtonFormField<String>(
              initialValue: _instructorId,
              decoration: const InputDecoration(
                labelText: 'Instructor',
                border: OutlineInputBorder(),
              ),
              items: <DropdownMenuItem<String>>[
                for (final Perfil p in _instructores)
                  DropdownMenuItem<String>(
                    value: p.id,
                    child: Text(p.especialidad == null
                        ? p.nombreCompleto
                        : '${p.nombreCompleto} · ${p.especialidad}'),
                  ),
              ],
              onChanged: (String? v) => setState(() => _instructorId = v),
            ),
        ],
        const SizedBox(height: 16),
        Text('Días', style: textos.titleSmall),
        const SizedBox(height: 6),
        Wrap(
          spacing: 8,
          children: <Widget>[
            for (int d = 1; d <= 5; d++)
              FilterChip(
                label: Text(diasLaborales[d - 1]),
                selected: _dias.contains(d),
                onSelected: (bool si) => setState(() {
                  if (si) {
                    _dias.add(d);
                  } else {
                    _dias.remove(d);
                  }
                }),
              ),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          children: <Widget>[
            Expanded(
              child: DropdownButtonFormField<int>(
                initialValue: _horaDesde,
                decoration: const InputDecoration(
                  labelText: 'Desde',
                  border: OutlineInputBorder(),
                ),
                items: <DropdownMenuItem<int>>[
                  for (int h = horaApertura; h < horaCierre; h++)
                    DropdownMenuItem<int>(value: h, child: Text(horaEntera(h))),
                ],
                onChanged: (int? v) =>
                    setState(() => _horaDesde = v ?? _horaDesde),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: DropdownButtonFormField<int>(
                initialValue: _horaHasta,
                decoration: const InputDecoration(
                  labelText: 'Hasta',
                  border: OutlineInputBorder(),
                ),
                items: <DropdownMenuItem<int>>[
                  for (int h = horaApertura + 1; h <= horaCierre; h++)
                    DropdownMenuItem<int>(value: h, child: Text(horaEntera(h))),
                ],
                onChanged: (int? v) =>
                    setState(() => _horaHasta = v ?? _horaHasta),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        OutlinedButton.icon(
          onPressed: _elegirFechas,
          icon: const Icon(Icons.date_range),
          label: Text('Del ${fechaCorta(_desde)} al ${fechaCorta(_hasta)}'),
        ),
        const SizedBox(height: 20),
        FilledButton(
          onPressed: _guardando ? null : _aplicar,
          child: Text(_guardando
              ? 'Guardando…'
              : (_quitar ? 'Quitar asignación' : 'Asignar turno')),
        ),
      ],
    );
  }
}
