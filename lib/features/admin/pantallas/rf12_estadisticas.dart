import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/datos/errores.dart';
import '../../../core/datos/repositorios.dart';
import '../../../core/modelos/estadisticas.dart';
import '../../../core/modelos/zona.dart';
import '../reglas_admin.dart';
import 'piezas_admin.dart';

/// RF12 - Visualización de estadísticas de ocupación y uso
///
/// Módulo: admin
///
/// El panel del CU12, solo para el administrador: indicadores del mes en
/// curso, filtros por fechas, zona y hora, ocupación por hora y por día,
/// asistencia efectiva frente a reservas por zona, y el estado del
/// inventario de máquinas. El reporte se puede copiar como CSV para
/// pegarlo en una hoja de cálculo (4a).
///
/// Los números los calcula la base (estadisticas_uso, migración 017). Si
/// alguien sin el rol llama a esa función, la base no responde datos y
/// deja el intento en la bitácora (1a).
class PantallaEstadisticas extends StatelessWidget {
  const PantallaEstadisticas({super.key, this.reloj = ahoraEnColombia});

  final DateTime Function() reloj;

  @override
  Widget build(BuildContext context) => SoloAdministrador(
        titulo: 'Estadísticas',
        construir: (_) => PanelEstadisticas(reloj: reloj),
      );
}

class PanelEstadisticas extends StatefulWidget {
  const PanelEstadisticas({super.key, this.reloj = ahoraEnColombia});

  final DateTime Function() reloj;

  @override
  State<PanelEstadisticas> createState() => _PanelEstadisticasState();
}

class _PanelEstadisticasState extends State<PanelEstadisticas> {
  late DateTime _desde =
      DateTime(widget.reloj().year, widget.reloj().month, 1);
  late DateTime _hasta =
      DateTime(widget.reloj().year, widget.reloj().month + 1, 0);
  int? _zonaId;
  int? _hora;

  List<Zona> _zonas = <Zona>[];
  bool _cargando = true;
  String? _error;
  EstadisticasDeUso? _datos;

  @override
  void initState() {
    super.initState();
    _consultar();
  }

