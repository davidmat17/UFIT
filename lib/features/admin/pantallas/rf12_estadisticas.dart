import 'package:flutter/material.dart';

import '../../../core/widgets/en_construccion.dart';

/// RF12 - Visualizacion de estadisticas de ocupacion y uso
///
/// Modulo: admin | Responsable: Sergio
class PantallaEstadisticas extends StatelessWidget {
  const PantallaEstadisticas({super.key});

  @override
  Widget build(BuildContext context) {
    return const EnConstruccion(
      id: 'RF12',
      titulo: 'Visualizacion de estadisticas de ocupacion y uso',
      descripcion: 'El sistema debe permitir la consulta de estadisticas de ocupacion y uso por parte de los administradores.',
      responsable: 'Sergio',
      siguientePaso: 'Panel de ocupacion por franja y uso de maquinas, solo visible para el rol administrador.',
    );
  }
}
