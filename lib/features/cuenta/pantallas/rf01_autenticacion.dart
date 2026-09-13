import 'package:flutter/material.dart';

import '../../../core/widgets/en_construccion.dart';

/// RF1 - Registro e inicio de sesion de usuarios
///
/// Modulo: cuenta | Responsable: David
class PantallaAutenticacion extends StatelessWidget {
  const PantallaAutenticacion({super.key});

  @override
  Widget build(BuildContext context) {
    return const EnConstruccion(
      id: 'RF1',
      titulo: 'Registro e inicio de sesion de usuarios',
      descripcion: 'El sistema debe permitir el registro e inicio de sesion de los usuarios.',
      responsable: 'David',
      siguientePaso: 'Formulario de registro con validacion de correo y contrasena, inicio de sesion y cierre de sesion contra Supabase Auth.',
    );
  }
}
