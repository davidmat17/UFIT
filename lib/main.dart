import 'package:flutter/material.dart';

import 'core/datos/repositorios.dart';
import 'core/rutas.dart';
import 'core/supabase/supabase_config.dart';
import 'core/tema/app_theme.dart';
import 'desarrollo/catalogo_requerimientos.dart';
import 'desarrollo/modelo_requerimiento.dart';
import 'desarrollo/pantalla_diagnostico.dart';
import 'desarrollo/pantalla_inicio.dart';
import 'features/admin/datos/repositorio_admin_supabase.dart';
import 'features/cuenta/datos/repositorio_perfiles_supabase.dart';
import 'features/entrenamiento/datos/repositorio_entrenamiento_supabase.dart';
import 'features/gimnasio/datos/repositorio_gimnasio_supabase.dart';
import 'features/reservas/datos/repositorio_reservas_supabase.dart';

/// Punto de composición de la aplicación.
///
/// Es el único archivo autorizado a conocer al tiempo el núcleo, los
/// cinco módulos y Supabase: aquí se decide qué implementación concreta
/// llena cada puerto. Si mañana se cambia de backend, se cambia este
/// archivo y los adaptadores, y ninguna pantalla se entera.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  String? errorDeArranque;
  try {
    await SupabaseConfig.inicializar();
  } catch (e) {
    errorDeArranque = e.toString();
  }

  Repositorios.registrar(
    perfiles: const RepositorioPerfilesSupabase(),
    gimnasio: const RepositorioGimnasioSupabase(),
    reservas: const RepositorioReservasSupabase(),
    entrenamiento: const RepositorioEntrenamientoSupabase(),
    admin: const RepositorioAdminSupabase(),
  );

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
