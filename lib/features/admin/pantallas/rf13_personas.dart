import 'package:flutter/material.dart';

import '../../../core/datos/errores.dart';
import '../../../core/datos/repositorios.dart';
import '../../../core/modelos/administracion.dart';
import '../../../core/modelos/perfil.dart';
import '../reglas_admin.dart';
import 'piezas_admin.dart';

/// RF13 - Pestaña "Personas" del panel de contenidos.
///
/// Cambia el rol (usuario, instructor o administrador), la especialidad
/// de los instructores (la ve el usuario en el RF7) y si la cuenta está
/// activa. El administrador no puede quitarse su propio rol.
class PestanaPersonas extends StatefulWidget {
  const PestanaPersonas({super.key});

  @override
  State<PestanaPersonas> createState() => _PestanaPersonasState();
}

class _PestanaPersonasState extends State<PestanaPersonas> {
  final TextEditingController _buscar = TextEditingController();

  bool _cargando = true;
  String? _error;
  List<Perfil> _personas = <Perfil>[];

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  @override
  void dispose() {
    _buscar.dispose();
    super.dispose();
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
        _personas = personas;
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

  List<Perfil> get _filtradas {
    final String q = _buscar.text.trim().toLowerCase();
    if (q.isEmpty) return _personas;
    return _personas
        .where((Perfil p) =>
            p.nombreCompleto.toLowerCase().contains(q) ||
            p.documento.contains(q) ||
            p.correo.toLowerCase().contains(q))
        .toList();
  }

  Future<void> _editar(Perfil p) async {
    final ResultadoPersona? r = await showDialog<ResultadoPersona>(
      context: context,
      builder: (_) => _DialogoPersona(persona: p),
    );
    if (r == null || !mounted) return;
    mostrarMensaje(context, mensajeDePersona(r));
    await _cargar();
  }

  @override
  Widget build(BuildContext context) {
    if (_cargando) return const CargandoAdmin();
    if (_error != null) {
      return ErrorConReintento(mensaje: _error!, alReintentar: _cargar);
    }

    final ColorScheme esquema = Theme.of(context).colorScheme;
    final List<Perfil> lista = _filtradas;

    return RefreshIndicator(
      onRefresh: _cargar,
      child: ListView(
        // Se puede jalar hacia abajo para actualizar aunque la lista sea
        // corta.
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: <Widget>[
          TextField(
            controller: _buscar,
            decoration: const InputDecoration(
              labelText: 'Buscar por nombre, documento o correo',
              prefixIcon: Icon(Icons.search),
              border: OutlineInputBorder(),
            ),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 12),
          if (lista.isEmpty)
            const AvisoAdmin(texto: 'No hay personas con ese dato.', esError: false),
          for (final Perfil p in lista)
            Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                title: Text(p.nombreCompleto),
                subtitle: Text(
                  '${nombreDeRol(p.rol)}'
                  '${p.especialidad == null ? '' : ' · ${p.especialidad}'}'
                  '${p.activo ? '' : ' · Desactivada'}\n${p.correo}',
                  style: TextStyle(
                    color: p.activo ? esquema.onSurfaceVariant : esquema.error,
                  ),
                ),
                isThreeLine: true,
                trailing: const Icon(Icons.edit_outlined),
                onTap: () => _editar(p),
              ),
            ),
        ],
      ),
    );
  }
}

class _DialogoPersona extends StatefulWidget {
  const _DialogoPersona({required this.persona});

  final Perfil persona;

  @override
  State<_DialogoPersona> createState() => _DialogoPersonaState();
}

class _DialogoPersonaState extends State<_DialogoPersona> {
  late RolUsuario _rol = widget.persona.rol;
  late bool _activo = widget.persona.activo;
  late final TextEditingController _especialidad =
      TextEditingController(text: widget.persona.especialidad ?? '');

  bool _guardando = false;
  String? _error;

  @override
  void dispose() {
    _especialidad.dispose();
    super.dispose();
  }

  Future<void> _guardar() async {
    final String esp = _especialidad.text.trim();
    if (_rol == RolUsuario.instructor && esp.length > 80) {
      setState(() => _error = 'La especialidad tiene máximo 80 caracteres.');
      return;
    }
    setState(() {
      _guardando = true;
      _error = null;
    });
    try {
      final ResultadoPersona r = await Repositorios.admin.actualizarPersona(
        perfilId: widget.persona.id,
        rol: _rol,
        activo: _activo,
        especialidad: esp.isEmpty ? null : esp,
      );
      if (mounted) Navigator.of(context).pop(r);
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
    return AlertDialog(
      title: Text(widget.persona.nombreCompleto),
      // Ancho fijo: el diálogo mide el ancho de su contenido, y así no le
      // pregunta a la lista desplegable.
      content: SizedBox(
        width: 360,
        child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            if (_error != null) ...<Widget>[
              AvisoAdmin(texto: _error!),
              const SizedBox(height: 12),
            ],
            DropdownButtonFormField<RolUsuario>(
              initialValue: _rol,
              decoration: const InputDecoration(
                labelText: 'Rol',
                border: OutlineInputBorder(),
              ),
              items: <DropdownMenuItem<RolUsuario>>[
                for (final RolUsuario r in RolUsuario.values)
                  DropdownMenuItem<RolUsuario>(
                    value: r,
                    child: Text(nombreDeRol(r)),
                  ),
              ],
              onChanged: (RolUsuario? v) => setState(() => _rol = v ?? _rol),
            ),
            if (_rol == RolUsuario.instructor) ...<Widget>[
              const SizedBox(height: 12),
              TextField(
                controller: _especialidad,
                decoration: const InputDecoration(
                  labelText: 'Especialidad',
                  hintText: 'Entrenamiento funcional',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
            const SizedBox(height: 8),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Cuenta activa'),
              value: _activo,
              onChanged: (bool v) => setState(() => _activo = v),
            ),
          ],
        ),
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: _guardando ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        TextButton(
          onPressed: _guardando ? null : _guardar,
          child: Text(_guardando ? 'Guardando…' : 'Guardar'),
        ),
      ],
    );
  }
}
