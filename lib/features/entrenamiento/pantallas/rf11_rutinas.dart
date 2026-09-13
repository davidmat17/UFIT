import 'package:flutter/material.dart';

import '../../../core/widgets/en_construccion.dart';

/// RF11 - Gestion de rutinas de ejercicio
///
/// Modulo: entrenamiento | Responsable: Sergio
class PantallaRutinas extends StatelessWidget {
  const PantallaRutinas({super.key});

  @override
  Widget build(BuildContext context) {
    return const EnConstruccion(
      id: 'RF11',
      titulo: 'Gestion de rutinas de ejercicio',
      descripcion: 'El sistema debe permitir la creacion y eliminacion de rutinas.',
      responsable: 'Sergio',
      siguientePaso: 'Maximo 3 rutinas por usuario, cada una con ejercicio, maquina, dias destinados y repeticiones.',
    );
  }
}
