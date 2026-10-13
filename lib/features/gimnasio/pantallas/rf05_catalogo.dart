import 'package:flutter/material.dart';

import '../../../core/datos/errores.dart';
import '../../../core/datos/repositorios.dart';
import '../../../core/modelos/maquina.dart';
import '../../../core/modelos/zona.dart';
import '../reglas_catalogo.dart';
import 'rf05_detalle_maquina.dart';

/// RF5 - Consulta de catálogo de máquinas y ejercicios
///
/// Módulo: gimnasio | Responsable: Sergio
///
/// Muestra las máquinas del gimnasio agrupadas por categoría (HU12), con
/// su estado, y deja buscar por nombre, ejercicio o grupo muscular.
/// Al tocar una máquina se abre su ficha con los ejercicios y sus
/// instrucciones (HU13). Sigue el flujo del CU05.
class PantallaCatalogo extends StatefulWidget {
  const PantallaCatalogo({super.key});

  @override
  State<PantallaCatalogo> createState() => _PantallaCatalogoState();
}

class _PantallaCatalogoState extends State<PantallaCatalogo> {
  final TextEditingController _busqueda = TextEditingController();

  bool _cargando = true;
  String? _errorDeCarga;
  List<Zona> _zonas = const <Zona>[];
  List<Maquina> _maquinas = const <Maquina>[];

  /// La categoría elegida en los filtros; null es "Todas".
  int? _zonaElegida;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  @override
  void dispose() {
    _busqueda.dispose();
    super.dispose();
  }

  Future<void> _cargar() async {
    setState(() {
      _cargando = true;
      _errorDeCarga = null;
    });
    await _consultar();
    if (mounted) setState(() => _cargando = false);
  }

  /// Trae zonas y máquinas. Lo usa también "deslizar para actualizar",
  /// que no muestra la rueda de carga de pantalla completa.
  Future<void> _consultar() async {
    try {
      final List<Zona> zonas = await Repositorios.gimnasio.zonas();
      final List<Maquina> maquinas = await Repositorios.gimnasio.maquinas();
      if (!mounted) return;
      setState(() {
        _zonas = zonas;
        _maquinas = maquinas;
        _errorDeCarga = null;
        // Si la categoría elegida desapareció, se vuelve a "Todas".
        if (_zonaElegida != null &&
            !zonas.any((Zona z) => z.id == _zonaElegida && z.activa)) {
          _zonaElegida = null;
        }
      });
    } on ErrorDeDatos catch (e) {
      if (!mounted) return;
      setState(() => _errorDeCarga = e.mensaje);
    }
  }

  void _abrirFicha(Maquina maquina, Zona zona) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => PantallaDetalleMaquina(
          maquina: maquina,
          categoria: zona.nombre,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Catálogo de máquinas')),
      body: _cuerpo(context),
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

    // CU05, flujo 4c: sin catálogo cargado se dice, en vez de mostrar
    // una lista vacía.
    if (maquinasVisibles(_maquinas).isEmpty) {
      return RefreshIndicator(
        onRefresh: _consultar,
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: const <Widget>[
            SizedBox(height: 40),
            _Vacio(
              icono: Icons.inventory_2_outlined,
              titulo: 'El catálogo no está disponible',
              texto: 'Todavía no hay máquinas registradas. Vuelve a '
                  'consultar más tarde.',
            ),
          ],
        ),
      );
    }

    final List<GrupoDeCatalogo> grupos = agruparPorCategoria(
      zonas: _zonas,
      maquinas: _maquinas,
      zonaElegida: _zonaElegida,
      busqueda: _busqueda.text,
    );

