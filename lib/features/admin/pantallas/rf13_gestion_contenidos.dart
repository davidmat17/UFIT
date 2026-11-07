import 'package:flutter/material.dart';

import 'piezas_admin.dart';
import 'rf13_bitacora.dart';
import 'rf13_ejercicios.dart';
import 'rf13_maquinas.dart';
import 'rf13_normativa.dart';
import 'rf13_personas.dart';
import 'rf13_turnos.dart';

/// RF13 - Gestión administrativa de contenidos del gimnasio
///
/// Módulo: admin
///
/// El panel de contenidos del CU13, solo para el administrador: catálogo
/// de máquinas y ejercicios (RF5), normativa y plazo para cancelar (RF6,
/// RF3), turnos de instructores (RF7), roles de las personas y la
/// bitácora de auditoría. Lo que se guarda aquí lo ven los usuarios de
/// inmediato en las pantallas de consulta.
///
/// La barrera real está en la base de datos (migración 016): aunque
/// alguien manipule la petición, sin el rol de administrador las
/// políticas y las funciones la rechazan.
class PantallaGestionContenidos extends StatelessWidget {
  const PantallaGestionContenidos({super.key});

  @override
  Widget build(BuildContext context) {
    return SoloAdministrador(
      titulo: 'Contenidos del gimnasio',
      construir: (_) => DefaultTabController(
        length: 6,
        child: Scaffold(
          appBar: AppBar(
            title: const Text('Contenidos del gimnasio'),
            bottom: const TabBar(
              isScrollable: true,
              tabAlignment: TabAlignment.start,
              tabs: <Widget>[
                Tab(icon: Icon(Icons.fitness_center), text: 'Máquinas'),
                Tab(icon: Icon(Icons.sports_gymnastics), text: 'Ejercicios'),
                Tab(icon: Icon(Icons.gavel_outlined), text: 'Normativa'),
                Tab(icon: Icon(Icons.badge_outlined), text: 'Turnos'),
                Tab(icon: Icon(Icons.group_outlined), text: 'Personas'),
                Tab(icon: Icon(Icons.history_edu), text: 'Bitácora'),
              ],
            ),
          ),
          body: const TabBarView(
            children: <Widget>[
              PestanaMaquinas(),
              PestanaEjercicios(),
              PestanaNormativa(),
              PestanaTurnos(),
              PestanaPersonas(),
              PestanaBitacora(),
            ],
          ),
        ),
      ),
    );
  }
}