  Future<void> _consultar() async {
    // CU12, 3a: con un rango inválido no se consulta.
    final String? problema = validarRangoDeFechas(_desde, _hasta);
    if (problema != null) {
      mostrarMensaje(context, problema);
      return;
    }

    setState(() {
      _cargando = true;
      _error = null;
    });
    try {
      if (_zonas.isEmpty) _zonas = await Repositorios.gimnasio.zonas();
      final EstadisticasDeUso datos = await Repositorios.admin.estadisticas(
        desde: _desde,
        hasta: _hasta,
        zonaId: _zonaId,
        hora: _hora == null ? null : '${_hora!.toString().padLeft(2, '0')}:00',
      );
      if (!mounted) return;
      setState(() {
        _datos = datos;
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

  Future<void> _elegirFechas() async {
    final DateTime hoy = soloFecha(widget.reloj());
    final DateTimeRange? r = await showDateRangePicker(
      context: context,
      firstDate: DateTime(hoy.year - 1),
      lastDate: DateTime(hoy.year + 1, 12, 31),
      initialDateRange: DateTimeRange(start: _desde, end: _hasta),
      helpText: 'Periodo del reporte',
      saveText: 'Aplicar',
    );
    if (r == null || !mounted) return;
    setState(() {
      _desde = r.start;
      _hasta = r.end;
    });
    await _consultar();
  }

  Future<void> _copiar() async {
    final EstadisticasDeUso? d = _datos;
    if (d == null) return;
    await Clipboard.setData(ClipboardData(text: reporteCsv(d)));
    if (mounted) {
      mostrarMensaje(
        context,
        'Reporte copiado. Pégalo en una hoja de cálculo (Excel o Google '
        'Sheets).',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final EstadisticasDeUso? d = _datos;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Estadísticas'),
        actions: <Widget>[
          IconButton(
            tooltip: 'Copiar reporte',
            icon: const Icon(Icons.content_copy),
            onPressed: d == null || d.resumen.sinDatos ? null : _copiar,
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _consultar,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
          children: <Widget>[
            _filtros(context),
            const SizedBox(height: 16),
            if (_cargando)
              const CargandoAdmin()
            else if (_error != null) ...<Widget>[
              AvisoAdmin(texto: _error!),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: _consultar,
                child: const Text('Reintentar'),
              ),
            ] else if (d != null)
              ..._contenido(context, d),
          ],
        ),
      ),
    );
  }

  Widget _filtros(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: <Widget>[
        OutlinedButton.icon(
          onPressed: _cargando ? null : _elegirFechas,
          icon: const Icon(Icons.date_range),
          label: Text('${fechaCorta(_desde)} – ${fechaCorta(_hasta)} '
              '${_hasta.year}'),
        ),
        DropdownButton<int?>(
          value: _zonaId,
          hint: const Text('Todas las zonas'),
          items: <DropdownMenuItem<int?>>[
            const DropdownMenuItem<int?>(
                value: null, child: Text('Todas las zonas')),
            for (final Zona z in _zonas)
              DropdownMenuItem<int?>(value: z.id, child: Text(z.nombre)),
          ],
          onChanged: _cargando
              ? null
              : (int? v) {
                  setState(() => _zonaId = v);
                  _consultar();
                },
        ),
        DropdownButton<int?>(
          value: _hora,
          hint: const Text('Todas las horas'),
          items: <DropdownMenuItem<int?>>[
            const DropdownMenuItem<int?>(
                value: null, child: Text('Todas las horas')),
            for (int h = horaApertura; h < horaCierre; h++)
              DropdownMenuItem<int?>(value: h, child: Text(horaEntera(h))),
          ],
          onChanged: _cargando
              ? null
              : (int? v) {
                  setState(() => _hora = v);
                  _consultar();
                },
        ),
      ],
    );
  }

  List<Widget> _contenido(BuildContext context, EstadisticasDeUso d) {
    final TextTheme textos = Theme.of(context).textTheme;
    final ResumenDeUso r = d.resumen;

    if (r.sinDatos) {
      // CU12, 4b: se dice claramente en lugar de mostrar gráficos vacíos.
      return <Widget>[
        AvisoAdmin(
          texto: r.franjas == 0
              ? 'No hay franjas publicadas en ese periodo. Elige otras fechas.'
              : 'No hay reservas en ese periodo con esos filtros, así que no '
                  'hay estadísticas que mostrar. Elige otras fechas, otra '
                  'zona u otra hora.',
          esError: false,
        ),
      ];
    }

    final ({UsoPorGrupo mayor, UsoPorGrupo menor})? extremos =
        extremosDeOcupacion(d.porHora);

    return <Widget>[
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: <Widget>[
          _Indicador(
            titulo: 'Asistencia efectiva',
            valor: porcentaje(r.asistenciaEfectiva),
            detalle: '${r.asistidas} de ${r.pasadas} reservas pasadas',
          ),
          _Indicador(
            titulo: 'Ocupación promedio',
            valor: porcentaje(r.ocupacionPromedio),
            detalle: 'de los cupos, en ${r.franjas} franjas',
          ),
          _Indicador(
            titulo: 'Reservas hechas',
            valor: '${r.reservas}',
            detalle: '${r.canceladas} canceladas · ${r.pendientes} por venir',
          ),
          _Indicador(
            titulo: 'No asistieron',
            valor: '${r.noAsistidas}',
            detalle: 'reservaron y no llegaron',
          ),
        ],
      ),
      if (extremos != null) ...<Widget>[
        const SizedBox(height: 16),
        Text(
          'Hora de mayor ocupación: ${extremos.mayor.etiqueta} '
          '(${porcentaje(extremos.mayor.ocupacion)}). '
          'Menor: ${extremos.menor.etiqueta} '
          '(${porcentaje(extremos.menor.ocupacion)}).',
          style: textos.bodyLarge,
        ),
      ],
      const SizedBox(height: 24),
      Text('Ocupación por hora', style: textos.titleMedium),
      const SizedBox(height: 8),
      _Barras(grupos: d.porHora),
      const SizedBox(height: 24),
      Text('Ocupación por día de la semana', style: textos.titleMedium),
      const SizedBox(height: 8),
      _Barras(grupos: d.porDia),
      const SizedBox(height: 24),
      Text('Reservas y asistencia por zona', style: textos.titleMedium),
      const SizedBox(height: 8),
      _TablaZonas(grupos: d.porZona),
      const SizedBox(height: 24),
      Text('Máquinas por zona', style: textos.titleMedium),
      const SizedBox(height: 8),
      for (final InventarioDeZona z in d.inventario)
        Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: Text(
            '${z.zona}: ${z.disponibles} disponibles · '
            '${z.fueraDeServicio} fuera de servicio o de baja',
            style: textos.bodyMedium,
          ),
        ),
    ];
  }
}

// ---------------------------------------------------------------------
// Piezas
// ---------------------------------------------------------------------

class _Indicador extends StatelessWidget {
  const _Indicador({
    required this.titulo,
    required this.valor,
    required this.detalle,
  });

