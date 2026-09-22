import '../../../core/datos/puertos/repositorio_admin.dart';

/// Adaptador del puerto de administración contra Supabase (RF12, RF13).
///
/// Responsable: Sergio.
class RepositorioAdminSupabase implements RepositorioAdmin {
  const RepositorioAdminSupabase();

  @override
  Future<Map<String, int>> ocupacionPorFranja({
    required DateTime desde,
    required DateTime hasta,
  }) {
    throw UnimplementedError('Pendiente: RF12, responsable Sergio');
  }

  @override
  Future<({int reservas, int asistencias})> asistenciaEfectiva({
    required DateTime desde,
    required DateTime hasta,
  }) {
    throw UnimplementedError('Pendiente: RF12, responsable Sergio');
  }
}
