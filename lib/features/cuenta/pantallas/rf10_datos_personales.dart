import 'package:flutter/material.dart';

import '../../../core/datos/errores.dart';
import '../../../core/datos/repositorios.dart';
import '../../../core/modelos/perfil.dart';
import '../reglas_cuenta.dart';

/// RF10 - Consulta y actualización de datos personales
///
/// Módulo: cuenta | Responsable: David
///
/// Muestra los datos de quien tiene la sesión abierta y permite cambiar
/// nombres, apellidos y celular. El correo y el documento no se
/// cambian desde la app: el correo es el de la cuenta de Microsoft y el
/// documento identifica a la persona. La base de datos aplica la misma
/// regla con permisos por columna (schema.sql), y cada quien solo puede
/// leer y editar su propio perfil (RLS).
class PantallaDatosPersonales extends StatefulWidget {
  const PantallaDatosPersonales({super.key});

  @override
  State<PantallaDatosPersonales> createState() =>
      _PantallaDatosPersonalesState();
}

class _PantallaDatosPersonalesState extends State<PantallaDatosPersonales> {
  final GlobalKey<FormState> _formulario = GlobalKey<FormState>();
  final TextEditingController _nombre = TextEditingController();
  final TextEditingController _apellido = TextEditingController();
  final TextEditingController _telefono = TextEditingController();

  bool _cargando = true;
  String? _errorDeCarga;
  Perfil? _perfil;

  bool _editando = false;
  bool _guardando = false;
  String? _errorAlGuardar;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  @override
  void dispose() {
    _nombre.dispose();
    _apellido.dispose();
    _telefono.dispose();
    super.dispose();
  }