  final String titulo;
  final String valor;
  final String detalle;

  @override
  Widget build(BuildContext context) {
    final TextTheme textos = Theme.of(context).textTheme;
    final ColorScheme esquema = Theme.of(context).colorScheme;

    return SizedBox(
      width: 170,
      child: Card(
        margin: EdgeInsets.zero,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(titulo,
                  style: textos.labelMedium
                      ?.copyWith(color: esquema.onSurfaceVariant)),
              const SizedBox(height: 4),
              Text(valor, style: textos.headlineSmall),
              const SizedBox(height: 2),
              Text(detalle, style: textos.bodySmall),
            ],
          ),
        ),
      ),
    );
  }
}

/// Barras horizontales de ocupación, una sola serie y un solo color: la
/// longitud dice la magnitud y el número va escrito al lado.
class _Barras extends StatelessWidget {
  const _Barras({required this.grupos});

  final List<UsoPorGrupo> grupos;

  @override
  Widget build(BuildContext context) {
    final ColorScheme esquema = Theme.of(context).colorScheme;
    final TextTheme textos = Theme.of(context).textTheme;

    final double maximo = grupos.fold<double>(
        0, (double m, UsoPorGrupo g) => (g.ocupacion ?? 0) > m ? g.ocupacion! : m);

    return Column(
      children: <Widget>[
        for (final UsoPorGrupo g in grupos)
          Semantics(
            label: '${g.etiqueta}: ${porcentaje(g.ocupacion)} de ocupación, '
                '${g.reservas} reservas',
            excludeSemantics: true,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Row(
                children: <Widget>[
                  SizedBox(
                    width: 84,
                    child: Text(g.etiqueta, style: textos.bodySmall),
                  ),
                  Expanded(
                    child: LayoutBuilder(
                      builder: (BuildContext c, BoxConstraints caja) {
                        final double fraccion = maximo <= 0
                            ? 0
                            : ((g.ocupacion ?? 0) / maximo).clamp(0.0, 1.0);
                        return Align(
                          alignment: Alignment.centerLeft,
                          child: Container(
                            width: caja.maxWidth * fraccion,
                            height: 14,
                            decoration: BoxDecoration(
                              color: esquema.primary,
                              borderRadius: const BorderRadius.horizontal(
                                right: Radius.circular(4),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  SizedBox(
                    width: 96,
                    child: Text(
                      '${porcentaje(g.ocupacion)} · ${g.reservas}',
                      textAlign: TextAlign.right,
                      style: textos.bodySmall,
                    ),
                  ),
                ],
              ),
            ),
          ),
        Align(
          alignment: Alignment.centerRight,
          child: Text(
            'ocupación promedio · reservas',
            style: textos.labelSmall?.copyWith(color: esquema.onSurfaceVariant),
          ),
        ),
      ],
    );
  }
}

class _TablaZonas extends StatelessWidget {
  const _TablaZonas({required this.grupos});

  final List<UsoPorGrupo> grupos;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        columnSpacing: 18,
        columns: const <DataColumn>[
          DataColumn(label: Text('Zona')),
          DataColumn(label: Text('Reservas'), numeric: true),
          DataColumn(label: Text('Asistidas'), numeric: true),
          DataColumn(label: Text('No asistidas'), numeric: true),
          DataColumn(label: Text('Canceladas'), numeric: true),
          DataColumn(label: Text('Asistencia'), numeric: true),
        ],
        rows: <DataRow>[
          for (final UsoPorGrupo g in grupos)
            DataRow(cells: <DataCell>[
              DataCell(Text(g.etiqueta)),
              DataCell(Text('${g.reservas}')),
              DataCell(Text('${g.asistidas}')),
              DataCell(Text('${g.noAsistidas}')),
              DataCell(Text('${g.canceladas}')),
              DataCell(Text(porcentaje(g.asistidas + g.noAsistidas == 0
                  ? null
                  : g.asistidas * 100 / (g.asistidas + g.noAsistidas)))),
            ]),
        ],
      ),
    );
  }
}
