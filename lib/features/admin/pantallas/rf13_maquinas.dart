import 'package:flutter/material.dart';

import '../../../core/datos/errores.dart';
import '../../../core/datos/repositorios.dart';
import '../../../core/modelos/administracion.dart';
import '../../../core/modelos/maquina.dart';
import '../../../core/modelos/zona.dart';
import '../reglas_admin.dart';
import 'piezas_admin.dart';

/// RF13 - Pestaña "Máquinas" del panel de contenidos.
///
/// Crear, editar, dejar fuera de servicio, dar de baja y eliminar. Una
/// máquina que usan rutinas de usuarios no se elimina: se ofrece dejarla
/// fuera de servicio (CU13, 5a).
class PestanaMaquinas extends StatefulWidget {
  const PestanaMaquinas({super.key});

  @override
  State<PestanaMaquinas> createState() => _PestanaMaquinasState();
}

class _PestanaMaquinasState extends State<PestanaMaquinas> {
  bool _cargando = true;
  String? _error;
  List<Maquina> _maquinas = <Maquina>[];
  List<Zona> _zonas = <Zona>[];

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
      final List<Maquina> maquinas = await Repositorios.admin.maquinas();
      final List<Zona> zonas = await Repositorios.gimnasio.zonas();
      if (!mounted) return;
      setState(() {
        _maquinas = maquinas;
        _zonas = zonas;
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

  String _zona(int id) {
    for (final Zona z in _zonas) {
      if (z.id == id) return z.nombre;
    }
    return 'Zona $id';
  }

  Future<void> _abrirFormulario([Maquina? maquina]) async {
    final bool? guardo = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => FormularioMaquina(maquina: maquina, zonas: _zonas),
      ),
    );
    if (guardo == true && mounted) {
      mostrarMensaje(
        context,
        'Máquina guardada el ${fechaLarga(ahoraEnColombia())} a las '
        '${horaDelReloj(ahoraEnColombia())}. Ya se ve en el catálogo.',
      );
      await _cargar();
    }
  }

  Future<void> _eliminar(Maquina m) async {
    final bool ok = await confirmar(
      context,
      titulo: '¿Eliminar «${m.nombre}»?',
      mensaje: 'Se borra del catálogo con sus vínculos a ejercicios. Si solo '
          'está dañada, mejor déjala fuera de servicio.',
      aceptar: 'Eliminar',
    );
    if (!ok || !mounted) return;

    try {
      final RespuestaEliminacion r =
          await Repositorios.admin.eliminarMaquina(m.id);
      if (!mounted) return;
      if (r.resultado == ResultadoEliminacion.enUso) {
        // CU13, 5a: se ofrece dejarla fuera de servicio.
        final bool fuera = await confirmar(
          context,
          titulo: 'No se puede eliminar',
          mensaje: '${mensajeDeEliminacion(r, que: 'La máquina')} ¿Quieres '
              'dejarla fuera de servicio? Seguirá en las rutinas, y el '
              'catálogo la mostrará como fuera de servicio.',
          aceptar: 'Dejar fuera de servicio',
        );
        if (fuera && mounted) {
          await Repositorios.admin
              .cambiarEstadoMaquina(m.id, EstadoMaquina.mantenimiento);
          if (mounted) mostrarMensaje(context, 'Máquina fuera de servicio.');
        }
      } else if (mounted) {
        mostrarMensaje(context, mensajeDeEliminacion(r, que: 'La máquina'));
      }
    } on ErrorDeDatos catch (e) {
      if (mounted) mostrarMensaje(context, e.mensaje);
    }
    if (mounted) await _cargar();
  }

  @override
  Widget build(BuildContext context) {
    if (_cargando) return const CargandoAdmin();
    if (_error != null) {
      return ErrorConReintento(mensaje: _error!, alReintentar: _cargar);
    }

    final TextTheme textos = Theme.of(context).textTheme;
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
            onPressed: _zonas.isEmpty ? null : () => _abrirFormulario(),
            icon: const Icon(Icons.add),
            label: const Text('Nueva máquina'),
          ),
          const SizedBox(height: 8),
          if (_maquinas.isEmpty)
            const Padding(
              padding: EdgeInsets.only(top: 16),
              child: AvisoAdmin(
                texto: 'Todavía no hay máquinas en el catálogo.',
                esError: false,
              ),
            ),
          for (final Zona z in _zonas)
            if (_maquinas.any((Maquina m) => m.zonaId == z.id)) ...<Widget>[
              Padding(
                padding: const EdgeInsets.only(top: 16, bottom: 6),
                child: Text(z.nombre, style: textos.titleSmall),
              ),
              for (final Maquina m in _maquinas.where((Maquina m) => m.zonaId == z.id))
                Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    title: Text(m.nombre),
                    subtitle: Text(
                      '${m.cantidad} ${m.cantidad == 1 ? 'unidad' : 'unidades'} · '
                      '${nombreDeEstadoMaquina(m.estado)}',
                      style: TextStyle(
                        color: m.estado == EstadoMaquina.disponible
                            ? esquema.onSurfaceVariant
                            : esquema.error,
                      ),
                    ),
                    onTap: () => _abrirFormulario(m),
                    trailing: IconButton(
                      tooltip: 'Eliminar ${m.nombre}',
                      icon: const Icon(Icons.delete_outline),
                      onPressed: () => _eliminar(m),
                    ),
                  ),
                ),
            ],
          // Máquinas de una zona que ya no existe en la lista.
          for (final Maquina m in _maquinas
              .where((Maquina m) => !_zonas.any((Zona z) => z.id == m.zonaId)))
            ListTile(title: Text(m.nombre), subtitle: Text(_zona(m.zonaId))),
        ],
      ),
    );
  }
}

