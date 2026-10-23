import 'package:flutter/material.dart';

import '../../../core/datos/errores.dart';
import '../../../core/datos/repositorios.dart';
import '../../../core/modelos/rutina.dart';
import '../reglas_rutinas.dart';
import 'rf11_nueva_rutina.dart';

/// RF11 - Gestión de rutinas de ejercicio
///
/// Módulo: entrenamiento
///
/// Es la pantalla "Mis rutinas" del CU11: las rutinas de la persona con
/// el contador ("2 de 3 rutinas"), el detalle de cada ejercicio (máquina,
/// días, series, repeticiones o minutos) y las opciones de crear y
/// eliminar.
///
/// Reglas que decide la base de datos (supabase/schema.sql):
/// - máximo 3 rutinas por persona, aunque la pidan dos celulares a la vez;
/// - la rutina se guarda completa o no se guarda (crear_rutina);
/// - eliminar una rutina que ya no existe no es un error (eliminar_rutina).
///
/// El formulario de una rutina nueva está en rf11_nueva_rutina.dart.
class PantallaRutinas extends StatefulWidget {
  const PantallaRutinas({super.key});

  @override
  State<PantallaRutinas> createState() => _PantallaRutinasState();
}

class _PantallaRutinasState extends State<PantallaRutinas> {
  bool _cargando = true;
  String? _error;
  List<Rutina> _rutinas = <Rutina>[];

  /// La rutina que se está eliminando en este momento, si hay una.
  int? _eliminando;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  // -------------------------------------------------------------------
  // Datos
  // -------------------------------------------------------------------

