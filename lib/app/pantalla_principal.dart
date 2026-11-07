import 'package:flutter/material.dart';

import '../core/datos/errores.dart';
import '../core/datos/repositorios.dart';
import '../core/modelos/maquina.dart';
import '../core/modelos/medicion.dart';
import '../core/modelos/normativa.dart';
import '../core/modelos/perfil.dart';
import '../core/modelos/reserva.dart';
import '../core/modelos/zona.dart';
import '../core/rutas.dart';
import '../features/reservas/pantallas/rf02_reservas.dart';
import '../features/reservas/pantallas/rf04_asistencia_qr.dart';
import '../features/reservas/reglas_cancelacion.dart';
import '../features/reservas/reglas_reservas.dart';

/// Pantalla principal de UFIT, según el storyboard de la Entrega 2B
/// (pantallas 07, 13 y 27): barra inferior con Inicio, Reservas, Mi QR,
/// Info y Perfil.
///
/// Igual que main.dart, esto es la capa de composición: es lo único fuera
/// de main.dart que junta pantallas de varios módulos. Por eso vive en
/// lib/app/ y no dentro de un módulo. Casi todo se abre por nombre de ruta;
/// solo las dos pestañas que se muestran dentro de esta pantalla (RF2 y
/// RF4) se importan directamente.
class PantallaPrincipal extends StatefulWidget {
  const PantallaPrincipal({super.key, this.reloj = ahoraEnColombia});

  /// De dónde sale "ahora" (hora de Colombia). Las pruebas lo cambian.
  final DateTime Function() reloj;

  @override
  State<PantallaPrincipal> createState() => _PantallaPrincipalState();
}

class _PantallaPrincipalState extends State<PantallaPrincipal> {
  int _pestana = 0;

  void _irA(int pestana) => setState(() => _pestana = pestana);

