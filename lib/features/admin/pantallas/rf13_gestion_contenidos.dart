import 'package:flutter/material.dart';

import '../../../core/widgets/en_construccion.dart';

/// RF13 - Gestion administrativa de contenidos del gimnasio
///
/// Modulo: admin | Responsable: Sergio
class PantallaGestionContenidos extends StatelessWidget {
  const PantallaGestionContenidos({super.key});

  @override
  Widget build(BuildContext context) {
    return const EnConstruccion(
      id: 'RF13',
      titulo: 'Gestion administrativa de contenidos del gimnasio',
      descripcion: 'El sistema debe permitir la gestion administrativa del catalogo, la normativa y la asignacion de instructores.',
      responsable: 'Sergio',
      siguientePaso: 'Alta y edicion del catalogo de maquinas y ejercicios, publicacion de la normativa y asignacion de instructores.',
    );
  }
}
