import 'package:flutter/material.dart';

import '../../../core/datos/errores.dart';
import '../../../core/datos/repositorios.dart';
import '../../../core/modelos/maquina.dart';
import '../../../core/modelos/rutina.dart';
import '../reglas_rutinas.dart';

/// RF11 - Formulario de una rutina nueva (CU11, pasos 3 a 7).
///
/// La persona le pone nombre a la rutina y agrega ejercicios. Por cada
/// uno elige la máquina, los días (lunes a viernes) y las repeticiones,
/// los minutos o ambos; las series son opcionales. Al guardar, la rutina se envía completa en una sola
/// llamada; si la red falla, reintentar no la duplica porque se envía el
/// mismo identificador de solicitud.
///
/// Devuelve true al cerrarse si la rutina quedó guardada.
class PantallaNuevaRutina extends StatefulWidget {
  const PantallaNuevaRutina({super.key});

  @override
  State<PantallaNuevaRutina> createState() => _PantallaNuevaRutinaState();
}

/// Un ejercicio ya elegido en el formulario, antes de guardar.
class _LineaEnEdicion {
  const _LineaEnEdicion({
    required this.opcion,
    required this.maquina,
    required this.dias,
    required this.series,
    required this.repeticiones,
    required this.minutos,
  });

  final OpcionDeEjercicio opcion;
  final Maquina maquina;
  final List<int> dias;
  final int? series;
  final int? repeticiones;
  final int? minutos;

  /// "3 series × 12 repeticiones", "20 min"...
  String get carga => textoDeCarga(
        series: series,
        repeticiones: repeticiones,
        minutos: minutos,
      );

  LineaNuevaRutina aLinea() => LineaNuevaRutina(
        ejercicioId: opcion.ejercicio.id,
        maquinaId: maquina.id,
        dias: dias,
        series: series,
        repeticiones: repeticiones,
        minutos: minutos,
      );
}

class _PantallaNuevaRutinaState extends State<PantallaNuevaRutina> {
  final GlobalKey<FormState> _formulario = GlobalKey<FormState>();
  final TextEditingController _nombre = TextEditingController();

  /// Uno por formulario: si la red falla y se reintenta, la base reconoce
  /// la solicitud y no crea otra rutina (CU11, 7d).
  final String _solicitudId = nuevoIdDeSolicitud();

  bool _cargando = true;
  String? _errorCatalogo;
  List<OpcionDeEjercicio> _opciones = <OpcionDeEjercicio>[];

  final List<_LineaEnEdicion> _lineas = <_LineaEnEdicion>[];

  /// Después del primer intento de guardar se muestran los errores que no
  /// son de un campo de texto (la lista de ejercicios vacía).
  bool _intentoGuardar = false;
  bool _guardando = false;

  /// Error del nombre que solo sabe la base (nombre repetido).
  String? _errorDelNombre;

  @override
  void initState() {
    super.initState();
    _cargarCatalogo();
  }

  @override
  void dispose() {
    _nombre.dispose();
    super.dispose();
  }

  Future<void> _cargarCatalogo() async {
    setState(() {
      _cargando = true;
      _errorCatalogo = null;
    });
    try {
      final List<Maquina> maquinas = await Repositorios.gimnasio.maquinas();
      if (!mounted) return;
      setState(() {
        _opciones = opcionesDeEjercicio(maquinas);
        _cargando = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _cargando = false;
        _errorCatalogo = e is ErrorDeDatos
            ? e.mensaje
            : 'No se pudo cargar el catálogo de ejercicios.';
      });
    }
  }

