import 'package:flutter/material.dart';

import '../supabase/supabase_config.dart';

/// Prueba de conexión con Supabase.
///
/// Consulta las zonas del gimnasio, que son datos semilla que ya existen
/// en la base. Si las muestra, la conexión funciona de punta a punta:
/// credenciales, red, permisos de lectura y consulta.
///
/// Es una pantalla de desarrollo, no de la app: se borra cuando el
/// proyecto esté andando.
class PantallaDiagnostico extends StatefulWidget {
  const PantallaDiagnostico({super.key});

  @override
  State<PantallaDiagnostico> createState() => _PantallaDiagnosticoState();
}

class _PantallaDiagnosticoState extends State<PantallaDiagnostico> {
  late Future<List<Map<String, dynamic>>> _consulta;

  @override
  void initState() {
    super.initState();
    _consulta = _traerZonas();
  }

  Future<List<Map<String, dynamic>>> _traerZonas() async {
    final List<Map<String, dynamic>> filas = await SupabaseConfig.cliente
        .from('zonas')
        .select('id, nombre, descripcion')
        .order('id');
    return filas;
  }

  void _reintentar() {
    setState(() {
      _consulta = _traerZonas();
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
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _consulta,
        builder: (BuildContext context,
            AsyncSnapshot<List<Map<String, dynamic>>> snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
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
                    '${snapshot.error}',
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

          final List<Map<String, dynamic>> zonas = snapshot.data ?? const [];

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
              for (final Map<String, dynamic> zona in zonas)
                Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    title: Text('${zona['nombre']}'),
                    subtitle: Text('${zona['descripcion'] ?? ''}'),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}
