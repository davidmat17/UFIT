import 'package:flutter/widgets.dart';

/// Los cinco modulos del proyecto. Cada uno tiene un unico dueno para
/// que nadie edite archivos de la carpeta del otro.
enum Modulo { cuenta, reservas, gimnasio, entrenamiento, admin }

extension ModuloInfo on Modulo {
  String get nombre => switch (this) {
        Modulo.cuenta => 'Cuenta y perfil',
        Modulo.reservas => 'Reservas y asistencia',
        Modulo.gimnasio => 'Informacion del gimnasio',
        Modulo.entrenamiento => 'Entrenamiento',
        Modulo.admin => 'Administracion',
      };

  String get carpeta => switch (this) {
        Modulo.cuenta => 'lib/features/cuenta',
        Modulo.reservas => 'lib/features/reservas',
        Modulo.gimnasio => 'lib/features/gimnasio',
        Modulo.entrenamiento => 'lib/features/entrenamiento',
        Modulo.admin => 'lib/features/admin',
      };

  String get responsable => switch (this) {
        Modulo.cuenta => 'David',
        Modulo.reservas => 'David',
        Modulo.gimnasio => 'Sergio',
        Modulo.entrenamiento => 'Sergio',
        Modulo.admin => 'Sergio',
      };
}

/// Un requerimiento funcional del documento de la Entrega 1B,
/// con la pantalla que lo implementa.
class Requerimiento {
  const Requerimiento({
    required this.id,
    required this.titulo,
    required this.modulo,
    required this.ruta,
    required this.construir,
  });

  final String id;
  final String titulo;
  final Modulo modulo;
  final String ruta;
  final WidgetBuilder construir;
}
