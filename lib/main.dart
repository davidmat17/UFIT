import 'package:flutter/material.dart';

import 'core/catalogo_requerimientos.dart';
import 'core/modelos/requerimiento.dart';
import 'core/pantallas/pantalla_inicio.dart';
import 'core/rutas.dart';
import 'core/tema/app_theme.dart';

void main() {
  runApp(const UfitApp());
}

class UfitApp extends StatelessWidget {
  const UfitApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'UFIT',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.claro,
      darkTheme: AppTheme.oscuro,
      initialRoute: Rutas.inicio,
      routes: <String, WidgetBuilder>{
        Rutas.inicio: (_) => const PantallaInicio(),
        for (final Requerimiento r in catalogoRequerimientos)
          r.ruta: r.construir,
      },
    );
  }
}
