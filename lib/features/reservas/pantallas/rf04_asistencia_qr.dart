import 'package:flutter/material.dart';

import '../../../core/widgets/en_construccion.dart';

/// RF4 - Registro de asistencia mediante codigo QR
///
/// Modulo: reservas | Responsable: David
class PantallaAsistenciaQr extends StatelessWidget {
  const PantallaAsistenciaQr({super.key});

  @override
  Widget build(BuildContext context) {
    return const EnConstruccion(
      id: 'RF4',
      titulo: 'Registro de asistencia mediante codigo QR',
      descripcion: 'El sistema debe permitir el registro de asistencia mediante codigo QR.',
      responsable: 'David',
      siguientePaso: 'Generacion del QR del usuario y lectura en la entrada, validando que exista reserva vigente.',
    );
  }
}
