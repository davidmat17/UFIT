import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/datos/errores.dart';
import '../../../core/datos/puertos/repositorio_perfiles.dart';
import '../../../core/datos/repositorios.dart';
import '../../../core/modelos/perfil.dart';
import '../../../core/modelos/sesion.dart';
import '../reglas_cuenta.dart';

/// RF1 - Registro e inicio de sesión de usuarios
///
/// Módulo: cuenta | Responsable: David
///
/// El ingreso es con la cuenta institucional de Microsoft. Registrarse
/// es ingresar por primera vez y completar documento y teléfono, que
/// Microsoft no entrega.
///
/// Este archivo tiene tres piezas:
/// - [CompuertaDeSesion]: decide qué ve la persona al abrir la app.
/// - Las pantallas de ingreso y de completar registro, que solo usa la
///   compuerta.
/// - [PantallaAutenticacion]: la cuenta abierta y el cierre de sesión,
///   que es la entrada del RF1 en el menú.

/// Lo primero que se muestra al abrir la app.
///
/// Sin sesión muestra el ingreso; con sesión pero sin perfil, el
/// formulario de registro; con perfil, lo que reciba en [inicio]. No
/// sabe qué hay en [inicio]: eso lo decide main.dart, para que el
/// módulo de cuenta no dependa de ningún otro.
class CompuertaDeSesion extends StatefulWidget {
  const CompuertaDeSesion({super.key, required this.inicio});

  final WidgetBuilder inicio;

  @override
  State<CompuertaDeSesion> createState() => _CompuertaDeSesionState();
}

enum _Etapa { cargando, ingreso, completarRegistro, cuentaInactiva, error, dentro }

class _CompuertaDeSesionState extends State<CompuertaDeSesion> {
  RepositorioPerfiles get _repo => Repositorios.perfiles;

  StreamSubscription<void>? _suscripcion;
  _Etapa _etapa = _Etapa.cargando;
  SesionActiva? _sesion;
  String? _aviso;

  /// Cada evaluación toma un número. Si llega una respuesta vieja
  /// después de una nueva, se descarta.
  int _turno = 0;

  @override
  void initState() {
    super.initState();
    _suscripcion = _repo.cambiosDeSesion.listen((_) => _evaluar());
    _evaluar();
  }

  @override
  void dispose() {
    _suscripcion?.cancel();
    super.dispose();
  }

  void _mostrar(_Etapa etapa, int turno) {
    if (!mounted || turno != _turno) return;
    setState(() => _etapa = etapa);
  }

  Future<void> _evaluar() async {
    final int turno = ++_turno;
    _mostrar(_Etapa.cargando, turno);

    final SesionActiva? sesion = _repo.sesionActual();
    _sesion = sesion;

    if (sesion == null) {
      _mostrar(_Etapa.ingreso, turno);
      return;
    }

    if (!esCorreoInstitucional(sesion.correo)) {
      _aviso = 'Ingresaste con ${sesion.correo}. UFIT solo acepta '
          'correos institucionales de la UIS '
          '(@uis.edu.co o @correo.uis.edu.co).';
      try {
        await _repo.cerrarSesion();
      } on ErrorDeDatos {
        // Si no se pudo cerrar, igual se queda en el ingreso.
      }
      _mostrar(_Etapa.ingreso, turno);
      return;
    }

    try {
      final Perfil? perfil = await _repo.perfilActual();
      if (perfil == null) {
        _mostrar(_Etapa.completarRegistro, turno);
      } else if (!perfil.activo) {
        _mostrar(_Etapa.cuentaInactiva, turno);
      } else {
        _aviso = null;
        _mostrar(_Etapa.dentro, turno);
      }
    } on ErrorDeDatos catch (e) {
      _aviso = e.mensaje;
      _mostrar(_Etapa.error, turno);
    }
  }

  Future<void> _cerrarSesion() async {
    try {
      await _repo.cerrarSesion();
    } on ErrorDeDatos catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(e.mensaje)));
    }
  }

  @override
  Widget build(BuildContext context) {
    return switch (_etapa) {
      _Etapa.cargando => const Scaffold(
          body: Center(child: CircularProgressIndicator()),
        ),
      _Etapa.ingreso => _PantallaIngreso(
          aviso: _aviso,
          alIntentar: () => setState(() => _aviso = null),
        ),
      _Etapa.completarRegistro => _PantallaCompletarRegistro(
          sesion: _sesion!,
          alTerminar: _evaluar,
          alCambiarCuenta: _cerrarSesion,
        ),
      _Etapa.cuentaInactiva => _PantallaMensaje(
          icono: Icons.block_outlined,
          titulo: 'Cuenta desactivada',
          mensaje: 'Tu cuenta de UFIT está desactivada. Acércate a la '
              'administración del gimnasio para reactivarla.',
          accion: 'Cerrar sesión',
          alPresionar: _cerrarSesion,
        ),
      _Etapa.error => _PantallaMensaje(
          icono: Icons.cloud_off_outlined,
          titulo: 'No se pudo cargar tu cuenta',
          mensaje: _aviso ?? 'Inténtalo de nuevo.',
          accion: 'Reintentar',
          alPresionar: _evaluar,
          accionSecundaria: 'Cerrar sesión',
          alPresionarSecundaria: _cerrarSesion,
        ),
      _Etapa.dentro => widget.inicio(context),
    };
  }
}

