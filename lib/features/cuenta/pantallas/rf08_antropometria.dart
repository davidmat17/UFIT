import 'package:flutter/material.dart';

import '../../../core/widgets/en_construccion.dart';

/// RF8 - Registro y gestion de datos antropometricos
///
/// Modulo: cuenta | Responsable: David
class PantallaAntropometria extends StatelessWidget {
  const PantallaAntropometria({super.key});

  @override
  Widget build(BuildContext context) {
    return const EnConstruccion(
      id: 'RF8',
      titulo: 'Registro y gestion de datos antropometricos',
      descripcion: 'El sistema debe permitir el registro y la gestion de datos antropometricos.',
      responsable: 'David',
      siguientePaso: 'Formulario de peso, estatura y circunferencias, con historial de mediciones del usuario.',
    );
  }
}
