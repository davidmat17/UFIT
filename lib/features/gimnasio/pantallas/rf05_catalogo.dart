import 'package:flutter/material.dart';

import '../../../core/widgets/en_construccion.dart';

/// RF5 - Consulta de catalogo de maquinas y ejercicios
///
/// Modulo: gimnasio | Responsable: Sergio
class PantallaCatalogo extends StatelessWidget {
  const PantallaCatalogo({super.key});

  @override
  Widget build(BuildContext context) {
    return const EnConstruccion(
      id: 'RF5',
      titulo: 'Consulta de catalogo de maquinas y ejercicios',
      descripcion: 'El sistema debe permitir la consulta del catalogo de maquinas y ejercicios asociados.',
      responsable: 'Sergio',
      siguientePaso: 'Listado de maquinas con busqueda y detalle de los ejercicios asociados a cada una.',
    );
  }
}
