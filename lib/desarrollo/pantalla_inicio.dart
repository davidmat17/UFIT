import 'package:flutter/material.dart';

import 'catalogo_requerimientos.dart';
import 'modelo_requerimiento.dart';
import '../core/rutas.dart';

/// Menu provisional de desarrollo.
///
/// Lista los 13 requerimientos agrupados por modulo para poder entrar a
/// cualquier pantalla mientras se construye. No es una pantalla de la
/// app final. Desde el RF1 se llega aquí solo después de iniciar sesión,
/// y se reemplaza cuando exista la pantalla principal real.
class PantallaInicio extends StatelessWidget {
  const PantallaInicio({super.key});

  @override
  Widget build(BuildContext context) {
    final TextTheme textos = Theme.of(context).textTheme;
    final ColorScheme esquema = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('UFIT'),
        actions: <Widget>[
          IconButton(
            tooltip: 'Mi cuenta',
            icon: const Icon(Icons.account_circle_outlined),
            onPressed: () =>
                Navigator.pushNamed(context, Rutas.rf01Autenticacion),
          ),
          IconButton(
            tooltip: 'Probar la conexión con Supabase',
            icon: const Icon(Icons.cloud_outlined),
            onPressed: () => Navigator.pushNamed(context, Rutas.diagnostico),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: esquema.outlineVariant),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
        children: <Widget>[
          Text(
            'Esqueleto del proyecto',
            style: textos.titleMedium,
          ),
          const SizedBox(height: 4),
          Text(
            'Menu de desarrollo con los 13 requerimientos funcionales. '
            'Se llega aquí después de iniciar sesión (RF1). Lo reemplaza '
            'la pantalla principal cuando exista.',
            style: textos.bodySmall?.copyWith(color: esquema.onSurfaceVariant),
          ),
          const SizedBox(height: 8),
          for (final Modulo modulo in Modulo.values)
            ..._seccionModulo(context, modulo),
        ],
      ),
    );
  }

  List<Widget> _seccionModulo(BuildContext context, Modulo modulo) {
    final TextTheme textos = Theme.of(context).textTheme;
    final ColorScheme esquema = Theme.of(context).colorScheme;

    return <Widget>[
      Padding(
        padding: const EdgeInsets.only(top: 24, bottom: 10),
        child: Row(
          children: <Widget>[
            Expanded(
              child: Text(modulo.nombre, style: textos.titleSmall),
            ),
            Text(
              modulo.responsable,
              style: textos.labelSmall?.copyWith(color: esquema.primary),
            ),
          ],
        ),
      ),
      for (final Requerimiento r in requerimientosDe(modulo))
        _TarjetaRequerimiento(requerimiento: r),
    ];
  }
}

class _TarjetaRequerimiento extends StatelessWidget {
  const _TarjetaRequerimiento({required this.requerimiento});

  final Requerimiento requerimiento;

  @override
  Widget build(BuildContext context) {
    final ColorScheme esquema = Theme.of(context).colorScheme;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      clipBehavior: Clip.antiAlias,
      child: ListTile(
        contentPadding: const EdgeInsets.fromLTRB(12, 6, 8, 6),
        leading: Container(
          width: 46,
          padding: const EdgeInsets.symmetric(vertical: 8),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: esquema.secondaryContainer,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            requerimiento.id,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: esquema.onSecondaryContainer,
            ),
          ),
        ),
        title: Text(requerimiento.titulo),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => Navigator.pushNamed(context, requerimiento.ruta),
      ),
    );
  }
}
