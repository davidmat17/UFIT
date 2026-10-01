/// Reglas del RF8 (medidas antropométricas) que no dependen de
/// pantallas ni de la base de datos. Por eso se pueden probar solas.
library;

/// Convierte lo que escribe la persona en un número. Acepta coma o
/// punto decimal ("70,5" y "70.5"). Devuelve null si está vacío o no es
/// un número.
double? leerNumero(String? texto) {
  final String t = (texto ?? '').trim().replaceAll(',', '.');
  if (t.isEmpty) return null;
  return double.tryParse(t);
}

/// Rangos que acepta la app. Son más estrechos que los de la base
/// (schema.sql) para atajar errores de digitación, como escribir la
/// estatura en metros.
const double pesoMinimo = 20;
const double pesoMaximo = 300;
const double estaturaMinima = 100;
const double estaturaMaxima = 250;
const double circunferenciaMinima = 10;
const double circunferenciaMaxima = 250;

String? _validarRango(
  String? valor, {
  required String campo,
  required String unidad,
  required double minimo,
  required double maximo,
  required bool obligatorio,
}) {
  final String v = (valor ?? '').trim();
  if (v.isEmpty) return obligatorio ? 'Escribe tu $campo.' : null;

  final double? n = leerNumero(v);
  if (n == null) return 'Escribe solo números, por ejemplo 70,5.';
  if (n < minimo || n > maximo) {
    return 'Debe estar entre ${formatearNumero(minimo)} y '
        '${formatearNumero(maximo)} $unidad.';
  }
  return null;
}

String? validarPeso(String? valor) => _validarRango(
      valor,
      campo: 'peso',
      unidad: 'kg',
      minimo: pesoMinimo,
      maximo: pesoMaximo,
      obligatorio: true,
    );

String? validarEstatura(String? valor) => _validarRango(
      valor,
      campo: 'estatura',
      unidad: 'cm',
      minimo: estaturaMinima,
      maximo: estaturaMaxima,
      obligatorio: true,
    );

/// Las circunferencias son opcionales: vacío es válido.
String? validarCircunferencia(String? valor) => _validarRango(
      valor,
      campo: 'medida',
      unidad: 'cm',
      minimo: circunferenciaMinima,
      maximo: circunferenciaMaxima,
      obligatorio: false,
    );

/// Clasificación del IMC para adultos según la OMS.
String clasificarImc(double imc) {
  if (imc < 18.5) return 'Bajo peso';
  if (imc < 25) return 'Peso normal';
  if (imc < 30) return 'Sobrepeso';
  return 'Obesidad';
}

/// Número con coma decimal y sin ceros sobrantes: 70 → "70",
/// 70.5 → "70,5", 22.857 → "22,9".
String formatearNumero(double n, {int decimales = 1}) {
  String texto = n.toStringAsFixed(decimales);
  if (texto.contains('.')) {
    texto = texto.replaceFirst(RegExp(r'\.?0+$'), '');
  }
  return texto.replaceAll('.', ',');
}

/// Diferencia con signo para el seguimiento: "+1,5", "-0,8" o "0".
String formatearDiferencia(double diferencia) {
  final String valor = formatearNumero(diferencia.abs());
  if (valor == '0') return '0';
  return diferencia > 0 ? '+$valor' : '-$valor';
}

const List<String> _meses = <String>[
  'enero', 'febrero', 'marzo', 'abril', 'mayo', 'junio', 'julio',
  'agosto', 'septiembre', 'octubre', 'noviembre', 'diciembre',
];

/// "1 de octubre de 2026".
String formatearFecha(DateTime fecha) =>
    '${fecha.day} de ${_meses[fecha.month - 1]} de ${fecha.year}';

/// "1 oct 2026", para listas y la gráfica.
String formatearFechaCorta(DateTime fecha) =>
    '${fecha.day} ${_meses[fecha.month - 1].substring(0, 3)} ${fecha.year}';
