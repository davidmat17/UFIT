import 'package:flutter/material.dart';

import '../../../core/widgets/en_construccion.dart';

/// RF7 - Visualizacion de disponibilidad de instructores
///
/// Modulo: gimnasio | Responsable: Sergio
class PantallaInstructores extends StatelessWidget {
  const PantallaInstructores({super.key});

  @override
  Widget build(BuildContext context) {
    return const EnConstruccion(
      id: 'RF7',
      titulo: 'Visualizacion de disponibilidad de instructores',
      descripcion: 'El sistema debe permitir la visualizacion de disponibilidad de instructores.',
      responsable: 'Sergio',
      siguientePaso: 'Agenda de instructores por dia y franja, alimentada por la asignacion del RF13.',
    );
  }
}
