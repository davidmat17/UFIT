import 'package:flutter/material.dart';

import '../../../core/datos/errores.dart';
import '../../../core/datos/repositorios.dart';
import '../../../core/modelos/administracion.dart';
import '../reglas_admin.dart';
import 'piezas_admin.dart';

/// RF13 - Pestaña "Bitácora": quién cambió qué y cuándo (CU13, paso 6).
/// Incluye los intentos de entrar sin permiso a las estadísticas (CU12,
/// 1a). Es solo lectura: nadie puede editar ni borrar la bitácora.
class PestanaBitacora extends StatefulWidget {
  const PestanaBitacora({super.key});

  @override
  State<PestanaBitacora> createState() => _PestanaBitacoraState();
}

class _PestanaBitacoraState extends State<PestanaBitacora> {
  bool _cargando = true;
  String? _error;
  List<EntradaBitacora> _entradas = <EntradaBitacora>[];

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
      final List<EntradaBitacora> entradas = await Repositorios.admin.bitacora();
      if (!mounted) return;
      setState(() {
        _entradas = entradas;
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

  @override
  Widget build(BuildContext context) {
    if (_cargando) return const CargandoAdmin();
    if (_error != null) {
      return ErrorConReintento(mensaje: _error!, alReintentar: _cargar);
    }

    final TextTheme textos = Theme.of(context).textTheme;

    return RefreshIndicator(
      onRefresh: _cargar,
      child: ListView(
        // Se puede jalar hacia abajo para actualizar aunque la lista sea
        // corta.
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Text('Últimos 100 cambios', style: textos.titleMedium),
              ),
              IconButton(
                tooltip: 'Actualizar la bitácora',
                icon: const Icon(Icons.refresh),
                onPressed: _cargar,
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (_entradas.isEmpty)
            const AvisoAdmin(
              texto: 'Todavía no hay cambios registrados. Cada vez que '
                  'publiques la normativa, edites el catálogo, asignes un '
                  'turno o cambies un rol, quedará aquí.',
              esError: false,
            ),
          for (final EntradaBitacora e in _entradas)
            Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: ExpansionTile(
                leading: Icon(
                  e.accion == 'acceso_denegado'
                      ? Icons.gpp_bad_outlined
                      : Icons.history_edu,
                ),
                title: Text(accionLegible(e)),
                subtitle: Text(
                  '${e.persona ?? 'Panel de Supabase'} · '
                  '${fechaCorta(e.fecha)} ${e.fecha.year}, '
                  '${horaDelReloj(e.fecha)}',
                ),
                childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                expandedCrossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  SelectableText(
                    e.detalle ?? 'Sin detalle.',
                    style: textos.bodySmall?.copyWith(fontFamily: 'monospace'),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
