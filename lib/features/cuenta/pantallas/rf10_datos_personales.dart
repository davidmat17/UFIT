import 'package:flutter/material.dart';

import '../../../core/widgets/en_construccion.dart';

/// RF10 - Consulta y actualizacion de datos personales
///
/// Modulo: cuenta | Responsable: David
class PantallaDatosPersonales extends StatelessWidget {
  const PantallaDatosPersonales({super.key});

  @override
  Widget build(BuildContext context) {
    return const EnConstruccion(
      id: 'RF10',
      titulo: 'Consulta y actualizacion de datos personales',
      descripcion: 'El sistema debe permitir la consulta y actualizacion de datos personales.',
      responsable: 'David',
      siguientePaso: 'Ficha del perfil en modo lectura y en modo edicion, con aislamiento entre cuentas.',
    );
  }
}
