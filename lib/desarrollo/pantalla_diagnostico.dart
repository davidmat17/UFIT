import 'package:flutter/material.dart';

import '../core/datos/errores.dart';
import '../core/datos/repositorios.dart';
import '../core/modelos/zona.dart';

/// Prueba de conexión de punta a punta.
///
/// Consulta las zonas a través del repositorio, no de Supabase. Esa es
/// la demostración de que la frontera funciona: esta pantalla no sabe
/// qué hay del otro lado, y en las pruebas se le entrega un repositorio
/// falso sin tocar una línea de este archivo.
class PantallaDiagnostico extends StatefulWidget {
  const PantallaDiagnostico({super.key});

  @override
  State<PantallaDiagnostico> createState() => _PantallaDiagnosticoState();
}

class _PantallaDiagnosticoState extends State<PantallaDiagnostico> {
  late Future<List<Zona>> _consulta;

  @override
  void initState() {
    super.initState();
    _consulta = Repositorios.gimnasio.zonas();
  }

  void _reintentar() {
    setState(() {
      _consulta = Repositorios.gimnasio.zonas();
    });
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme esquema = Theme.of(context).colorScheme;
    final TextTheme textos = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Conexión con Supabase'),
        actions: <Widget>[
          IconButton(
            onPressed: _reintentar,
            icon: const Icon(Icons.refresh),
            tooltip: 'Reintentar',
          ),
        ],
      ),
      body: FutureBuilder<List<Zona>>(
        future: _consulta,
        builder: (BuildContext context, AsyncSnapshot<List<Zona>> snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            final Object? error = snapshot.error;
            final String mensaje = error is ErrorDeDatos
                ? error.mensaje
                : 'Ocurrió un error inesperado.';

            return Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  Icon(Icons.cloud_off, size: 40, color: esquema.error),
                  const SizedBox(height: 16),
                  Text('No se pudo consultar la base',
                      style: textos.titleMedium),
                  const SizedBox(height: 8),
                  Text(
                    mensaje,
                    textAlign: TextAlign.center,
                    style: textos.bodySmall
                        ?.copyWith(color: esquema.onSurfaceVariant),
                  ),
                  const SizedBox(height: 20),
                  FilledButton(
                      onPressed: _reintentar, child: const Text('Reintentar')),
                ],
              ),
            );
          }

          final List<Zona> zonas = snapshot.data ?? const <Zona>[];

          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
            children: <Widget>[
              Row(
                children: <Widget>[
                  Icon(Icons.check_circle, color: esquema.primary, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Conexión establecida: ${zonas.length} zonas leídas',
                      style: textos.titleSmall,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              for (final Zona zona in zonas)
                Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    title: Text(zona.nombre),
                    subtitle: Text(zona.descripcion ?? ''),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}
