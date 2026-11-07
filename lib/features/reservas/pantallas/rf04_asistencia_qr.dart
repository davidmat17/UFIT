import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../../core/datos/errores.dart';
import '../../../core/datos/repositorios.dart';
import '../../../core/modelos/perfil.dart';
import '../../../core/modelos/reserva.dart';
import '../../../core/modelos/validacion_ingreso.dart';
import '../../../core/modelos/zona.dart';
import '../../../core/rutas.dart';
import '../reglas_asistencia.dart';
import '../reglas_cancelacion.dart';
import '../reglas_reservas.dart';
import 'rf04_escaner_qr.dart';

/// RF4 - Registro de asistencia mediante código QR
///
/// Módulo: reservas
///
/// Dos vistas, según quién abre la pantalla (CU04):
/// - "Mi código": el QR de la reserva de hoy (o la próxima), con desde
///   cuándo y hasta cuándo sirve. Lo ve cualquier persona.
/// - "Validar ingresos": la cámara para escanear el QR en la entrada y la
///   búsqueda por documento cuando la persona no puede mostrarlo (3a).
///   Solo aparece para instructores y administradores.
///
/// Reglas que decide la base de datos (validar_ingreso, migración 015):
/// el código sirve desde 15 minutos antes de la franja hasta que termina,
/// una sola vez, y solo lo valida el personal del gimnasio.
class PantallaAsistenciaQr extends StatefulWidget {
  const PantallaAsistenciaQr({
    super.key,
    this.reloj = ahoraEnColombia,
    this.abrirEscaner,
  });

  /// De dónde sale "ahora" (hora de Colombia). Las pruebas lo cambian.
  final DateTime Function() reloj;

  /// Abre la cámara y devuelve el texto del QR, o null si se cerró sin
  /// leer. Las pruebas lo cambian para no necesitar cámara.
  final Future<String?> Function(BuildContext contexto)? abrirEscaner;

  @override
  State<PantallaAsistenciaQr> createState() => _PantallaAsistenciaQrState();
}

class _PantallaAsistenciaQrState extends State<PantallaAsistenciaQr> {
  bool _cargando = true;
  String? _error;

  Perfil? _perfil;
  List<Reserva> _reservas = <Reserva>[];
  List<Zona> _zonas = <Zona>[];

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  bool get _esPersonal =>
      _perfil?.rol == RolUsuario.instructor ||
      _perfil?.rol == RolUsuario.administrador;

  Future<void> _cargar({bool silencioso = false}) async {
    if (!silencioso) {
      setState(() {
        _cargando = true;
        _error = null;
      });
    }

    final DateTime hoy = soloFecha(widget.reloj());
    Perfil? perfil = _perfil;
    List<Reserva> reservas = <Reserva>[];
    List<Zona> zonas = _zonas;
    String? fallo;

    try {
      await Future.wait<void>(<Future<void>>[
        Repositorios.perfiles.perfilActual().then((Perfil? v) => perfil = v),
        Repositorios.reservas
            .misReservas(
              desde: hoy,
              hasta: DateTime(hoy.year, hoy.month, hoy.day + 14),
            )
            .then((List<Reserva> v) => reservas = v),
        if (_zonas.isEmpty)
          Repositorios.gimnasio.zonas().then((List<Zona> v) => zonas = v),
      ]);
    } on ErrorDeDatos catch (e) {
      fallo = e.mensaje;
    } catch (_) {
      fallo = 'No se pudo cargar tu código. Inténtalo de nuevo.';
    }

    if (!mounted) return;

    if (fallo != null && !silencioso) {
      setState(() {
        _cargando = false;
        _error = fallo;
      });
      return;
    }
    if (fallo != null) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(fallo)));
      return;
    }

    setState(() {
      _perfil = perfil;
      _reservas = reservas;
      _zonas = zonas;
      _cargando = false;
      _error = null;
    });
  }

  String _nombreDeZona(int id) {
    for (final Zona z in _zonas) {
      if (z.id == id) return z.nombre;
    }
    return 'Zona $id';
  }

  @override
  Widget build(BuildContext context) {
    final Widget miCodigo = RefreshIndicator(
      onRefresh: () => _cargar(silencioso: true),
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
        children: _contenidoMiCodigo(context),
      ),
    );

    if (_cargando || _error != null || !_esPersonal) {
      return Scaffold(
        appBar: AppBar(title: const Text('Mi código de ingreso')),
        body: miCodigo,
      );
    }

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Ingreso al gimnasio'),
          bottom: const TabBar(
            tabs: <Widget>[
              Tab(icon: Icon(Icons.qr_code_2), text: 'Mi código'),
              Tab(icon: Icon(Icons.qr_code_scanner), text: 'Validar ingresos'),
            ],
          ),
        ),
        body: TabBarView(
          children: <Widget>[
            miCodigo,
            VistaValidarIngresos(
              abrirEscaner: widget.abrirEscaner ?? _abrirCamara,
            ),
          ],
        ),
      ),
    );
  }

  static Future<String?> _abrirCamara(BuildContext contexto) =>
      Navigator.of(contexto).push<String>(
        MaterialPageRoute<String>(builder: (_) => const PantallaEscanerQr()),
      );

  List<Widget> _contenidoMiCodigo(BuildContext context) {
    if (_cargando) {
      return const <Widget>[
        Padding(
          padding: EdgeInsets.symmetric(vertical: 40),
          child: Center(
            child: CircularProgressIndicator(semanticsLabel: 'Cargando'),
          ),
        ),
      ];
    }

    if (_error != null) {
      return <Widget>[
        _Aviso(texto: _error!, esError: true),
        const SizedBox(height: 16),
        FilledButton(
          onPressed: () => _cargar(),
          child: const Text('Reintentar'),
        ),
      ];
    }

    final DateTime ahora = widget.reloj();
    final Reserva? reserva = reservaParaElCodigo(_reservas, ahora);

    if (reserva == null) {
      return <Widget>[const _SinReserva()];
    }

    return <Widget>[
      _TarjetaDeCodigo(
        reserva: reserva,
        ahora: ahora,
        nombreDeZona: _nombreDeZona(reserva.zonaId),
      ),
      const SizedBox(height: 16),
      OutlinedButton.icon(
        onPressed: () => _cargar(silencioso: true),
        icon: const Icon(Icons.refresh),
        label: const Text('Actualizar'),
      ),
    ];
  }
}

