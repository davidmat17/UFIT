import 'package:flutter/material.dart';

import 'core/catalogo_requerimientos.dart';
import 'core/modelos/requerimiento.dart';
import 'core/pantallas/pantalla_diagnostico.dart';
import 'core/pantallas/pantalla_inicio.dart';
import 'core/rutas.dart';
import 'core/supabase/supabase_config.dart';
import 'core/tema/app_theme.dart';

Future<void> main() async {
  // Obligatorio antes de cualquier await en main: prepara el puente
  // entre Dart y Android para que se puedan leer archivos.
  WidgetsFlutterBinding.ensureInitialized();

  // La app arranca aunque Supabase falle. Si esperáramos aquí sin
  // atrapar el error, una credencial mal escrita dejaría la pantalla
  // congelada en el logo, sin ninguna pista de qué pasó.
  String? errorDeArranque;
  try {
    await SupabaseConfig.inicializar();
  } catch (e) {
    errorDeArranque = e.toString();
  }

  runApp(UfitApp(errorDeArranque: errorDeArranque));
}

class UfitApp extends StatelessWidget {
  const UfitApp({super.key, this.errorDeArranque});

  /// Mensaje del fallo al conectar con Supabase, si lo hubo.
  final String? errorDeArranque;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'UFIT',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.claro,
      darkTheme: AppTheme.oscuro,
      home: errorDeArranque == null
          ? const PantallaInicio()
          : PantallaErrorArranque(mensaje: errorDeArranque!),
      routes: <String, WidgetBuilder>{
        Rutas.diagnostico: (_) => const PantallaDiagnostico(),
        for (final Requerimiento r in catalogoRequerimientos)
          r.ruta: r.construir,
      },
    );
  }
}

/// Se muestra cuando la app no pudo conectarse a Supabase al arrancar.
class PantallaErrorArranque extends StatelessWidget {
  const PantallaErrorArranque({super.key, required this.mensaje});

  final String mensaje;

  @override
  Widget build(BuildContext context) {
    final ColorScheme esquema = Theme.of(context).colorScheme;
    final TextTheme textos = Theme.of(context).textTheme;

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: <Widget>[
            const SizedBox(height: 40),
            Icon(Icons.error_outline, size: 44, color: esquema.error),
            const SizedBox(height: 16),
            Text('No se pudo conectar con Supabase',
                style: textos.headlineSmall, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            Text(
              'La app arrancó, pero la base de datos no respondió. '
              'Revisa el archivo .env y que el proyecto de Supabase no '
              'esté pausado.',
              textAlign: TextAlign.center,
              style: textos.bodyMedium
                  ?.copyWith(color: esquema.onSurfaceVariant),
            ),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: esquema.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(10),
              ),
              child: SelectableText(
                mensaje,
                style: textos.bodySmall?.copyWith(fontFamily: 'monospace'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