  Future<void> _cargar() async {
    setState(() {
      _cargando = true;
      _errorDeCarga = null;
    });
    try {
      final Perfil? perfil = await Repositorios.perfiles.perfilActual();
      if (!mounted) return;
      setState(() {
        _perfil = perfil;
        if (perfil == null) {
          _errorDeCarga = 'No encontramos tu perfil. Cierra sesión y vuelve '
              'a ingresar.';
        }
      });
    } on ErrorDeDatos catch (e) {
      if (!mounted) return;
      setState(() => _errorDeCarga = e.mensaje);
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  void _empezarEdicion() {
    final Perfil p = _perfil!;
    _nombre.text = p.nombre;
    _apellido.text = p.apellido;
    _telefono.text = p.telefono ?? '';
    setState(() {
      _editando = true;
      _errorAlGuardar = null;
    });
  }

  void _cancelar() {
    setState(() {
      _editando = false;
      _errorAlGuardar = null;
    });
  }

  /// Si no cambió nada, no vale la pena ir a la base.
  bool get _hayCambios {
    final Perfil p = _perfil!;
    return _nombre.text.trim() != p.nombre ||
        _apellido.text.trim() != p.apellido ||
        _telefono.text.trim() != (p.telefono ?? '');
  }

  Future<void> _guardar() async {
    if (!_formulario.currentState!.validate()) return;

    if (!_hayCambios) {
      setState(() => _editando = false);
      return;
    }

    setState(() {
      _guardando = true;
      _errorAlGuardar = null;
    });
    try {
      final Perfil actualizado = await Repositorios.perfiles.actualizarPerfil(
        nombre: _nombre.text,
        apellido: _apellido.text,
        telefono: _telefono.text,
      );
      if (!mounted) return;
      setState(() {
        _perfil = actualizado;
        _editando = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Tus datos se actualizaron.')),
      );
    } on ErrorDeDatos catch (e) {
      if (mounted) setState(() => _errorAlGuardar = e.mensaje);
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool puedeEditar = !_cargando && _perfil != null && !_editando;

    return PopScope(
      // Con la edición abierta, el botón atrás cancela la edición en vez
      // de salir de la pantalla y perder lo escrito sin avisar.
      canPop: !_editando,
      onPopInvokedWithResult: (bool salio, Object? _) {
        if (!salio && !_guardando) _cancelar();
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(_editando ? 'Editar mis datos' : 'Mis datos personales'),
          actions: <Widget>[
            if (puedeEditar)
              IconButton(
                tooltip: 'Editar mis datos',
                icon: const Icon(Icons.edit_outlined),
                onPressed: _empezarEdicion,
              ),
          ],
        ),
        body: _cuerpo(context),
      ),
    );
  }

  Widget _cuerpo(BuildContext context) {
    if (_cargando) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_errorDeCarga != null) {
      return ListView(
        padding: const EdgeInsets.all(24),
        children: <Widget>[
          _Aviso(texto: _errorDeCarga!),
          const SizedBox(height: 16),
          FilledButton(onPressed: _cargar, child: const Text('Reintentar')),
        ],
      );
    }

    final Perfil p = _perfil!;
    return _editando ? _formularioDeEdicion(context, p) : _ficha(context, p);
  }

  // -------------------------------------------------------------------
  // Modo lectura
  // -------------------------------------------------------------------

  Widget _ficha(BuildContext context, Perfil p) {
    final TextTheme textos = Theme.of(context).textTheme;
    final ColorScheme esquema = Theme.of(context).colorScheme;

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
      children: <Widget>[
        Text(p.nombreCompleto, style: textos.headlineSmall),
        const SizedBox(height: 4),
        Text(nombreDelRol(p.rol),
            style: textos.bodyMedium?.copyWith(color: esquema.primary)),
        const SizedBox(height: 16),
        Card(
          child: Column(
            children: <Widget>[
              _Fila(icono: Icons.person_outline, titulo: 'Nombres', valor: p.nombre),
              _Fila(icono: Icons.person_outline, titulo: 'Apellidos', valor: p.apellido),
              _Fila(icono: Icons.badge_outlined, titulo: 'Documento', valor: p.documento),
              _Fila(icono: Icons.mail_outline, titulo: 'Correo institucional', valor: p.correo),
              _Fila(
                icono: Icons.phone_outlined,
                titulo: 'Celular',
                valor: p.telefono ?? 'Sin registrar',
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        FilledButton.icon(
          onPressed: _empezarEdicion,
          icon: const Icon(Icons.edit_outlined),
          label: const Text('Actualizar mis datos'),
        ),
      ],
    );
  }

  // -------------------------------------------------------------------
  // Modo edición
  // -------------------------------------------------------------------

  Widget _formularioDeEdicion(BuildContext context, Perfil p) {
    final TextTheme textos = Theme.of(context).textTheme;
    final ColorScheme esquema = Theme.of(context).colorScheme;

    return Form(
      key: _formulario,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
        children: <Widget>[
          TextFormField(
            controller: _nombre,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(
              labelText: 'Nombres',
              border: OutlineInputBorder(),
            ),
            validator: (String? v) => validarObligatorio(v, 'nombre'),
          ),
          const SizedBox(height: 14),
          TextFormField(
            controller: _apellido,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(
              labelText: 'Apellidos',
              border: OutlineInputBorder(),
            ),
            validator: (String? v) => validarObligatorio(v, 'apellido'),
          ),
          const SizedBox(height: 14),
          TextFormField(
            controller: _telefono,
            keyboardType: TextInputType.phone,
            decoration: const InputDecoration(
              labelText: 'Celular (opcional)',
              border: OutlineInputBorder(),
            ),
            validator: validarTelefono,
          ),
          const SizedBox(height: 20),
          // Lo que no se puede cambiar se muestra, pero bloqueado.
          TextFormField(
            initialValue: p.documento,
            enabled: false,
            decoration: const InputDecoration(
              labelText: 'Documento',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 14),
          TextFormField(
            initialValue: p.correo,
            enabled: false,
            decoration: const InputDecoration(
              labelText: 'Correo institucional',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'El correo y el documento no se pueden cambiar desde la app. '
            'Si tu documento está mal, acércate a la administración del '
            'gimnasio.',
            style: textos.bodySmall?.copyWith(color: esquema.onSurfaceVariant),
          ),
          const SizedBox(height: 20),
          if (_errorAlGuardar != null) ...<Widget>[
            _Aviso(texto: _errorAlGuardar!),
            const SizedBox(height: 16),
          ],
          FilledButton(
            onPressed: _guardando ? null : _guardar,
            child: _guardando
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Guardar cambios'),
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: _guardando ? null : _cancelar,
            child: const Text('Cancelar'),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------
// Piezas de este archivo
// ---------------------------------------------------------------------

class _Fila extends StatelessWidget {
  const _Fila({required this.icono, required this.titulo, required this.valor});

  final IconData icono;
  final String titulo;
  final String valor;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icono),
      title: Text(titulo),
      subtitle: Text(valor),
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