    return RefreshIndicator(
      onRefresh: _consultar,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: <Widget>[
          _campoDeBusqueda(),
          const SizedBox(height: 12),
          _filtrosDeCategoria(),
          const SizedBox(height: 8),
          if (grupos.isEmpty)
            // CU05, flujo 3a: la búsqueda no arrojó resultados.
            const Padding(
              padding: EdgeInsets.only(top: 32),
              child: _Vacio(
                icono: Icons.search_off,
                titulo: 'No encontramos máquinas',
                texto: 'Prueba con otra palabra o elige la categoría '
                    '"Todas".',
              ),
            )
          else
            for (final GrupoDeCatalogo g in grupos) ..._seccion(context, g),
        ],
      ),
    );
  }

  Widget _campoDeBusqueda() {
    return TextField(
      controller: _busqueda,
      textInputAction: TextInputAction.search,
      onChanged: (_) => setState(() {}),
      decoration: InputDecoration(
        hintText: 'Buscar máquina, ejercicio o grupo muscular',
        prefixIcon: const Icon(Icons.search),
        suffixIcon: _busqueda.text.isEmpty
            ? null
            : IconButton(
                tooltip: 'Borrar búsqueda',
                icon: const Icon(Icons.close),
                onPressed: () => setState(_busqueda.clear),
              ),
        border: const OutlineInputBorder(),
      ),
    );
  }

  Widget _filtrosDeCategoria() {
    final List<Zona> activas = _zonas.where((Zona z) => z.activa).toList();

    return Wrap(
      spacing: 8,
      runSpacing: 4,
      children: <Widget>[
        ChoiceChip(
          label: const Text('Todas'),
          selected: _zonaElegida == null,
          onSelected: (_) => setState(() => _zonaElegida = null),
        ),
        for (final Zona z in activas)
          ChoiceChip(
            label: Text(z.nombre),
            selected: _zonaElegida == z.id,
            onSelected: (_) => setState(() => _zonaElegida = z.id),
          ),
      ],
    );
  }

  List<Widget> _seccion(BuildContext context, GrupoDeCatalogo grupo) {
    final TextTheme textos = Theme.of(context).textTheme;
    final ColorScheme esquema = Theme.of(context).colorScheme;
    final String descripcion = (grupo.zona.descripcion ?? '').trim();

    return <Widget>[
      Padding(
        padding: const EdgeInsets.only(top: 20, bottom: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(grupo.zona.nombre, style: textos.titleMedium),
            if (descripcion.isNotEmpty)
              Text(
                descripcion,
                style: textos.bodySmall
                    ?.copyWith(color: esquema.onSurfaceVariant),
              ),
          ],
        ),
      ),
      for (final Maquina m in grupo.maquinas)
        _TarjetaMaquina(
          maquina: m,
          alTocar: () => _abrirFicha(m, grupo.zona),
        ),
    ];
  }
}

// ---------------------------------------------------------------------
// Piezas de este archivo
// ---------------------------------------------------------------------

class _TarjetaMaquina extends StatelessWidget {
  const _TarjetaMaquina({required this.maquina, required this.alTocar});

  final Maquina maquina;
  final VoidCallback alTocar;

  @override
  Widget build(BuildContext context) {
    final TextTheme textos = Theme.of(context).textTheme;
    final ColorScheme esquema = Theme.of(context).colorScheme;
    final Maquina m = maquina;
    final int n = m.ejercicios.length;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: alTocar,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              SizedBox(
                width: 64,
                child: ImagenDeMaquina(url: m.imagenUrl, alto: 64),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(m.nombre, style: textos.titleSmall),
                    if ((m.descripcion ?? '').trim().isNotEmpty) ...<Widget>[
                      const SizedBox(height: 2),
                      Text(
                        m.descripcion!,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: textos.bodySmall
                            ?.copyWith(color: esquema.onSurfaceVariant),
                      ),
                    ],
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: <Widget>[
                        EtiquetaDeEstado(estado: m.estado),
                        Text(
                          n == 1 ? '1 ejercicio' : '$n ejercicios',
                          style: textos.bodySmall,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right),
            ],
          ),
        ),
      ),
    );
  }
}

class _Vacio extends StatelessWidget {
  const _Vacio({
    required this.icono,
    required this.titulo,
    required this.texto,
  });

  final IconData icono;
  final String titulo;
  final String texto;

  @override
  Widget build(BuildContext context) {
    final TextTheme textos = Theme.of(context).textTheme;
    final ColorScheme esquema = Theme.of(context).colorScheme;

    return Column(
      children: <Widget>[
        Icon(icono, size: 44, color: esquema.onSurfaceVariant),
        const SizedBox(height: 12),
        Text(titulo, style: textos.titleMedium, textAlign: TextAlign.center),
        const SizedBox(height: 6),
        Text(
          texto,
          textAlign: TextAlign.center,
          style: textos.bodyMedium?.copyWith(color: esquema.onSurfaceVariant),
        ),
      ],
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
            child:
                Text(texto, style: TextStyle(color: esquema.onErrorContainer)),
          ),
        ],
      ),
    );
  }
}