  /// Con [silencioso] no tapa la pantalla con el indicador de carga; si
  /// falla, avisa con un mensaje y deja lo que ya había.
  Future<void> _cargar({bool silencioso = false}) async {
    if (!silencioso) {
      setState(() {
        _cargando = true;
        _error = null;
      });
    }

    try {
      final List<Rutina> rutinas = await Repositorios.entrenamiento.misRutinas();
      if (!mounted) return;
      setState(() {
        _rutinas = rutinas;
        _cargando = false;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      final String fallo = e is ErrorDeDatos
          ? e.mensaje
          : 'No se pudieron cargar tus rutinas. Inténtalo de nuevo.';
      if (silencioso) {
        _avisar(fallo);
      } else {
        setState(() {
          _cargando = false;
          _error = fallo;
        });
      }
    }
  }

  void _avisar(String texto) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(texto)));
  }

  bool get _hayCupo => _rutinas.length < maximoRutinas;

  // -------------------------------------------------------------------
  // Crear
  // -------------------------------------------------------------------

  Future<void> _nuevaRutina() async {
    final bool? creada = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (BuildContext _) => const PantallaNuevaRutina(),
      ),
    );
    if (!mounted) return;
    if (creada == true) _avisar('Rutina creada correctamente');
    await _cargar(silencioso: true);
  }

  // -------------------------------------------------------------------
  // Eliminar
  // -------------------------------------------------------------------

  Future<void> _eliminar(Rutina rutina) async {
    final bool confirmo = await _confirmarEliminacion(rutina);
    if (!confirmo || !mounted) return;

    setState(() => _eliminando = rutina.id);

    String mensaje;
    try {
      final ResultadoEliminarRutina r =
          await Repositorios.entrenamiento.eliminarRutina(rutina.id);
      mensaje = r.mensaje;
    } on ErrorDeDatos catch (e) {
      mensaje = e.mensaje;
    } catch (_) {
      mensaje = 'No se pudo eliminar la rutina. Inténtalo de nuevo.';
    }

    if (!mounted) return;
    setState(() => _eliminando = null);
    _avisar(mensaje);

    // Pase lo que pase, la lista y el contador se ponen al día con la base
    // (por ejemplo, si se eliminó desde otro dispositivo).
    await _cargar(silencioso: true);
  }

  Future<bool> _confirmarEliminacion(Rutina rutina) async {
    final bool? respuesta = await showDialog<bool>(
      context: context,
      builder: (BuildContext contexto) => AlertDialog(
        title: const Text('¿Eliminar esta rutina?'),
        content: Text(
          '${_queSeBorra(rutina)} Esta acción no se puede deshacer.',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(contexto).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(contexto).pop(true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    return respuesta ?? false;
  }

  /// "«Fuerza A» y sus 3 ejercicios se borrarán."
  String _queSeBorra(Rutina rutina) {
    final int n = rutina.ejercicios.length;
    final String nombre = '«${rutina.nombre}»';
    if (n == 0) return '$nombre se borrará.';
    if (n == 1) return '$nombre y su ejercicio se borrarán.';
    return '$nombre y sus $n ejercicios se borrarán.';
  }

  // -------------------------------------------------------------------
  // Pantalla
  // -------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Mis rutinas')),
      body: RefreshIndicator(
        onRefresh: () => _cargar(silencioso: true),
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
          children: _contenido(context),
        ),
      ),
    );
  }

  List<Widget> _contenido(BuildContext context) {
    final TextTheme textos = Theme.of(context).textTheme;

    if (_cargando) {
      return const <Widget>[
        Padding(
          padding: EdgeInsets.symmetric(vertical: 40),
          child: Center(
            child:
                CircularProgressIndicator(semanticsLabel: 'Cargando rutinas'),
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

    return <Widget>[
      Text(textoDelContador(_rutinas.length), style: textos.titleMedium),
      const SizedBox(height: 12),
      // A todo el ancho: el tema le da a los FilledButton un ancho mínimo
      // infinito, así que no pueden ir dentro de una Row.
      FilledButton.icon(
        onPressed: _hayCupo && _eliminando == null ? _nuevaRutina : null,
        icon: const Icon(Icons.add),
        label: const Text('Nueva rutina'),
      ),
      if (!_hayCupo) ...<Widget>[
        const SizedBox(height: 12),
        const _Aviso(
          texto: 'Ya tienes 3 rutinas, que es el máximo. Elimina una para '
              'poder crear otra.',
        ),
      ],
      const SizedBox(height: 16),
      if (_rutinas.isEmpty)
        const _SinRutinas()
      else
        for (final Rutina r in _rutinas)
          _TarjetaDeRutina(
            rutina: r,
            eliminando: _eliminando == r.id,
            // Mientras se elimina una, las demás esperan.
            alEliminar: _eliminando == null ? () => _eliminar(r) : null,
          ),
    ];
  }
}

// ---------------------------------------------------------------------
// Piezas de la pantalla
// ---------------------------------------------------------------------

class _TarjetaDeRutina extends StatelessWidget {
  const _TarjetaDeRutina({
    required this.rutina,
    required this.eliminando,
    required this.alEliminar,
  });

  final Rutina rutina;
  final bool eliminando;
  final VoidCallback? alEliminar;

  @override
  Widget build(BuildContext context) {
    final ColorScheme esquema = Theme.of(context).colorScheme;
    final TextTheme textos = Theme.of(context).textTheme;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 4, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Row(
              children: <Widget>[
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(rutina.nombre, style: textos.titleMedium),
                      Text(
                        textoDeEjercicios(rutina.ejercicios.length),
                        style: textos.bodySmall
                            ?.copyWith(color: esquema.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
                if (eliminando)
                  const Padding(
                    padding: EdgeInsets.all(12),
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  )
                else
                  IconButton(
                    tooltip: 'Eliminar rutina',
                    color: esquema.error,
                    icon: const Icon(Icons.delete_outline),
                    onPressed: alEliminar,
                  ),
              ],
            ),
            for (final EjercicioDeRutina e in rutina.ejercicios)
              Padding(
                padding: const EdgeInsets.only(top: 10, right: 12),
                child: _LineaDeEjercicio(ejercicio: e),
              ),
          ],
        ),
      ),
    );
  }
}

class _LineaDeEjercicio extends StatelessWidget {
  const _LineaDeEjercicio({required this.ejercicio});

  final EjercicioDeRutina ejercicio;

  @override
  Widget build(BuildContext context) {
    final ColorScheme esquema = Theme.of(context).colorScheme;
    final TextTheme textos = Theme.of(context).textTheme;
    final TextStyle? secundario =
        textos.bodyMedium?.copyWith(color: esquema.onSurfaceVariant);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.only(top: 2),
          child: Icon(Icons.fitness_center, size: 18, color: esquema.primary),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(ejercicio.nombreEjercicio, style: textos.bodyLarge),
              Text(
                '${ejercicio.nombreMaquina ?? 'Máquina retirada del catálogo'}'
                ' · ${textoDeDias(ejercicio.dias)}',
                style: secundario,
              ),
              Text(
                textoDeCarga(
                  series: ejercicio.series,
                  repeticiones: ejercicio.repeticiones,
                  minutos: ejercicio.minutos,
                ),
                style: secundario,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _SinRutinas extends StatelessWidget {
  const _SinRutinas();

  @override
  Widget build(BuildContext context) {
    final ColorScheme esquema = Theme.of(context).colorScheme;
    final TextTheme textos = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.only(top: 24),
      child: Column(
        children: <Widget>[
          Icon(Icons.fitness_center, size: 48, color: esquema.outline),
          const SizedBox(height: 12),
          Text(
            'Todavía no tienes rutinas.',
            style: textos.titleMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          Text(
            'Arma una con los ejercicios, las máquinas, los días y las '
            'repeticiones que vas a hacer.',
            style: textos.bodyMedium,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _Aviso extends StatelessWidget {
  const _Aviso({required this.texto, this.esError = false});

  final String texto;
  final bool esError;

  @override
  Widget build(BuildContext context) {
    final ColorScheme esquema = Theme.of(context).colorScheme;
    final Color fondo =
        esError ? esquema.errorContainer : esquema.secondaryContainer;
    final Color tinta =
        esError ? esquema.onErrorContainer : esquema.onSecondaryContainer;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: fondo,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(Icons.info_outline, size: 20, color: tinta),
          const SizedBox(width: 10),
          Expanded(child: Text(texto, style: TextStyle(color: tinta))),
        ],
      ),
    );
  }
}