// ---------------------------------------------------------------------
// Ingreso
// ---------------------------------------------------------------------

class _PantallaIngreso extends StatefulWidget {
  const _PantallaIngreso({this.aviso, required this.alIntentar});

  /// Mensaje del intento anterior, por ejemplo un correo no institucional.
  final String? aviso;
  final VoidCallback alIntentar;

  @override
  State<_PantallaIngreso> createState() => _PantallaIngresoState();
}

class _PantallaIngresoState extends State<_PantallaIngreso> {
  bool _abriendo = false;
  String? _error;

  Future<void> _ingresar() async {
    widget.alIntentar();
    setState(() {
      _abriendo = true;
      _error = null;
    });
    try {
      await Repositorios.perfiles.iniciarSesionInstitucional();
    } on ErrorDeDatos catch (e) {
      if (mounted) setState(() => _error = e.mensaje);
    } finally {
      if (mounted) setState(() => _abriendo = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme esquema = Theme.of(context).colorScheme;
    final TextTheme textos = Theme.of(context).textTheme;
    final String? mensaje = _error ?? widget.aviso;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.all(28),
            children: <Widget>[
              Icon(Icons.fitness_center, size: 56, color: esquema.primary),
              const SizedBox(height: 16),
              Text('UFIT',
                  textAlign: TextAlign.center,
                  style: textos.displaySmall?.copyWith(
                    color: esquema.primary,
                    fontWeight: FontWeight.w700,
                  )),
              const SizedBox(height: 6),
              Text(
                'Gimnasio de la Universidad Industrial de Santander',
                textAlign: TextAlign.center,
                style: textos.bodyMedium
                    ?.copyWith(color: esquema.onSurfaceVariant),
              ),
              const SizedBox(height: 40),
              if (mensaje != null) ...<Widget>[
                _Aviso(texto: mensaje),
                const SizedBox(height: 16),
              ],
              FilledButton.icon(
                onPressed: _abriendo ? null : _ingresar,
                icon: _abriendo
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.school_outlined),
                label: const Text('Ingresar con correo institucional'),
              ),
              const SizedBox(height: 14),
              Text(
                'Usa tu cuenta @uis.edu.co o @correo.uis.edu.co. '
                'Si es tu primera vez, te pediremos unos datos para '
                'crear tu cuenta.',
                textAlign: TextAlign.center,
                style: textos.bodySmall
                    ?.copyWith(color: esquema.onSurfaceVariant),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------
// Completar registro (primera vez)
// ---------------------------------------------------------------------

class _PantallaCompletarRegistro extends StatefulWidget {
  const _PantallaCompletarRegistro({
    required this.sesion,
    required this.alTerminar,
    required this.alCambiarCuenta,
  });

  final SesionActiva sesion;
  final Future<void> Function() alTerminar;
  final Future<void> Function() alCambiarCuenta;

  @override
  State<_PantallaCompletarRegistro> createState() =>
      _PantallaCompletarRegistroState();
}

class _PantallaCompletarRegistroState
    extends State<_PantallaCompletarRegistro> {
  final GlobalKey<FormState> _formulario = GlobalKey<FormState>();
  late final TextEditingController _nombre;
  late final TextEditingController _apellido;
  final TextEditingController _documento = TextEditingController();
  final TextEditingController _telefono = TextEditingController();

  bool _guardando = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final ({String nombre, String apellido}) sugerido =
        dividirNombre(widget.sesion.nombreCompleto);
    _nombre = TextEditingController(text: sugerido.nombre);
    _apellido = TextEditingController(text: sugerido.apellido);
  }

  @override
  void dispose() {
    _nombre.dispose();
    _apellido.dispose();
    _documento.dispose();
    _telefono.dispose();
    super.dispose();
  }

  Future<void> _guardar() async {
    if (!_formulario.currentState!.validate()) return;

    setState(() {
      _guardando = true;
      _error = null;
    });
    try {
      await Repositorios.perfiles.completarRegistro(
        nombre: _nombre.text,
        apellido: _apellido.text,
        documento: _documento.text,
        telefono: _telefono.text,
      );
      await widget.alTerminar();
    } on ErrorDeDatos catch (e) {
      if (mounted) setState(() => _error = e.mensaje);
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme esquema = Theme.of(context).colorScheme;
    final TextTheme textos = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Crea tu cuenta')),
      body: SafeArea(
        child: Form(
          key: _formulario,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
            children: <Widget>[
              Text(
                'Es tu primera vez en UFIT. Confirma tus datos para '
                'terminar el registro.',
                style: textos.bodyMedium
                    ?.copyWith(color: esquema.onSurfaceVariant),
              ),
              const SizedBox(height: 20),
              TextFormField(
                initialValue: widget.sesion.correo,
                enabled: false,
                decoration: const InputDecoration(
                  labelText: 'Correo institucional',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 14),
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
                controller: _documento,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Número de documento',
                  border: OutlineInputBorder(),
                ),
                validator: validarDocumento,
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
              if (_error != null) ...<Widget>[
                _Aviso(texto: _error!),
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
                    : const Text('Crear cuenta'),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: _guardando ? null : widget.alCambiarCuenta,
                child: const Text('Usar otra cuenta'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------
// Cuenta abierta (entrada del RF1 en el menú)
// ---------------------------------------------------------------------

/// Muestra quién tiene la sesión abierta y permite cerrarla.
class PantallaAutenticacion extends StatelessWidget {
  const PantallaAutenticacion({super.key});

  Future<void> _cerrarSesion(BuildContext context) async {
    final NavigatorState navegador = Navigator.of(context);
    try {
      await Repositorios.perfiles.cerrarSesion();
      // La compuerta, en la raíz, ya cambió al ingreso. Se quitan las
      // pantallas que quedaron encima.
      navegador.popUntil((Route<dynamic> r) => r.isFirst);
    } on ErrorDeDatos catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(e.mensaje)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final TextTheme textos = Theme.of(context).textTheme;
    final ColorScheme esquema = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Mi cuenta')),
      body: FutureBuilder<Perfil?>(
        future: Repositorios.perfiles.perfilActual(),
        builder: (BuildContext context, AsyncSnapshot<Perfil?> snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          final Perfil? perfil = snapshot.data;

          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
            children: <Widget>[
              if (snapshot.hasError)
                _Aviso(texto: snapshot.error.toString())
              else if (perfil != null) ...<Widget>[
                Text(perfil.nombreCompleto, style: textos.headlineSmall),
                const SizedBox(height: 4),
                Text(perfil.correo,
                    style: textos.bodyMedium
                        ?.copyWith(color: esquema.onSurfaceVariant)),
                const SizedBox(height: 16),
                Card(
                  child: Column(
                    children: <Widget>[
                      ListTile(
                        leading: const Icon(Icons.badge_outlined),
                        title: const Text('Documento'),
                        subtitle: Text(perfil.documento),
                      ),
                      ListTile(
                        leading: const Icon(Icons.phone_outlined),
                        title: const Text('Celular'),
                        subtitle: Text(perfil.telefono ?? 'Sin registrar'),
                      ),
                      ListTile(
                        leading: const Icon(Icons.verified_user_outlined),
                        title: const Text('Rol'),
                        subtitle: Text(_nombreDelRol(perfil.rol)),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 24),
              OutlinedButton.icon(
                onPressed: () => _cerrarSesion(context),
                icon: const Icon(Icons.logout),
                label: const Text('Cerrar sesión'),
              ),
            ],
          );
        },
      ),
    );
  }

  static String _nombreDelRol(RolUsuario rol) => switch (rol) {
        RolUsuario.usuario => 'Usuario',
        RolUsuario.instructor => 'Instructor',
        RolUsuario.administrador => 'Administrador',
      };
}

// ---------------------------------------------------------------------
// Piezas compartidas de este archivo
// ---------------------------------------------------------------------

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
            child: Text(texto,
                style: TextStyle(color: esquema.onErrorContainer)),
          ),
        ],
      ),
    );
  }
}

class _PantallaMensaje extends StatelessWidget {
  const _PantallaMensaje({
    required this.icono,
    required this.titulo,
    required this.mensaje,
    required this.accion,
    required this.alPresionar,
    this.accionSecundaria,
    this.alPresionarSecundaria,
  });

  final IconData icono;
  final String titulo;
  final String mensaje;
  final String accion;
  final VoidCallback alPresionar;
  final String? accionSecundaria;
  final VoidCallback? alPresionarSecundaria;

  @override
  Widget build(BuildContext context) {
    final ColorScheme esquema = Theme.of(context).colorScheme;
    final TextTheme textos = Theme.of(context).textTheme;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.all(28),
            children: <Widget>[
              Icon(icono, size: 48, color: esquema.primary),
              const SizedBox(height: 16),
              Text(titulo,
                  textAlign: TextAlign.center, style: textos.headlineSmall),
              const SizedBox(height: 12),
              Text(mensaje,
                  textAlign: TextAlign.center,
                  style: textos.bodyMedium
                      ?.copyWith(color: esquema.onSurfaceVariant)),
              const SizedBox(height: 28),
              FilledButton(onPressed: alPresionar, child: Text(accion)),
              if (accionSecundaria != null) ...<Widget>[
                const SizedBox(height: 8),
                TextButton(
                  onPressed: alPresionarSecundaria,
                  child: Text(accionSecundaria!),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
