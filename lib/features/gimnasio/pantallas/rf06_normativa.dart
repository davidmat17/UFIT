import 'package:flutter/material.dart';

import '../../../core/widgets/en_construccion.dart';

/// RF6 - Consulta de normativa del gimnasio
///
/// Modulo: gimnasio | Responsable: Sergio
class PantallaNormativa extends StatelessWidget {
  const PantallaNormativa({super.key});

  @override
  Widget build(BuildContext context) {
    return const EnConstruccion(
      id: 'RF6',
      titulo: 'Consulta de normativa del gimnasio',
      descripcion: 'El sistema debe permitir la consulta de la normativa del gimnasio.',
      responsable: 'Sergio',
      siguientePaso: 'Lectura de la normativa publicada, accesible sin iniciar sesion desde la barra de ayuda.',
    );
  }
}
