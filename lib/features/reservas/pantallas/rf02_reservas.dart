import 'package:flutter/material.dart';

import '../../../core/widgets/en_construccion.dart';

/// RF2 - Gestion de reservas de cupos en franjas horarias
///
/// Modulo: reservas | Responsable: David
class PantallaReservas extends StatelessWidget {
  const PantallaReservas({super.key});

  @override
  Widget build(BuildContext context) {
    return const EnConstruccion(
      id: 'RF2',
      titulo: 'Gestion de reservas de cupos en franjas horarias',
      descripcion: 'El sistema debe permitir la gestion de reservas en franjas horarias disponibles.',
      responsable: 'David',
      siguientePaso: 'Consulta de disponibilidad por franja, creacion de la reserva y reservas recurrentes.',
    );
  }
}
