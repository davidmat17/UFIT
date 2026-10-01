/// Una medición antropométrica de una persona en una fecha (RF8).
///
/// Corresponde a una fila de la tabla medidas_antropometricas. Cada vez
/// que la persona registra sus medidas se crea una medición nueva; las
/// anteriores quedan como historial para hacer seguimiento.
class MedicionAntropometrica {
  const MedicionAntropometrica({
    required this.id,
    required this.registradaEn,
    required this.pesoKg,
    required this.estaturaCm,
    this.cinturaCm,
    this.caderaCm,
    this.pechoCm,
    this.brazoCm,
    this.musloCm,
  });

  final int id;

  /// Cuándo se registró. La pone la base, no la app.
  final DateTime registradaEn;

  final double pesoKg;
  final double estaturaCm;

  // Circunferencias: son opcionales.
  final double? cinturaCm;
  final double? caderaCm;
  final double? pechoCm;
  final double? brazoCm;
  final double? musloCm;

  /// Índice de masa corporal: peso en kilos sobre estatura en metros al
  /// cuadrado.
  double get imc {
    final double metros = estaturaCm / 100;
    return pesoKg / (metros * metros);
  }
}