  void _avisar(String texto) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(texto)));
  }

  /// Los ejercicios que todavía no están en la rutina: uno solo puede
  /// estar una vez.
  List<OpcionDeEjercicio> get _opcionesLibres => _opciones
      .where((OpcionDeEjercicio o) => !_lineas.any(
          (_LineaEnEdicion l) => l.opcion.ejercicio.id == o.ejercicio.id))
      .toList();

  bool get _sePuedeAgregar =>
      !_guardando &&
      _lineas.length < maximoEjerciciosPorRutina &&
      _opcionesLibres.isNotEmpty;

  // -------------------------------------------------------------------
  // Acciones
  // -------------------------------------------------------------------

  Future<void> _agregarEjercicio() async {
    final _LineaEnEdicion? linea = await showModalBottomSheet<_LineaEnEdicion>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (BuildContext _) => _HojaDeEjercicio(opciones: _opcionesLibres),
    );
    if (linea == null || !mounted) return;
    setState(() => _lineas.add(linea));
  }

  void _quitar(_LineaEnEdicion linea) => setState(() => _lineas.remove(linea));

  Future<void> _guardar() async {
    setState(() {
      _intentoGuardar = true;
      _errorDelNombre = null;
    });
    final bool camposBien = _formulario.currentState?.validate() ?? false;
    if (!camposBien || _lineas.isEmpty) return;

    setState(() => _guardando = true);

    try {
      final RespuestaCrearRutina r =
          await Repositorios.entrenamiento.crearRutina(
        nombre: _nombre.text.trim(),
        ejercicios: <LineaNuevaRutina>[
          for (final _LineaEnEdicion l in _lineas) l.aLinea(),
        ],
        solicitudId: _solicitudId,
      );
      if (!mounted) return;

      if (r.fueGuardada) {
        Navigator.of(context).pop(true);
        return;
      }

      setState(() => _guardando = false);
      if (r.resultado == ResultadoCrearRutina.nombreRepetido) {
        setState(() => _errorDelNombre = r.mensaje);
        _formulario.currentState?.validate();
      } else {
        _avisar(r.mensaje);
      }
    } on ErrorDeDatos catch (e) {
      if (!mounted) return;
      setState(() => _guardando = false);
      _avisar(e.mensaje);
    } catch (_) {
      if (!mounted) return;
      setState(() => _guardando = false);
      _avisar('No se pudo guardar la rutina. Inténtalo de nuevo.');
    }
  }

  // -------------------------------------------------------------------
  // Pantalla
  // -------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Nueva rutina')),
      body: _cuerpo(context),
    );
  }

  Widget _cuerpo(BuildContext context) {
    final ColorScheme esquema = Theme.of(context).colorScheme;
    final TextTheme textos = Theme.of(context).textTheme;

    if (_cargando) {
      return const Center(
        child: CircularProgressIndicator(semanticsLabel: 'Cargando catálogo'),
      );
    }

    if (_errorCatalogo != null || _opciones.isEmpty) {
      return ListView(
        padding: const EdgeInsets.all(16),
        children: <Widget>[
          Text(
            _errorCatalogo ??
                'No hay ejercicios con máquinas disponibles en el catálogo.',
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: _cargarCatalogo,
            child: const Text('Reintentar'),
          ),
        ],
      );
    }

    return Form(
      key: _formulario,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: <Widget>[
          TextFormField(
            controller: _nombre,
            enabled: !_guardando,
            maxLength: largoMaximoDelNombre,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
              labelText: 'Nombre de la rutina',
              hintText: 'Por ejemplo: Fuerza lunes y miércoles',
              border: OutlineInputBorder(),
            ),
            validator: (String? v) => validarNombre(v) ?? _errorDelNombre,
            onChanged: (String _) {
              if (_errorDelNombre != null) {
                setState(() => _errorDelNombre = null);
              }
            },
          ),
          const SizedBox(height: 12),
          Text(
            'Ejercicios (${_lineas.length} de $maximoEjerciciosPorRutina)',
            style: textos.titleMedium,
          ),
          const SizedBox(height: 8),
          for (final _LineaEnEdicion l in _lineas)
            Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                title: Text(l.opcion.ejercicio.nombre),
                subtitle: Text(
                  '${l.maquina.nombre} · ${textoDeDias(l.dias)}\n'
                  '${l.carga}',
                ),
                isThreeLine: true,
                trailing: IconButton(
                  tooltip: 'Quitar ejercicio',
                  icon: const Icon(Icons.close),
                  onPressed: _guardando ? null : () => _quitar(l),
                ),
              ),
            ),
          if (_intentoGuardar && _lineas.isEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                'Agrega al menos un ejercicio.',
                style: textos.bodySmall?.copyWith(color: esquema.error),
              ),
            ),
          OutlinedButton.icon(
            onPressed: _sePuedeAgregar ? _agregarEjercicio : null,
            icon: const Icon(Icons.add),
            label: const Text('Agregar ejercicio'),
          ),
          const SizedBox(height: 24),
          FilledButton(
            style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
            onPressed: _guardando ? null : _guardar,
            child: _guardando
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Guardar'),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------
// Hoja para agregar un ejercicio
// ---------------------------------------------------------------------

class _HojaDeEjercicio extends StatefulWidget {
  const _HojaDeEjercicio({required this.opciones});

  final List<OpcionDeEjercicio> opciones;

  @override
  State<_HojaDeEjercicio> createState() => _HojaDeEjercicioState();
}

class _HojaDeEjercicioState extends State<_HojaDeEjercicio> {
  final GlobalKey<FormState> _formulario = GlobalKey<FormState>();
  final TextEditingController _series = TextEditingController();
  final TextEditingController _repeticiones = TextEditingController();
  final TextEditingController _minutos = TextEditingController();

  OpcionDeEjercicio? _opcion;
  Maquina? _maquina;
  final Set<int> _dias = <int>{};
  bool _intento = false;

  @override
  void dispose() {
    _series.dispose();
    _repeticiones.dispose();
    _minutos.dispose();
    super.dispose();
  }

  void _elegirEjercicio(OpcionDeEjercicio? o) {
    setState(() {
      _opcion = o;
      // Si el ejercicio se hace en una sola máquina, ya queda elegida.
      _maquina = (o != null && o.maquinas.length == 1) ? o.maquinas.first : null;
    });
  }

  void _agregar() {
    setState(() => _intento = true);
    final bool camposBien = _formulario.currentState?.validate() ?? false;
    final OpcionDeEjercicio? opcion = _opcion;
    final Maquina? maquina = _maquina;
    if (!camposBien ||
        opcion == null ||
        maquina == null ||
        validarDias(_dias) != null ||
        validarRepeticionesOMinutos(_repeticiones.text, _minutos.text) !=
            null) {
      return;
    }

    Navigator.of(context).pop(_LineaEnEdicion(
      opcion: opcion,
      maquina: maquina,
      dias: _dias.toList()..sort(),
      series: numeroOpcional(_series.text),
      repeticiones: numeroOpcional(_repeticiones.text),
      minutos: numeroOpcional(_minutos.text),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme esquema = Theme.of(context).colorScheme;
    final TextTheme textos = Theme.of(context).textTheme;
    final TextStyle? estiloDeError =
        textos.bodySmall?.copyWith(color: esquema.error);

    final String? errorDeDias = _intento ? validarDias(_dias) : null;
    final String? errorDeCarga = _intento
        ? validarRepeticionesOMinutos(_repeticiones.text, _minutos.text)
        : null;
    final String? errorDeMaquina =
        _intento && _opcion != null && _maquina == null
            ? 'Elige una máquina.'
            : null;

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        child: Form(
          key: _formulario,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Text('Agregar ejercicio', style: textos.titleLarge),
              const SizedBox(height: 16),
              DropdownButtonFormField<OpcionDeEjercicio>(
                initialValue: _opcion,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Ejercicio',
                  border: OutlineInputBorder(),
                ),
                items: <DropdownMenuItem<OpcionDeEjercicio>>[
                  for (final OpcionDeEjercicio o in widget.opciones)
                    DropdownMenuItem<OpcionDeEjercicio>(
                      value: o,
                      child: Text(o.etiqueta, overflow: TextOverflow.ellipsis),
                    ),
                ],
                onChanged: _elegirEjercicio,
                validator: (OpcionDeEjercicio? o) =>
                    o == null ? 'Elige un ejercicio.' : null,
              ),
              if (_opcion != null) ...<Widget>[
                const SizedBox(height: 16),
                Text('Máquina', style: textos.titleSmall),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: <Widget>[
                    for (final Maquina m in _opcion!.maquinas)
                      ChoiceChip(
                        label: Text(m.nombre),
                        selected: _maquina?.id == m.id,
                        onSelected: (bool _) => setState(() => _maquina = m),
                      ),
                  ],
                ),
                if (errorDeMaquina != null)
                  Text(errorDeMaquina, style: estiloDeError),
              ],
              const SizedBox(height: 16),
              Text('Días', style: textos.titleSmall),
              const SizedBox(height: 6),
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: <Widget>[
                  for (final int d in diasPermitidos)
                    FilterChip(
                      label: Text(nombreCortoDelDia(d)),
                      selected: _dias.contains(d),
                      onSelected: (bool si) => setState(() {
                        si ? _dias.add(d) : _dias.remove(d);
                      }),
                    ),
                ],
              ),
              if (errorDeDias != null) Text(errorDeDias, style: estiloDeError),
              const SizedBox(height: 16),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Expanded(
                    child: TextFormField(
                      controller: _series,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Series',
                        helperText: 'Opcional, $minimoSeries a $maximoSeries',
                        border: OutlineInputBorder(),
                      ),
                      validator: validarSeries,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _repeticiones,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Repeticiones',
                        helperText: '$minimoRepeticiones a $maximoRepeticiones',
                        border: OutlineInputBorder(),
                      ),
                      validator: validarRepeticiones,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _minutos,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Minutos',
                  helperText: '$minimoMinutos a $maximoMinutos. Para lo que se '
                      'mide en tiempo, como la caminata.',
                  border: OutlineInputBorder(),
                ),
                validator: validarMinutos,
              ),
              if (errorDeCarga != null) ...<Widget>[
                const SizedBox(height: 6),
                Text(errorDeCarga, style: estiloDeError),
              ],
              const SizedBox(height: 20),
              FilledButton(
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(48),
                ),
                onPressed: _agregar,
                child: const Text('Agregar a la rutina'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
