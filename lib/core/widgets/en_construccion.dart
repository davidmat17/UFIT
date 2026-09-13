import 'package:flutter/material.dart';

/// Pantalla provisional de un requerimiento todavia sin implementar.
///
/// Sirve para que la navegacion funcione completa desde el primer dia y
/// para que cada quien sepa que le toca. Se borra cuando la pantalla
/// real ocupe su lugar.
class EnConstruccion extends StatelessWidget {
  const EnConstruccion({
    super.key,
    required this.id,
    required this.titulo,
    required this.descripcion,
    required this.responsable,
    required this.siguientePaso,
  });

  final String id;
  final String titulo;
  final String descripcion;
  final String responsable;
  final String siguientePaso;

  @override
  Widget build(BuildContext context) {
    final ColorScheme esquema = Theme.of(context).colorScheme;
    final TextTheme textos = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(title: Text(id)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: <Widget>[
          Text(titulo, style: textos.headlineSmall),
          const SizedBox(height: 12),
          Text(
            descripcion,
            style: textos.bodyLarge?.copyWith(color: esquema.onSurfaceVariant),
          ),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: esquema.secondaryContainer,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Icon(Icons.construction_outlined,
                        size: 18, color: esquema.onSecondaryContainer),
                    const SizedBox(width: 8),
                    Text(
                      'Pendiente por implementar',
                      style: textos.labelLarge
                          ?.copyWith(color: esquema.onSecondaryContainer),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  siguientePaso,
                  style: textos.bodyMedium
                      ?.copyWith(color: esquema.onSecondaryContainer),
                ),
                const SizedBox(height: 10),
                Text(
                  'Responsable: $responsable',
                  style: textos.bodySmall
                      ?.copyWith(color: esquema.onSecondaryContainer),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