/// Formulario para crear o editar una máquina.
class FormularioMaquina extends StatefulWidget {
  const FormularioMaquina({super.key, this.maquina, required this.zonas});

  /// null para crear una nueva.
  final Maquina? maquina;
  final List<Zona> zonas;

  @override
  State<FormularioMaquina> createState() => _FormularioMaquinaState();
}

class _FormularioMaquinaState extends State<FormularioMaquina> {
  final GlobalKey<FormState> _form = GlobalKey<FormState>();
  late final TextEditingController _nombre =
      TextEditingController(text: widget.maquina?.nombre ?? '');
  late final TextEditingController _descripcion =
      TextEditingController(text: widget.maquina?.descripcion ?? '');
  late final TextEditingController _cantidad =
      TextEditingController(text: '${widget.maquina?.cantidad ?? 1}');
  late final TextEditingController _imagen =
      TextEditingController(text: widget.maquina?.imagenUrl ?? '');

  late int _zonaId = widget.maquina?.zonaId ?? widget.zonas.first.id;
  late EstadoMaquina _estado = widget.maquina?.estado ?? EstadoMaquina.disponible;

  bool _guardando = false;
  String? _error;

  @override
  void dispose() {
    _nombre.dispose();
    _descripcion.dispose();
    _cantidad.dispose();
    _imagen.dispose();
    super.dispose();
  }

  Future<void> _guardar() async {
    if (!(_form.currentState?.validate() ?? false)) return;
    setState(() {
      _guardando = true;
      _error = null;
    });
    try {
      await Repositorios.admin.guardarMaquina(DatosMaquina(
        id: widget.maquina?.id,
        zonaId: _zonaId,
        nombre: _nombre.text,
        descripcion: _descripcion.text,
        cantidad: int.parse(_cantidad.text.trim()),
        estado: estadoMaquinaATexto(_estado),
        imagenUrl: _imagen.text,
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
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.maquina == null ? 'Nueva máquina' : 'Editar máquina'),
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
            DropdownButtonFormField<int>(
              initialValue: _zonaId,
              decoration: const InputDecoration(
                labelText: 'Zona *',
                border: OutlineInputBorder(),
              ),
              items: <DropdownMenuItem<int>>[
                for (final Zona z in widget.zonas)
                  DropdownMenuItem<int>(value: z.id, child: Text(z.nombre)),
              ],
              onChanged: (int? v) => setState(() => _zonaId = v ?? _zonaId),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _cantidad,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Unidades *',
                border: OutlineInputBorder(),
              ),
              validator: validarCantidad,
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<EstadoMaquina>(
              initialValue: _estado,
              decoration: const InputDecoration(
                labelText: 'Estado *',
                border: OutlineInputBorder(),
                helperText: 'Fuera de servicio: se ve en el catálogo marcada. '
                    'Dada de baja: ya no se muestra.',
                helperMaxLines: 2,
              ),
              items: <DropdownMenuItem<EstadoMaquina>>[
                for (final EstadoMaquina e in EstadoMaquina.values)
                  DropdownMenuItem<EstadoMaquina>(
                    value: e,
                    child: Text(nombreDeEstadoMaquina(e)),
                  ),
              ],
              onChanged: (EstadoMaquina? v) =>
                  setState(() => _estado = v ?? _estado),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _descripcion,
              maxLines: 4,
              decoration: const InputDecoration(
                labelText: 'Descripción e instrucciones de uso',
                border: OutlineInputBorder(),
                alignLabelWithHint: true,
              ),
              validator: (String? v) => validarTextoLargo(v),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _imagen,
              keyboardType: TextInputType.url,
              decoration: const InputDecoration(
                labelText: 'Dirección de la foto (https://…)',
                border: OutlineInputBorder(),
                helperText: 'Sube la foto al bucket "maquinas" de Supabase y '
                    'pega aquí su dirección pública.',
                helperMaxLines: 2,
              ),
              validator: validarImagenUrl,
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