// ---------------------------------------------------------------------
// Mi código
// ---------------------------------------------------------------------

class _TarjetaDeCodigo extends StatelessWidget {
  const _TarjetaDeCodigo({
    required this.reserva,
    required this.ahora,
    required this.nombreDeZona,
  });

  final Reserva reserva;
  final DateTime ahora;
  final String nombreDeZona;

  @override
  Widget build(BuildContext context) {
    final ColorScheme esquema = Theme.of(context).colorScheme;
    final TextTheme textos = Theme.of(context).textTheme;

    final EstadoDelCodigo estado = estadoDelCodigo(reserva, ahora);
    final String dia = capitalizar(formatearDiaLargo(reserva.fecha));
    final String rango = rangoDeReserva(reserva);
    final bool esHoy = mismoDia(reserva.fecha, ahora);
    // El QR se muestra apagado cuando todavía no sirve o ya no sirve, para
    // que nadie lo presente creyendo que funciona.
    final bool apagado = estado != EstadoDelCodigo.vigente;

    final (IconData icono, String etiqueta, Color color) = switch (estado) {
      EstadoDelCodigo.vigente => (
          Icons.check_circle_outline,
          'Activo ahora',
          esquema.primary,
        ),
      EstadoDelCodigo.proximo => (
          Icons.schedule,
          'Todavía no está activo',
          esquema.outline,
        ),
      EstadoDelCodigo.usado => (
          Icons.how_to_reg,
          'Ingreso registrado',
          esquema.primary,
        ),
      EstadoDelCodigo.vencido => (
          Icons.event_busy,
          'Vencido',
          esquema.error,
        ),
      EstadoDelCodigo.cancelado => (
          Icons.cancel_outlined,
          'Cancelado',
          esquema.error,
        ),
    };

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
        child: Column(
          children: <Widget>[
            Text(
              esHoy ? 'Hoy · $dia' : dia,
              style: textos.titleMedium,
              textAlign: TextAlign.center,
            ),
            if (rango.isNotEmpty)
              Text(rango, style: textos.titleSmall, textAlign: TextAlign.center),
            Text(
              nombreDeZona,
              style:
                  textos.bodyMedium?.copyWith(color: esquema.onSurfaceVariant),
            ),
            const SizedBox(height: 16),
            Semantics(
              label: 'Código QR de tu reserva',
              child: Opacity(
                opacity: apagado ? 0.25 : 1,
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    // Fondo blanco siempre, también en tema oscuro: la
                    // cámara lee mejor negro sobre blanco. El marco verde
                    // es el del storyboard (pantalla 12).
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: esquema.primary, width: 6),
                  ),
                  child: QrImageView(
                    data: reserva.codigoQr,
                    version: QrVersions.auto,
                    size: 220,
                    backgroundColor: Colors.white,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            SelectableText(
              'Código ${codigoCorto(reserva.codigoQr)}',
              style: textos.labelLarge,
            ),
            const SizedBox(height: 14),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                Icon(icono, color: color, size: 20),
                const SizedBox(width: 6),
                Text(etiqueta, style: textos.titleSmall?.copyWith(color: color)),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              explicacionDelCodigo(reserva, ahora),
              textAlign: TextAlign.center,
              style: textos.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }
}

class _SinReserva extends StatelessWidget {
  const _SinReserva();

  @override
  Widget build(BuildContext context) {
    final ColorScheme esquema = Theme.of(context).colorScheme;
    final TextTheme textos = Theme.of(context).textTheme;

    return Column(
      children: <Widget>[
        const SizedBox(height: 24),
        Icon(Icons.qr_code_2, size: 56, color: esquema.outline),
        const SizedBox(height: 12),
        Text(
          'No tienes reservas para hoy ni para los próximos días.',
          style: textos.titleMedium,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        Text(
          'Cada reserva trae su propio código de ingreso. Reserva un cupo y '
          'aquí aparecerá el código.',
          style: textos.bodyMedium,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 16),
        FilledButton(
          onPressed: () => Navigator.of(context).pushNamed(Rutas.rf02Reservas),
          child: const Text('Reservar un cupo'),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------
// Validar ingresos (personal del gimnasio)
// ---------------------------------------------------------------------

/// La vista del personal en la entrada: escanear el QR o buscar por
/// documento. Es pública para poder probarla sola.
class VistaValidarIngresos extends StatefulWidget {
  const VistaValidarIngresos({super.key, required this.abrirEscaner});

  final Future<String?> Function(BuildContext contexto) abrirEscaner;

  @override
  State<VistaValidarIngresos> createState() => _VistaValidarIngresosState();
}

class _VistaValidarIngresosState extends State<VistaValidarIngresos> {
  final GlobalKey<FormState> _formulario = GlobalKey<FormState>();
  final TextEditingController _documento = TextEditingController();

  bool _trabajando = false;
  RespuestaValidacion? _ultima;
  String? _error;

  /// null: no se ha buscado. Lista vacía: se buscó y no hay reservas.
  List<ReservaDeHoy>? _encontradas;

  @override
  void dispose() {
    _documento.dispose();
    super.dispose();
  }

  Future<void> _escanear() async {
    final String? codigo = await widget.abrirEscaner(context);
    if (codigo == null || !mounted) return;
    await _validar(() => Repositorios.reservas.validarIngreso(codigo));
  }

  Future<void> _validarManual(ReservaDeHoy r) async {
    await _validar(
      () => Repositorios.reservas.validarIngresoManual(r.reservaId),
    );
    // La lista se pone al día para que la reserva salga como validada.
    if (mounted && _encontradas != null) await _buscar(silencioso: true);
  }

  Future<void> _validar(Future<RespuestaValidacion> Function() pedir) async {
    setState(() {
      _trabajando = true;
      _error = null;
    });

    RespuestaValidacion? respuesta;
    String? fallo;
    try {
      respuesta = await pedir();
    } on ErrorDeDatos catch (e) {
      fallo = e.mensaje;
    } catch (_) {
      fallo = 'No se pudo validar el ingreso. Inténtalo de nuevo.';
    }

    if (!mounted) return;
    setState(() {
      _trabajando = false;
      _ultima = respuesta;
      _error = fallo;
    });
  }

  Future<void> _buscar({bool silencioso = false}) async {
    if (!silencioso && !(_formulario.currentState?.validate() ?? false)) {
      return;
    }
    FocusScope.of(context).unfocus();

    setState(() {
      _trabajando = true;
      if (!silencioso) _error = null;
    });

    List<ReservaDeHoy>? encontradas;
    String? fallo;
    try {
      encontradas = await Repositorios.reservas
          .reservasDeHoyPorDocumento(_documento.text.trim());
    } on ErrorDeDatos catch (e) {
      fallo = e.mensaje;
    } catch (_) {
      fallo = 'No se pudo buscar la reserva. Inténtalo de nuevo.';
    }

    if (!mounted) return;
    setState(() {
      _trabajando = false;
      if (encontradas != null) _encontradas = encontradas;
      if (fallo != null) _error = fallo;
    });
  }

  @override
  Widget build(BuildContext context) {
    final TextTheme textos = Theme.of(context).textTheme;
    final RespuestaValidacion? ultima = _ultima;
    final List<ReservaDeHoy>? encontradas = _encontradas;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
      children: <Widget>[
        FilledButton.icon(
          onPressed: _trabajando ? null : _escanear,
          icon: const Icon(Icons.qr_code_scanner),
          label: const Text('Escanear código QR'),
        ),
        if (_trabajando) ...<Widget>[
          const SizedBox(height: 16),
          const Center(
            child: CircularProgressIndicator(semanticsLabel: 'Validando'),
          ),
        ],
        if (_error != null) ...<Widget>[
          const SizedBox(height: 16),
          _Aviso(texto: _error!, esError: true),
        ],
        if (ultima != null) ...<Widget>[
          const SizedBox(height: 16),
          TarjetaDeValidacion(respuesta: ultima),
        ],
        const SizedBox(height: 28),
        Text('¿No puede mostrar el código?', style: textos.titleMedium),
        const SizedBox(height: 4),
        Text(
          'Busca a la persona por su número de documento y valida su '
          'reserva de hoy.',
          style: textos.bodyMedium,
        ),
        const SizedBox(height: 12),
        Form(
          key: _formulario,
          child: TextFormField(
            controller: _documento,
            keyboardType: TextInputType.number,
            textInputAction: TextInputAction.search,
            decoration: const InputDecoration(
              labelText: 'Número de documento',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.badge_outlined),
            ),
            validator: validarDocumentoDeBusqueda,
            onFieldSubmitted: (_) => _buscar(),
          ),
        ),
        const SizedBox(height: 10),
        OutlinedButton.icon(
          onPressed: _trabajando ? null : () => _buscar(),
          icon: const Icon(Icons.search),
          label: const Text('Buscar reserva de hoy'),
        ),
        if (encontradas != null) ...<Widget>[
          const SizedBox(height: 12),
          if (encontradas.isEmpty)
            const _Aviso(
              texto: 'Esa persona no tiene reservas activas hoy. Sin reserva '
                  'no puede ingresar.',
              esError: false,
            ),
          for (final ReservaDeHoy r in encontradas)
            Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                title: Text(r.persona),
                subtitle: Text(
                  '${horaCorta(r.horaInicio)} – ${horaCorta(r.horaFin)} · '
                  '${r.zona}',
                ),
                trailing: r.validada
                    ? const Chip(
                        avatar: Icon(Icons.how_to_reg, size: 18),
                        label: Text('Ya ingresó'),
                      )
                    : TextButton(
                        onPressed:
                            _trabajando ? null : () => _validarManual(r),
                        child: const Text('Validar'),
                      ),
              ),
            ),
        ],
      ],
    );
  }
}

/// El resultado grande de una validación: verde si puede ingresar, rojo
/// si no, con ícono y texto para no depender solo del color (RNF13).
class TarjetaDeValidacion extends StatelessWidget {
  const TarjetaDeValidacion({super.key, required this.respuesta});

  final RespuestaValidacion respuesta;

  @override
  Widget build(BuildContext context) {
    final ColorScheme esquema = Theme.of(context).colorScheme;
    final TextTheme textos = Theme.of(context).textTheme;

    final bool ok = respuesta.esValido;
    final Color fondo = ok ? esquema.primaryContainer : esquema.errorContainer;
    final Color texto =
        ok ? esquema.onPrimaryContainer : esquema.onErrorContainer;

    final String? persona = respuesta.persona;
    final String? inicio = respuesta.horaInicio;
    final String? fin = respuesta.horaFin;
    final DateTime? registrada = respuesta.registradaEn;

    final List<String> detalles = <String>[
      if (inicio != null && fin != null)
        'Franja ${horaCorta(inicio)} – ${horaCorta(fin)}',
      if (respuesta.zona != null) respuesta.zona!,
      if (registrada != null) 'Ingreso: ${horaDelReloj(registrada)}',
    ];

    return Semantics(
      liveRegion: true,
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: fondo,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Icon(
                  ok ? Icons.check_circle : Icons.block,
                  color: texto,
                  size: 32,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    respuesta.titulo,
                    style: textos.titleLarge?.copyWith(color: texto),
                  ),
                ),
              ],
            ),
            if (persona != null) ...<Widget>[
              const SizedBox(height: 10),
              Text(
                persona,
                style: textos.titleMedium?.copyWith(color: texto),
              ),
            ],
            if (detalles.isNotEmpty)
              Text(
                detalles.join(' · '),
                style: textos.bodyMedium?.copyWith(color: texto),
              ),
            const SizedBox(height: 8),
            Text(
              respuesta.mensaje,
              style: textos.bodyMedium?.copyWith(color: texto),
            ),
          ],
        ),
      ),
    );
  }
}

class _Aviso extends StatelessWidget {
  const _Aviso({required this.texto, required this.esError});

  final String texto;
  final bool esError;

  @override
  Widget build(BuildContext context) {
    final ColorScheme esquema = Theme.of(context).colorScheme;
    final Color fondo =
        esError ? esquema.errorContainer : esquema.surfaceContainerHighest;
    final Color color =
        esError ? esquema.onErrorContainer : esquema.onSurfaceVariant;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: fondo,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(Icons.info_outline, size: 20, color: color),
          const SizedBox(width: 10),
          Expanded(child: Text(texto, style: TextStyle(color: color))),
        ],
      ),
    );
  }
}
