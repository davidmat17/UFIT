/// Reglas de presentación de la normativa (RF6).
///
/// No tocan la base ni Flutter: se prueban con pruebas unitarias.
library;

/// Separa el texto de la normativa en reglas, una por línea.
///
/// El administrador puede escribirlas con o sin número ("1. ...",
/// "2) ...", "- ..."): la pantalla las numera de nuevo, así que aquí se
/// quita la numeración original. Las líneas vacías se ignoran.
List<String> reglasDeLaNormativa(String contenido) {
  final RegExp numeracion = RegExp(r'^(\d+\s*[.)\-]|[-•*])\s*');

  return contenido
      .split(RegExp(r'\r?\n'))
      .map((String linea) => linea.trim().replaceFirst(numeracion, '').trim())
      .where((String linea) => linea.isNotEmpty)
      .toList();
}

const List<String> _meses = <String>[
  'enero',
  'febrero',
  'marzo',
  'abril',
  'mayo',
  'junio',
  'julio',
  'agosto',
  'septiembre',
  'octubre',
  'noviembre',
  'diciembre',
];

/// La fecha en palabras, por ejemplo "13 de octubre de 2026".
String fechaLarga(DateTime fecha) =>
    '${fecha.day} de ${_meses[fecha.month - 1]} de ${fecha.year}';
