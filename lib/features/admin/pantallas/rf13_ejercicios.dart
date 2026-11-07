import 'package:flutter/material.dart';

import '../../../core/datos/errores.dart';
import '../../../core/datos/repositorios.dart';
import '../../../core/modelos/administracion.dart';
import '../../../core/modelos/maquina.dart';
import '../reglas_admin.dart';
import 'piezas_admin.dart';

/// RF13 - Pestaña "Ejercicios" del panel de contenidos.
///
/// Crear, editar, dar de baja y eliminar ejercicios, y elegir en qué
/// máquinas se hacen. Un ejercicio que usan rutinas de usuarios no se
/// elimina: se ofrece darlo de baja (CU13, 5a).
class PestanaEjercicios extends StatefulWidget {
  const PestanaEjercicios({super.key});

  @override
  State<PestanaEjercicios> createState() => _PestanaEjerciciosState();
}

class _PestanaEjerciciosState extends State<PestanaEjercicios> {
  bool _cargando = true;
  String? _error;
  List<EjercicioAdmin> _ejercicios = <EjercicioAdmin>[];
  List<Maquina> _maquinas = <Maquina>[];

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
      final List<EjercicioAdmin> ejercicios =
          await Repositorios.admin.ejercicios();
      final List<Maquina> maquinas = await Repositorios.admin.maquinas();
      if (!mounted) return;
      setState(() {
        _ejercicios = ejercicios;
        _maquinas = maquinas;
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

  Future<void> _abrirFormulario([EjercicioAdmin? ejercicio]) async {
    final bool? guardo = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) =>
            FormularioEjercicio(ejercicio: ejercicio, maquinas: _maquinas),
      ),
    );
    if (guardo == true && mounted) {
      mostrarMensaje(
        context,
        'Ejercicio guardado el ${fechaLarga(ahoraEnColombia())} a las '
        '${horaDelReloj(ahoraEnColombia())}.',
      );
      await _cargar();
    }
  }

  DatosEjercicio _datos(EjercicioAdmin e, {required bool activo}) =>
      DatosEjercicio(
        id: e.id,
        nombre: e.nombre,
        grupoMuscular: e.grupoMuscular,
        descripcion: e.descripcion,
        instrucciones: e.instrucciones,
        activo: activo,
        maquinaIds: e.maquinaIds,
      );

  Future<void> _eliminar(EjercicioAdmin e) async {
    final bool ok = await confirmar(
      context,
      titulo: '¿Eliminar «${e.nombre}»?',
      mensaje: 'Se borra del catálogo. Si solo ya no se quiere ofrecer, '
          'mejor dalo de baja.',
      aceptar: 'Eliminar',
    );
    if (!ok || !mounted) return;

    try {
      final RespuestaEliminacion r =
          await Repositorios.admin.eliminarEjercicio(e.id);
      if (!mounted) return;
      if (r.resultado == ResultadoEliminacion.enUso) {
        final bool baja = await confirmar(
          context,
          titulo: 'No se puede eliminar',
          mensaje: '${mensajeDeEliminacion(r, que: 'El ejercicio')} ¿Quieres '
              'darlo de baja? Las rutinas que lo tienen lo conservan, pero '
              'ya no aparecerá en el catálogo ni en rutinas nuevas.',
          aceptar: 'Dar de baja',
        );
        if (baja && mounted) {
          await Repositorios.admin.guardarEjercicio(_datos(e, activo: false));
          if (mounted) mostrarMensaje(context, 'Ejercicio dado de baja.');
        }
      } else if (mounted) {
        mostrarMensaje(context, mensajeDeEliminacion(r, que: 'El ejercicio'));
      }
    } on ErrorDeDatos catch (err) {
      if (mounted) mostrarMensaje(context, err.mensaje);
    }
    if (mounted) await _cargar();
  }

  @override
  Widget build(BuildContext context) {
    if (_cargando) return const CargandoAdmin();
    if (_error != null) {
      return ErrorConReintento(mensaje: _error!, alReintentar: _cargar);
    }

    final ColorScheme esquema = Theme.of(context).colorScheme;

    return RefreshIndicator(
      onRefresh: _cargar,
      child: ListView(
        // Se puede jalar hacia abajo para actualizar aunque la lista sea
        // corta.
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: <Widget>[
          FilledButton.icon(
            onPressed: () => _abrirFormulario(),
            icon: const Icon(Icons.add),
            label: const Text('Nuevo ejercicio'),
          ),
          const SizedBox(height: 12),
          if (_ejercicios.isEmpty)
            const AvisoAdmin(
              texto: 'Todavía no hay ejercicios en el catálogo.',
              esError: false,
            ),
          for (final EjercicioAdmin e in _ejercicios)
            Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                title: Text(e.nombre),
                subtitle: Text(
                  '${e.grupoMuscular} · '
                  '${e.maquinaIds.length == 1 ? '1 máquina' : '${e.maquinaIds.length} máquinas'}'
                  '${e.activo ? '' : ' · Dado de baja'}',
                  style: TextStyle(
                    color: e.activo ? esquema.onSurfaceVariant : esquema.error,
                  ),
                ),
                onTap: () => _abrirFormulario(e),
                trailing: IconButton(
                  tooltip: 'Eliminar ${e.nombre}',
                  icon: const Icon(Icons.delete_outline),
                  onPressed: () => _eliminar(e),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Formulario para crear o editar un ejercicio.
class FormularioEjercicio extends StatefulWidget {
  const FormularioEjercicio({
    super.key,
    this.ejercicio,
    required this.maquinas,
  });

  final EjercicioAdmin? ejercicio;
  final List<Maquina> maquinas;

  @override
  State<FormularioEjercicio> createState() => _FormularioEjercicioState();
}

class _FormularioEjercicioState extends State<FormularioEjercicio> {
  final GlobalKey<FormState> _form = GlobalKey<FormState>();
  late final TextEditingController _nombre =
      TextEditingController(text: widget.ejercicio?.nombre ?? '');
  late final TextEditingController _grupo =
      TextEditingController(text: widget.ejercicio?.grupoMuscular ?? '');
  late final TextEditingController _descripcion =
      TextEditingController(text: widget.ejercicio?.descripcion ?? '');
  late final TextEditingController _instrucciones =
      TextEditingController(text: widget.ejercicio?.instrucciones ?? '');

  late final Set<int> _maquinas =
      (widget.ejercicio?.maquinaIds ?? const <int>[]).toSet();
  late bool _activo = widget.ejercicio?.activo ?? true;

  bool _guardando = false;
  String? _error;

  @override
  void dispose() {
    _nombre.dispose();
    _grupo.dispose();
    _descripcion.dispose();
    _instrucciones.dispose();
    super.dispose();
  }

  Future<void> _guardar() async {
    final bool camposBien = _form.currentState?.validate() ?? false;
    if (_maquinas.isEmpty) {
      setState(() => _error = 'Elige al menos una máquina donde se haga.');
      return;
    }
    if (!camposBien) return;

    setState(() {
      _guardando = true;
      _error = null;
    });
    try {
      await Repositorios.admin.guardarEjercicio(DatosEjercicio(
        id: widget.ejercicio?.id,
        nombre: _nombre.text,
        grupoMuscular: _grupo.text,
        descripcion: _descripcion.text,
        instrucciones: _instrucciones.text,
        activo: _activo,
        maquinaIds: _maquinas.toList(),
      ));
      if (mounted) Navigator.of(context).pop(true);
    } on ErrorDeDatos catch (e) {
      if (!mounted) return;
      setState(() {
        _guardando = false;
        _error = e.mensaje;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final TextTheme textos = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(
            widget.ejercicio == null ? 'Nuevo ejercicio' : 'Editar ejercicio'),
      ),
      body: Form(
        key: _form,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
          children: <Widget>[
            if (_error != null) ...<Widget>[
              AvisoAdmin(texto: _error!),
              const SizedBox(height: 12),
            ],
            TextFormField(
              controller: _nombre,
              decoration: const InputDecoration(
                labelText: 'Nombre *',
                border: OutlineInputBorder(),
              ),
              validator: validarNombre,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _grupo,
              decoration: const InputDecoration(
                labelText: 'Grupo muscular *',
                hintText: 'Pierna, Pecho, Espalda…',
                border: OutlineInputBorder(),
              ),
              validator: validarGrupoMuscular,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _descripcion,
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: 'Descripción',
                border: OutlineInputBorder(),
              ),
              validator: (String? v) => validarTextoLargo(v),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _instrucciones,
              maxLines: 5,
              decoration: const InputDecoration(
                labelText: 'Instrucciones de ejecución',
                border: OutlineInputBorder(),
                alignLabelWithHint: true,
              ),
              validator: (String? v) => validarTextoLargo(v, maximo: 2000),
            ),
            const SizedBox(height: 16),
            Text('Máquinas donde se hace *', style: textos.titleSmall),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: <Widget>[
                for (final Maquina m in widget.maquinas)
                  FilterChip(
                    label: Text(m.nombre),
                    selected: _maquinas.contains(m.id),
                    onSelected: (bool si) => setState(() {
                      if (si) {
                        _maquinas.add(m.id);
                      } else {
                        _maquinas.remove(m.id);
                      }
                    }),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Activo'),
              subtitle: const Text(
                  'Si lo apagas, se da de baja: ya no sale en el catálogo.'),
              value: _activo,
              onChanged: (bool v) => setState(() => _activo = v),
            ),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: _guardando ? null : _guardar,
              child: Text(_guardando ? 'Guardando…' : 'Guardar y publicar'),
            ),
          ],
        ),
      ),
    );
  }
}
