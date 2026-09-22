/// Puerto de administración (RF12, RF13).
abstract class RepositorioAdmin {
  /// Ocupación por franja en un rango, para el panel del RF12.
  /// La clave es la fecha y hora; el valor, los cupos ocupados.
  Future<Map<String, int>> ocupacionPorFranja({
    required DateTime desde,
    required DateTime hasta,
  });

  /// Cuántas reservas se hicieron y cuántas terminaron en ingreso real.
  Future<({int reservas, int asistencias})> asistenciaEfectiva({
    required DateTime desde,
    required DateTime hasta,
  });
}
