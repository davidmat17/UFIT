import '../../../core/datos/puertos/repositorio_entrenamiento.dart';

/// Adaptador del puerto de entrenamiento contra Supabase (RF11).
///
/// Responsable: Sergio. El puerto ya está definido; los métodos se
/// implementan al trabajar el requerimiento.
class RepositorioEntrenamientoSupabase implements RepositorioEntrenamiento {
  const RepositorioEntrenamientoSupabase();

  @override
  Future<int> cantidadDeRutinas() {
    throw UnimplementedError('Pendiente: RF11, responsable Sergio');
  }

  @override
  Future<void> eliminarRutina(int rutinaId) {
    throw UnimplementedError('Pendiente: RF11, responsable Sergio');
  }
}
