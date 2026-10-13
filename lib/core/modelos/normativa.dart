/// La normativa del gimnasio publicada por el administrador (RF6, RF13).
///
/// El contenido es texto con una regla por línea. La base guarda todas
/// las versiones, pero solo una está vigente a la vez.
class Normativa {
  const Normativa({
    required this.titulo,
    required this.contenido,
    required this.version,
    required this.publicadaEn,
    this.desdeCopiaLocal = false,
  });

  final String titulo;
  final String contenido;
  final int version;

  /// Fecha de la última actualización, en hora local.
  final DateTime publicadaEn;

  /// true cuando no hubo conexión y se muestra la última versión que se
  /// descargó en el teléfono (CU06, flujo 2a).
  final bool desdeCopiaLocal;

  Normativa comoCopiaLocal() => Normativa(
        titulo: titulo,
        contenido: contenido,
        version: version,
        publicadaEn: publicadaEn,
        desdeCopiaLocal: true,
      );
}
