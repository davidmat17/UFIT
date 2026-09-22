/// Errores de acceso a datos, en el vocabulario del proyecto.
///
/// Las pantallas nunca ven una excepción de Supabase: los adaptadores
/// traducen lo que llega de la red a uno de estos casos. Así, cambiar de
/// backend no obliga a tocar el manejo de errores de ninguna pantalla.
enum TipoDeError {
  sinConexion,
  credencialesInvalidas,
  sinPermiso,
  noEncontrado,
  reglaDeNegocio,
  desconocido,
}

class ErrorDeDatos implements Exception {
  const ErrorDeDatos(this.tipo, this.mensaje, {this.causa});

  final TipoDeError tipo;

  /// Texto listo para mostrarle a la persona, sin jerga técnica.
  final String mensaje;

  /// El error original, solo para registrarlo. No se muestra.
  final Object? causa;

  @override
  String toString() => mensaje;
}