  @override
  Widget build(BuildContext context) {
    // Cada pestaña se construye al entrar, así siempre muestra datos al
    // día (por ejemplo, el QR de una reserva recién hecha).
    final Widget cuerpo = switch (_pestana) {
      0 => _Inicio(reloj: widget.reloj, irA: _irA),
      1 => PantallaReservas(reloj: widget.reloj),
      2 => PantallaAsistenciaQr(reloj: widget.reloj),
      3 => const _InfoGimnasio(),
      _ => const _Perfil(),
    };

    return Scaffold(
      body: KeyedSubtree(key: ValueKey<int>(_pestana), child: cuerpo),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _pestana,
        onDestinationSelected: _irA,
        destinations: const <NavigationDestination>[
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'Inicio',
          ),
          NavigationDestination(
            icon: Icon(Icons.calendar_month_outlined),
            selectedIcon: Icon(Icons.calendar_month),
            label: 'Reservas',
          ),
          NavigationDestination(
            icon: Icon(Icons.qr_code_2_outlined),
            selectedIcon: Icon(Icons.qr_code_2),
            label: 'Mi QR',
          ),
          NavigationDestination(
            icon: Icon(Icons.info_outline),
            selectedIcon: Icon(Icons.info),
            label: 'Info',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person),
            label: 'Perfil',
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------
// Inicio (storyboard, pantalla 07)
// ---------------------------------------------------------------------

/// "¡Buenos días", "¡Buenas tardes" o "¡Buenas noches" según la hora.
String saludo(DateTime ahora) {
  if (ahora.hour < 12) return '¡Buenos días';
  if (ahora.hour < 19) return '¡Buenas tardes';
  return '¡Buenas noches';
}

/// Ingresos registrados en el mes de [ahora].
int asistenciasDelMes(Iterable<Reserva> reservas, DateTime ahora) => reservas
    .where((Reserva r) =>
        r.fecha.year == ahora.year &&
        r.fecha.month == ahora.month &&
        (r.estado == EstadoReserva.asistida || r.ingresoEn != null))
    .length;

class _Inicio extends StatefulWidget {
  const _Inicio({required this.reloj, required this.irA});

  final DateTime Function() reloj;
  final void Function(int pestana) irA;

  @override
  State<_Inicio> createState() => _InicioState();
}

class _InicioState extends State<_Inicio> {
  Perfil? _perfil;
  List<Reserva> _reservas = <Reserva>[];
  bool _cargando = true;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    final DateTime ahora = widget.reloj();
    Perfil? perfil = _perfil;
    List<Reserva> reservas = _reservas;
    try {
      await Future.wait<void>(<Future<void>>[
        Repositorios.perfiles.perfilActual().then((Perfil? v) => perfil = v),
        Repositorios.reservas
            .misReservas(
              desde: DateTime(ahora.year, ahora.month, 1),
              hasta: DateTime(ahora.year, ahora.month, ahora.day + 30),
            )
            .then((List<Reserva> v) => reservas = v),
      ]);
    } on ErrorDeDatos {
      // El inicio se muestra igual; los números quedan en "—".
    }
    if (!mounted) return;
    setState(() {
      _perfil = perfil;
      _reservas = reservas;
      _cargando = false;
    });
  }

  Future<void> _abrir(String ruta) async {
    await Navigator.of(context).pushNamed(ruta);
    if (mounted) await _cargar();
  }

  @override
  Widget build(BuildContext context) {
    final TextTheme textos = Theme.of(context).textTheme;
    final DateTime ahora = widget.reloj();
    final Perfil? perfil = _perfil;
    final List<Reserva> activas = reservasActivas(_reservas, ahora);

    final List<_Atajo> atajos = <_Atajo>[
      _Atajo(
        icono: Icons.event_available,
        titulo: 'Reservar cupo',
        alTocar: () => widget.irA(1),
      ),
      _Atajo(
        icono: Icons.qr_code_2,
        titulo: 'Mi código QR',
        alTocar: () => widget.irA(2),
      ),
      _Atajo(
        icono: Icons.info_outline,
        titulo: 'Info gimnasio',
        alTocar: () => widget.irA(3),
      ),
      _Atajo(
        icono: Icons.sports,
        titulo: 'Instructores',
        alTocar: () => _abrir(Rutas.rf07Instructores),
      ),
      _Atajo(
        icono: Icons.fitness_center,
        titulo: 'Mis rutinas',
        detalle: 'GESTIONAR RUTINAS →',
        destacado: true,
        alTocar: () => _abrir(Rutas.rf11Rutinas),
      ),
      _Atajo(
        icono: Icons.event_note,
        titulo: 'Mis reservas',
        alTocar: () => _abrir(Rutas.rf03CancelarReserva),
      ),
      _Atajo(
        icono: Icons.history,
        titulo: 'Historial',
        alTocar: () => _abrir(Rutas.rf09Historial),
      ),
      _Atajo(
        icono: Icons.monitor_weight_outlined,
        titulo: 'Mis medidas',
        alTocar: () => _abrir(Rutas.rf08Antropometria),
      ),
      if (perfil?.esPersonal ?? false)
        _Atajo(
          icono: Icons.qr_code_scanner,
          titulo: 'Validar ingresos',
          detalle: 'PERSONAL',
          alTocar: () => widget.irA(2),
        ),
      if (perfil?.esAdministrador ?? false) ...<_Atajo>[
        _Atajo(
          icono: Icons.dashboard_customize_outlined,
          titulo: 'Contenidos',
          detalle: 'ADMINISTRADOR',
          alTocar: () => _abrir(Rutas.rf13GestionContenidos),
        ),
        _Atajo(
          icono: Icons.insights,
          titulo: 'Estadísticas',
          detalle: 'ADMINISTRADOR',
          alTocar: () => _abrir(Rutas.rf12Estadisticas),
        ),
      ],
    ];

    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _cargar,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            children: <Widget>[
              _TarjetaSaludo(
                saludo: saludo(ahora),
                perfil: perfil,
                cargando: _cargando,
                asistencias: _cargando ? null : asistenciasDelMes(_reservas, ahora),
                activas: _cargando ? null : activas.length,
                proxima: activas.isEmpty ? null : activas.first,
              ),
              const SizedBox(height: 22),
              Text(
                'Acceso rápido',
                style: textos.titleMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 12),
              GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 1.35,
                children: <Widget>[
                  for (final _Atajo a in atajos) _TarjetaAtajo(atajo: a),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TarjetaSaludo extends StatelessWidget {
  const _TarjetaSaludo({
    required this.saludo,
    required this.perfil,
    required this.cargando,
    required this.asistencias,
    required this.activas,
    required this.proxima,
  });

  final String saludo;
  final Perfil? perfil;
  final bool cargando;
  final int? asistencias;
  final int? activas;
  final Reserva? proxima;

  @override
  Widget build(BuildContext context) {
    final ColorScheme esquema = Theme.of(context).colorScheme;
    final TextTheme textos = Theme.of(context).textTheme;
    final Color texto = esquema.onPrimary;
    final Perfil? p = perfil;
    final Reserva? siguiente = proxima;

    final String rol = switch (p?.rol) {
      RolUsuario.administrador => 'Administrador',
      RolUsuario.instructor => 'Instructor',
      _ => 'Comunidad UIS',
    };

    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[
            esquema.primary,
            Color.lerp(esquema.primary, Colors.black, 0.35)!,
          ],
        ),
      ),
      child: Stack(
        children: <Widget>[
          // Círculo decorativo, como en el storyboard.
          Positioned(
            right: -40,
            top: -40,
            child: Container(
              width: 150,
              height: 150,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.12),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text('$saludo 👋',
                    style: textos.bodyMedium?.copyWith(color: texto)),
                const SizedBox(height: 4),
                Text(
                  p?.nombreCompleto ?? (cargando ? ' ' : 'Bienvenido'),
                  style: textos.headlineSmall?.copyWith(
                    color: texto,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  p == null ? rol : '$rol · Documento ${p.documento}',
                  style: textos.bodySmall
                      ?.copyWith(color: texto.withValues(alpha: 0.85)),
                ),
                const SizedBox(height: 16),
                Row(
                  children: <Widget>[
                    _Cifra(
                      valor: asistencias?.toString() ?? '—',
                      etiqueta: 'Asistencias\neste mes',
                      color: texto,
                    ),
                    const SizedBox(width: 24),
                    _Cifra(
                      valor: activas?.toString() ?? '—',
                      etiqueta: 'Reservas\nactivas',
                      color: texto,
                    ),
                  ],
                ),
                if (siguiente != null) ...<Widget>[
                  const SizedBox(height: 12),
                  Text(
                    'Próxima: ${formatearDiaCorto(siguiente.fecha)}'
                    '${rangoDeReserva(siguiente).isEmpty ? '' : ' · ${rangoDeReserva(siguiente)}'}',
                    style: textos.labelLarge?.copyWith(color: texto),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Cifra extends StatelessWidget {
  const _Cifra({
    required this.valor,
    required this.etiqueta,
    required this.color,
  });

  final String valor;
  final String etiqueta;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final TextTheme textos = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(valor,
            style: textos.headlineMedium
                ?.copyWith(color: color, fontWeight: FontWeight.w800)),
        Text(etiqueta,
            style: textos.labelSmall
                ?.copyWith(color: color.withValues(alpha: 0.85))),
      ],
    );
  }
}

class _Atajo {
  const _Atajo({
    required this.icono,
    required this.titulo,
    required this.alTocar,
    this.detalle,
    this.destacado = false,
  });

  final IconData icono;
  final String titulo;
  final String? detalle;
  final bool destacado;
  final VoidCallback alTocar;
}

class _TarjetaAtajo extends StatelessWidget {
  const _TarjetaAtajo({required this.atajo});

  final _Atajo atajo;

  @override
  Widget build(BuildContext context) {
    final ColorScheme esquema = Theme.of(context).colorScheme;
    final TextTheme textos = Theme.of(context).textTheme;
    final String? detalle = atajo.detalle;

    return Material(
      color: esquema.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(
          color: atajo.destacado ? esquema.primary : esquema.outlineVariant,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: atajo.alTocar,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: <Widget>[
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: esquema.primary.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(atajo.icono, color: esquema.primary),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    atajo.titulo,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: textos.titleSmall
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                  if (detalle != null)
                    Text(
                      detalle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: textos.labelSmall?.copyWith(
                        color: esquema.primary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------
// Info del gimnasio (storyboard, pantalla 13)
// ---------------------------------------------------------------------

class _InfoGimnasio extends StatefulWidget {
  const _InfoGimnasio();

  @override
  State<_InfoGimnasio> createState() => _InfoGimnasioState();
}

class _InfoGimnasioState extends State<_InfoGimnasio> {
  List<Zona> _zonas = <Zona>[];
  List<Maquina> _maquinas = <Maquina>[];
  Normativa? _normativa;
  bool _cargando = true;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    List<Zona> zonas = _zonas;
    List<Maquina> maquinas = _maquinas;
    Normativa? normativa = _normativa;
    try {
      zonas = await Repositorios.gimnasio.zonas();
      maquinas = await Repositorios.gimnasio.maquinas();
    } on ErrorDeDatos {
      // Se muestran las tarjetas sin los números.
    }
    try {
      normativa = await Repositorios.gimnasio.normativaVigente();
    } on ErrorDeDatos {
      normativa = null;
    }
    if (!mounted) return;
    setState(() {
      _zonas = zonas;
      _maquinas = maquinas;
      _normativa = normativa;
      _cargando = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme esquema = Theme.of(context).colorScheme;
    final TextTheme textos = Theme.of(context).textTheme;

    // Las dadas de baja no hacen parte del inventario (igual que en el
    // RF5).
    final List<Maquina> inventario = _maquinas
        .where((Maquina m) => m.estado != EstadoMaquina.retirada)
        .toList();
    final int equipos =
        inventario.fold<int>(0, (int n, Maquina m) => n + m.cantidad);
    final Normativa? normativa = _normativa;
    final int reglas = normativa == null
        ? 0
        : normativa.contenido
            .split('\n')
            .where((String l) => l.trim().isNotEmpty)
            .length;

    return Scaffold(
      appBar: AppBar(title: const Text('Gimnasio UIS')),
      body: RefreshIndicator(
        onRefresh: _cargar,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          children: <Widget>[
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: esquema.primary,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    'Gimnasio de la UIS',
                    style: textos.titleMedium?.copyWith(
                      color: esquema.onPrimary,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Lunes a viernes · 6:00 a. m. – 8:00 p. m. · 75 cupos '
                    'por franja',
                    style: textos.bodySmall?.copyWith(color: esquema.onPrimary),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            _TarjetaEnlace(
              icono: Icons.gavel_outlined,
              titulo: 'Normativa del gimnasio',
              detalle: normativa == null
                  ? (_cargando ? 'Cargando…' : 'Reglas de uso')
                  : '$reglas normas de uso · versión ${normativa.version}',
              alTocar: () =>
                  Navigator.of(context).pushNamed(Rutas.rf06Normativa),
            ),
            _TarjetaEnlace(
              icono: Icons.fitness_center,
              titulo: 'Inventario de máquinas',
              detalle: _cargando
                  ? 'Cargando…'
                  : '$equipos equipos registrados',
              alTocar: () =>
                  Navigator.of(context).pushNamed(Rutas.rf05Catalogo),
            ),
            _TarjetaEnlace(
              icono: Icons.sports,
              titulo: 'Instructores',
              detalle: 'Quién acompaña cada franja',
              alTocar: () =>
                  Navigator.of(context).pushNamed(Rutas.rf07Instructores),
            ),
            const SizedBox(height: 6),
            Card(
              margin: EdgeInsets.zero,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      'Zonas del gimnasio',
                      style: textos.titleSmall
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 6),
                    for (final Zona z in _zonas)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Row(
                          children: <Widget>[
                            Icon(Icons.circle, size: 8, color: esquema.primary),
                            const SizedBox(width: 10),
                            Expanded(child: Text(z.nombre)),
                            Text(
                              '${inventario.where((Maquina m) => m.zonaId == z.id).length} máquinas',
                              style: textos.bodySmall?.copyWith(
                                  color: esquema.onSurfaceVariant),
                            ),
                          ],
                        ),
                      ),
                    if (_zonas.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Text(
                          _cargando ? 'Cargando…' : 'Sin conexión.',
                          style: textos.bodySmall,
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TarjetaEnlace extends StatelessWidget {
  const _TarjetaEnlace({
    required this.icono,
    required this.titulo,
    required this.detalle,
    required this.alTocar,
  });

  final IconData icono;
  final String titulo;
  final String detalle;
  final VoidCallback alTocar;

  @override
  Widget build(BuildContext context) {
    final ColorScheme esquema = Theme.of(context).colorScheme;
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      clipBehavior: Clip.antiAlias,
      child: ListTile(
        contentPadding: const EdgeInsets.fromLTRB(14, 6, 10, 6),
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: esquema.primary.withValues(alpha: 0.16),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icono, color: esquema.primary),
        ),
        title: Text(titulo,
            style: const TextStyle(fontWeight: FontWeight.w700)),
        subtitle: Text(detalle),
        trailing: const Icon(Icons.chevron_right),
        onTap: alTocar,
      ),
    );
  }
}

// ---------------------------------------------------------------------
// Perfil (storyboard, pantalla 27)
// ---------------------------------------------------------------------

class _Perfil extends StatefulWidget {
  const _Perfil();

  @override
  State<_Perfil> createState() => _PerfilState();
}

class _PerfilState extends State<_Perfil> {
  Perfil? _perfil;
  MedicionAntropometrica? _medicion;
  bool _cargando = true;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    Perfil? perfil = _perfil;
    MedicionAntropometrica? medicion = _medicion;
    try {
      perfil = await Repositorios.perfiles.perfilActual();
      final List<MedicionAntropometrica> medidas =
          await Repositorios.perfiles.misMediciones();
      medicion = medidas.isEmpty ? null : medidas.first;
    } on ErrorDeDatos {
      // Se muestra lo que se alcanzó a cargar.
    }
    if (!mounted) return;
    setState(() {
      _perfil = perfil;
      _medicion = medicion;
      _cargando = false;
    });
  }

  Future<void> _abrir(String ruta) async {
    await Navigator.of(context).pushNamed(ruta);
    if (mounted) await _cargar();
  }

  Future<void> _cerrarSesion() async {
    final bool? si = await showDialog<bool>(
      context: context,
      builder: (BuildContext c) => AlertDialog(
        title: const Text('¿Cerrar sesión?'),
        content: const Text('Tendrás que volver a ingresar con tu cuenta '
            'institucional.'),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(c).pop(false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.of(c).pop(true),
            child: const Text('Cerrar sesión'),
          ),
        ],
      ),
    );
    if (si == true) await Repositorios.perfiles.cerrarSesion();
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme esquema = Theme.of(context).colorScheme;
    final TextTheme textos = Theme.of(context).textTheme;
    final Perfil? p = _perfil;
    final MedicionAntropometrica? m = _medicion;

    final String iniciales = p == null
        ? ''
        : '${p.nombre.isEmpty ? '' : p.nombre[0]}'
                '${p.apellido.isEmpty ? '' : p.apellido[0]}'
            .toUpperCase();

    return Scaffold(
      appBar: AppBar(title: const Text('Mi perfil')),
      body: RefreshIndicator(
        onRefresh: _cargar,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          children: <Widget>[
            Card(
              margin: EdgeInsets.zero,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: <Widget>[
                    Container(
                      width: 56,
                      height: 56,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: esquema.primary,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Text(
                        iniciales,
                        style: textos.titleLarge?.copyWith(
                          color: esquema.onPrimary,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            p?.nombreCompleto ?? (_cargando ? 'Cargando…' : ''),
                            style: textos.titleMedium
                                ?.copyWith(fontWeight: FontWeight.w800),
                          ),
                          if (p != null) ...<Widget>[
                            Text(p.correo,
                                style: textos.bodySmall?.copyWith(
                                    color: esquema.onSurfaceVariant)),
                            Text('Documento ${p.documento} · ${nombreDeRol(p.rol)}',
                                style: textos.bodySmall?.copyWith(
                                    color: esquema.onSurfaceVariant)),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Card(
              margin: EdgeInsets.zero,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      'Datos antropométricos',
                      style: textos.titleSmall
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 10),
                    if (m == null)
                      Text(
                        _cargando
                            ? 'Cargando…'
                            : 'Todavía no registras tus medidas.',
                        style: textos.bodyMedium,
                      )
                    else
                      Row(
                        children: <Widget>[
                          Expanded(
                            child: _Dato(
                              etiqueta: 'Peso',
                              valor: '${_numero(m.pesoKg)} kg',
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _Dato(
                              etiqueta: 'Estatura',
                              valor: '${_numero(m.estaturaCm / 100, 2)} m',
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _Dato(
                              etiqueta: 'IMC',
                              valor: _numero(m.imc),
                            ),
                          ),
                        ],
                      ),
                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: () => _abrir(Rutas.rf08Antropometria),
                        child: Text(m == null
                            ? 'Registrar mis medidas'
                            : 'Ver y actualizar'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Card(
              margin: EdgeInsets.zero,
              clipBehavior: Clip.antiAlias,
              child: Column(
                children: <Widget>[
                  _Opcion(
                    icono: Icons.badge_outlined,
                    titulo: 'Mis datos personales',
                    alTocar: () => _abrir(Rutas.rf10DatosPersonales),
                  ),
                  _Opcion(
                    icono: Icons.history,
                    titulo: 'Historial de asistencia',
                    alTocar: () => _abrir(Rutas.rf09Historial),
                  ),
                  _Opcion(
                    icono: Icons.event_note,
                    titulo: 'Mis reservas activas',
                    alTocar: () => _abrir(Rutas.rf03CancelarReserva),
                  ),
                  _Opcion(
                    icono: Icons.fitness_center,
                    titulo: 'Mis rutinas',
                    alTocar: () => _abrir(Rutas.rf11Rutinas),
                  ),
                  if (p?.esAdministrador ?? false) ...<Widget>[
                    _Opcion(
                      icono: Icons.dashboard_customize_outlined,
                      titulo: 'Contenidos del gimnasio',
                      alTocar: () => _abrir(Rutas.rf13GestionContenidos),
                    ),
                    _Opcion(
                      icono: Icons.insights,
                      titulo: 'Estadísticas',
                      alTocar: () => _abrir(Rutas.rf12Estadisticas),
                    ),
                  ],
                  // Solo el administrador ve el menú con los 13 RF: un
                  // usuario no necesita saber qué es un requerimiento.
                  if (p?.esAdministrador ?? false)
                    _Opcion(
                      icono: Icons.developer_mode,
                      titulo: 'Menú de desarrollo (RF1 a RF13)',
                      alTocar: () => _abrir(Rutas.menuDesarrollo),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: esquema.error,
                minimumSize: const Size.fromHeight(48),
              ),
              onPressed: _cerrarSesion,
              icon: const Icon(Icons.logout),
              label: const Text('Cerrar sesión'),
            ),
          ],
        ),
      ),
    );
  }

  /// "58,5" o "21,3": coma decimal y sin ceros sobrantes.
  static String _numero(double v, [int decimales = 1]) {
    String t = v.toStringAsFixed(decimales);
    if (t.contains('.')) {
      t = t.replaceFirst(RegExp(r'0+$'), '').replaceFirst(RegExp(r'\.$'), '');
    }
    return t.replaceAll('.', ',');
  }
}

class _Dato extends StatelessWidget {
  const _Dato({required this.etiqueta, required this.valor});

  final String etiqueta;
  final String valor;

  @override
  Widget build(BuildContext context) {
    final ColorScheme esquema = Theme.of(context).colorScheme;
    final TextTheme textos = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: esquema.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(etiqueta,
              style: textos.labelSmall
                  ?.copyWith(color: esquema.onSurfaceVariant)),
          const SizedBox(height: 2),
          Text(valor,
              style:
                  textos.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
        ],
      ),
    );
  }
}

class _Opcion extends StatelessWidget {
  const _Opcion({
    required this.icono,
    required this.titulo,
    required this.alTocar,
  });

  final IconData icono;
  final String titulo;
  final VoidCallback alTocar;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icono),
      title: Text(titulo),
      trailing: const Icon(Icons.chevron_right),
      onTap: alTocar,
    );
  }
}
