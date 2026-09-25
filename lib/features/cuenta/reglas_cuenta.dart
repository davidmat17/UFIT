/// Reglas del módulo de cuenta que no dependen de pantallas ni de la
/// base de datos. Por eso se pueden probar solas.
library;

/// Dominios de correo aceptados. La base de datos aplica la misma regla
/// (restricción perfiles_correo_institucional en schema.sql): esta copia
/// solo sirve para avisar antes y con un mensaje claro.
const List<String> dominiosInstitucionales = <String>[
  'uis.edu.co',
  'correo.uis.edu.co',
];

bool esCorreoInstitucional(String correo) {
  final String c = correo.trim().toLowerCase();
  final int arroba = c.lastIndexOf('@');
  if (arroba < 1) return false;
  return dominiosInstitucionales.contains(c.substring(arroba + 1));
}

/// Parte el nombre que entrega Microsoft en nombre y apellido para
/// prellenar el registro. Es una suposición —la persona lo corrige en
/// el formulario—: con cuatro palabras o más toma dos de nombre, con
/// menos toma una.
({String nombre, String apellido}) dividirNombre(String? completo) {
  final List<String> partes = (completo ?? '')
      .trim()
      .split(RegExp(r'\s+'))
      .where((String p) => p.isNotEmpty)
      .map(_capitalizar)
      .toList();

  if (partes.isEmpty) return (nombre: '', apellido: '');
  if (partes.length == 1) return (nombre: partes.first, apellido: '');

  final int corte = partes.length >= 4 ? 2 : 1;
  return (
    nombre: partes.take(corte).join(' '),
    apellido: partes.skip(corte).join(' '),
  );
}

/// "PEREZ" y "perez" quedan "Perez".
String _capitalizar(String palabra) =>
    palabra[0].toUpperCase() + palabra.substring(1).toLowerCase();

/// Documento de identidad colombiano: solo dígitos, entre 6 y 10.
String? validarDocumento(String? valor) {
  final String v = (valor ?? '').trim();
  if (v.isEmpty) return 'Escribe tu número de documento.';
  if (!RegExp(r'^\d{6,10}$').hasMatch(v)) {
    return 'Solo números, entre 6 y 10 dígitos, sin puntos.';
  }
  return null;
}

/// Teléfono opcional; si se escribe, celular colombiano de 10 dígitos.
String? validarTelefono(String? valor) {
  final String v = (valor ?? '').trim();
  if (v.isEmpty) return null;
  if (!RegExp(r'^3\d{9}$').hasMatch(v)) {
    return 'Celular de 10 dígitos que empiece por 3, o déjalo vacío.';
  }
  return null;
}

String? validarObligatorio(String? valor, String campo) =>
    (valor ?? '').trim().isEmpty ? 'Escribe tu $campo.' : null;
