import 'package:flutter/material.dart';

import '../../../core/widgets/en_construccion.dart';

/// RF9 - Consulta de historial de asistencia y reservas
///
/// Modulo: reservas | Responsable: David
class PantallaHistorial extends StatelessWidget {
  const PantallaHistorial({super.key});

  @override
  Widget build(BuildContext context) {
    return const EnConstruccion(
      id: 'RF9',
      titulo: 'Consulta de historial de asistencia y reservas',
      descripcion: 'El sistema debe permitir la consulta del historial de asistencia y reservas por mes.',
      responsable: 'David',
      siguientePaso: 'Vista por mes con las asistencias y reservas del usuario, incluso cuando no hay registros.',
    );
  }
}
