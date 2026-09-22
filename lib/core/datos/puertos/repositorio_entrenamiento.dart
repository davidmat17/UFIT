/// Puerto de entrenamiento (RF11).
///
/// Los modelos de rutina se agregan cuando se implemente el RF11; por
/// ahora el puerto declara solo lo que ya se sabe que hace falta.
abstract class RepositorioEntrenamiento {
  /// Cuántas rutinas tiene el usuario. El máximo es 3 y lo hace cumplir
  /// la base de datos.
  Future<int> cantidadDeRutinas();

  Future<void> eliminarRutina(int rutinaId);
}
