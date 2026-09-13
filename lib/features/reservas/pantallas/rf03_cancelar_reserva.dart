import 'package:flutter/material.dart';

import '../../../core/widgets/en_construccion.dart';

/// RF3 - Cancelacion de reservas
///
/// Modulo: reservas | Responsable: David
class PantallaCancelarReserva extends StatelessWidget {
  const PantallaCancelarReserva({super.key});

  @override
  Widget build(BuildContext context) {
    return const EnConstruccion(
      id: 'RF3',
      titulo: 'Cancelacion de reservas',
      descripcion: 'El sistema debe permitir la cancelacion de reservas.',
      responsable: 'David',
      siguientePaso: 'Listado de reservas activas del usuario y cancelacion con devolucion del cupo.',
    );
  }
}
