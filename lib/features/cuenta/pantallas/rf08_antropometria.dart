import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/datos/errores.dart';
import '../../../core/datos/repositorios.dart';
import '../../../core/modelos/medicion.dart';
import '../reglas_antropometria.dart';

/// RF8 - Registro y gestión de datos antropométricos
///
/// Módulo: cuenta | Responsable: David
///
/// Cada medición se guarda con su fecha; las anteriores quedan como
/// historial. La pantalla muestra la última medición con su IMC, la
/// evolución del peso y el historial completo. Una medición no se
/// edita: se registra una nueva o se borra la equivocada.
///
/// Este archivo tiene dos pantallas:
/// - [PantallaAntropometria]: resumen, gráfica e historial. Es la
///   entrada del RF8 en el menú.
/// - La pantalla para registrar una medición nueva, que solo se abre
///   desde la anterior.
class PantallaAntropometria extends StatefulWidget {
  const PantallaAntropometria({super.key});

  @override
  State<PantallaAntropometria> createState() => _PantallaAntropometriaState();
}

class _PantallaAntropometriaState extends State<PantallaAntropometria> {
  bool _cargando = true;
  String? _errorDeCarga;

  /// De la más reciente a la más antigua.
  List<MedicionAntropometrica> _mediciones = <MedicionAntropometrica>[];

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    setState(() {
      _cargando = true;
      _errorDeCarga = null;
    });
    try {
      final List<MedicionAntropometrica> lista =
          await Repositorios.perfiles.misMediciones();
      if (!mounted) return;
      setState(() => _mediciones = lista);
    } on ErrorDeDatos catch (e) {
      if (!mounted) return;
      setState(() => _errorDeCarga = e.mensaje);
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  Future<void> _registrar() async {
    final MedicionAntropometrica? nueva =
        await Navigator.of(context).push<MedicionAntropometrica>(
      MaterialPageRoute<MedicionAntropometrica>(
        builder: (_) => _PantallaNuevaMedicion(
          anterior: _mediciones.isEmpty ? null : _mediciones.first,
        ),
      ),
    );
    if (nueva == null || !mounted) return;

    setState(() => _mediciones = <MedicionAntropometrica>[nueva, ..._mediciones]);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Medición registrada.')),
    );
  }

  Future<void> _borrar(MedicionAntropometrica m) async {
    final bool? confirmar = await showDialog<bool>(
      context: context,
      builder: (BuildContext contexto) => AlertDialog(
        title: const Text('¿Borrar esta medición?'),
        content: Text(
          'Se borrará la medición del ${formatearFecha(m.registradaEn)}. '
          'Esto no se puede deshacer.',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(contexto, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(contexto, true),
            child: const Text('Borrar'),
          ),
        ],
      ),
    );
    if (confirmar != true || !mounted) return;

    try {
      await Repositorios.perfiles.borrarMedicion(m.id);
      if (!mounted) return;
      setState(() => _mediciones = _mediciones
          .where((MedicionAntropometrica x) => x.id != m.id)
          .toList());
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Medición borrada.')),
      );
    } on ErrorDeDatos catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(e.mensaje)));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Mis medidas')),
      floatingActionButton: _cargando || _errorDeCarga != null
          ? null
          : FloatingActionButton.extended(
              onPressed: _registrar,
              icon: const Icon(Icons.add),
              label: const Text('Registrar medición'),
            ),
      body: _cuerpo(context),
    );
  }

  Widget _cuerpo(BuildContext context) {
    final TextTheme textos = Theme.of(context).textTheme;
    final ColorScheme esquema = Theme.of(context).colorScheme;

    if (_cargando) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_errorDeCarga != null) {
      return ListView(
        padding: const EdgeInsets.all(24),
        children: <Widget>[
          _Aviso(texto: _errorDeCarga!),
          const SizedBox(height: 16),
          FilledButton(onPressed: _cargar, child: const Text('Reintentar')),
        ],
      );
    }

    if (_mediciones.isEmpty) {
      return ListView(
        padding: const EdgeInsets.fromLTRB(28, 48, 28, 100),
        children: <Widget>[
          Icon(Icons.straighten, size: 52, color: esquema.primary),
          const SizedBox(height: 16),
          Text('Aún no has registrado tus medidas',
              textAlign: TextAlign.center, style: textos.titleMedium),
          const SizedBox(height: 8),
          Text(
            'Registra tu peso, estatura y circunferencias. Cada vez que '
            'vuelvas a medirte verás cómo cambian.',
            textAlign: TextAlign.center,
            style: textos.bodyMedium?.copyWith(color: esquema.onSurfaceVariant),
          ),
        ],
      );
    }

    final MedicionAntropometrica ultima = _mediciones.first;
    final MedicionAntropometrica? anterior =
        _mediciones.length > 1 ? _mediciones[1] : null;

    return RefreshIndicator(
      onRefresh: _cargar,
      child: ListView(
        // El espacio de abajo evita que el botón flotante tape la
        // última fila del historial.
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
        children: <Widget>[
          _ResumenUltima(ultima: ultima, anterior: anterior),
          if (_mediciones.length >= 2) ...<Widget>[
            const SizedBox(height: 20),
            Text('Evolución del peso', style: textos.titleSmall),
            const SizedBox(height: 8),
            _GraficaPeso(mediciones: _mediciones.reversed.toList()),
          ],
          const SizedBox(height: 20),
          Text('Historial (${_mediciones.length})', style: textos.titleSmall),
          const SizedBox(height: 8),
          for (int i = 0; i < _mediciones.length; i++)
            _FilaHistorial(
              medicion: _mediciones[i],
              anterior: i + 1 < _mediciones.length ? _mediciones[i + 1] : null,
              alBorrar: () => _borrar(_mediciones[i]),
            ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------
// Resumen de la última medición
// ---------------------------------------------------------------------

class _ResumenUltima extends StatelessWidget {
  const _ResumenUltima({required this.ultima, this.anterior});

  final MedicionAntropometrica ultima;
  final MedicionAntropometrica? anterior;

  @override
  Widget build(BuildContext context) {
    final TextTheme textos = Theme.of(context).textTheme;
    final ColorScheme esquema = Theme.of(context).colorScheme;
    final MedicionAntropometrica? previa = anterior;

    final List<(String, double?)> circunferencias = <(String, double?)>[
      ('Cintura', ultima.cinturaCm),
      ('Cadera', ultima.caderaCm),
      ('Pecho', ultima.pechoCm),
      ('Brazo', ultima.brazoCm),
      ('Muslo', ultima.musloCm),
    ].where(((String, double?) c) => c.$2 != null).toList();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text('Última medición · ${formatearFecha(ultima.registradaEn)}',
                style: textos.labelMedium
                    ?.copyWith(color: esquema.onSurfaceVariant)),
            const SizedBox(height: 12),
            Row(
              children: <Widget>[
                Expanded(
                  child: _Dato(
                    titulo: 'Peso',
                    valor: '${formatearNumero(ultima.pesoKg)} kg',
                    nota: previa == null
                        ? null
                        : '${formatearDiferencia(ultima.pesoKg - previa.pesoKg)} kg',
                  ),
                ),
                Expanded(
                  child: _Dato(
                    titulo: 'Estatura',
                    valor: '${formatearNumero(ultima.estaturaCm)} cm',
                  ),
                ),
                Expanded(
                  child: _Dato(
                    titulo: 'IMC',
                    valor: formatearNumero(ultima.imc),
                    nota: clasificarImc(ultima.imc),
                  ),
                ),
              ],
            ),
            if (circunferencias.isNotEmpty) ...<Widget>[
              const SizedBox(height: 16),
              Text('Circunferencias (cm)', style: textos.labelMedium),
              const SizedBox(height: 6),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: <Widget>[
                  for (final (String nombre, double? valor) in circunferencias)
                    Chip(
                      label: Text('$nombre ${formatearNumero(valor!)}'),
                      visualDensity: VisualDensity.compact,
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _Dato extends StatelessWidget {
  const _Dato({required this.titulo, required this.valor, this.nota});

  final String titulo;
  final String valor;
  final String? nota;

  @override
  Widget build(BuildContext context) {
    final TextTheme textos = Theme.of(context).textTheme;
    final ColorScheme esquema = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(titulo,
            style: textos.bodySmall?.copyWith(color: esquema.onSurfaceVariant)),
        const SizedBox(height: 2),
        Text(valor,
            style: textos.titleLarge?.copyWith(fontWeight: FontWeight.w600)),
        if (nota != null)
          Text(nota!,
              style: textos.bodySmall?.copyWith(color: esquema.primary)),
      ],
    );
  }
}

// ---------------------------------------------------------------------
// Gráfica de peso
// ---------------------------------------------------------------------

/// Línea simple del peso en el tiempo. Se dibuja a mano con
/// CustomPaint para no agregar una librería de gráficas por una sola
/// línea.
class _GraficaPeso extends StatelessWidget {
  const _GraficaPeso({required this.mediciones});

  /// De la más antigua a la más reciente.
  final List<MedicionAntropometrica> mediciones;

  @override
  Widget build(BuildContext context) {
    final ColorScheme esquema = Theme.of(context).colorScheme;
    final TextTheme textos = Theme.of(context).textTheme;
    final TextStyle? estiloEje =
        textos.labelSmall?.copyWith(color: esquema.onSurfaceVariant);

    final List<double> pesos =
        mediciones.map((MedicionAntropometrica m) => m.pesoKg).toList();
    final double minimo = pesos.reduce(math.min);
    final double maximo = pesos.reduce(math.max);

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 14, 16, 10),
        child: Column(
          children: <Widget>[
            SizedBox(
              height: 140,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  Column(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: <Widget>[
                      Text('${formatearNumero(maximo)} kg', style: estiloEje),
                      Text('${formatearNumero(minimo)} kg', style: estiloEje),
                    ],
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: CustomPaint(
                      painter: _PintorLinea(
                        valores: pesos,
                        color: esquema.primary,
                        colorGuia: esquema.outlineVariant,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: <Widget>[
                Text(formatearFechaCorta(mediciones.first.registradaEn),
                    style: estiloEje),
                Text(formatearFechaCorta(mediciones.last.registradaEn),
                    style: estiloEje),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _PintorLinea extends CustomPainter {
  _PintorLinea({
    required this.valores,
    required this.color,
    required this.colorGuia,
  });

  final List<double> valores;
  final Color color;
  final Color colorGuia;

  @override
  void paint(Canvas canvas, Size size) {
    final double minimo = valores.reduce(math.min);
    final double maximo = valores.reduce(math.max);
    // Si todos los pesos son iguales, la línea queda en la mitad.
    final double rango = maximo - minimo == 0 ? 1 : maximo - minimo;
    const double margen = 6;
    final double alto = size.height - 2 * margen;

    Offset punto(int i) => Offset(
          valores.length == 1 ? size.width / 2 : size.width * i / (valores.length - 1),
          maximo - minimo == 0
              ? size.height / 2
              : margen + alto * (1 - (valores[i] - minimo) / rango),
        );

    final Paint guia = Paint()
      ..color = colorGuia
      ..strokeWidth = 1;
    canvas.drawLine(Offset(0, margen), Offset(size.width, margen), guia);
    canvas.drawLine(Offset(0, size.height - margen),
        Offset(size.width, size.height - margen), guia);

    final Path camino = Path()..moveTo(punto(0).dx, punto(0).dy);
    for (int i = 1; i < valores.length; i++) {
      camino.lineTo(punto(i).dx, punto(i).dy);
    }
    canvas.drawPath(
      camino,
      Paint()
        ..color = color
        ..strokeWidth = 2.5
        ..style = PaintingStyle.stroke
        ..strokeJoin = StrokeJoin.round,
    );

    final Paint relleno = Paint()..color = color;
    for (int i = 0; i < valores.length; i++) {
      canvas.drawCircle(punto(i), 3.5, relleno);
    }
  }

  @override
  bool shouldRepaint(_PintorLinea anterior) =>
      anterior.valores != valores ||
      anterior.color != color ||
      anterior.colorGuia != colorGuia;
}

// ---------------------------------------------------------------------
// Historial
// ---------------------------------------------------------------------

class _FilaHistorial extends StatelessWidget {
  const _FilaHistorial({
    required this.medicion,
    required this.anterior,
    required this.alBorrar,
  });

  final MedicionAntropometrica medicion;

  /// La medición previa a esta, para mostrar cuánto cambió el peso.
  final MedicionAntropometrica? anterior;

  final VoidCallback alBorrar;

  @override
  Widget build(BuildContext context) {
    final MedicionAntropometrica? previa = anterior;
    final String cambio = previa == null
        ? ''
        : '  (${formatearDiferencia(medicion.pesoKg - previa.pesoKg)} kg)';

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        title: Text(formatearFecha(medicion.registradaEn)),
        subtitle: Text(
          '${formatearNumero(medicion.pesoKg)} kg$cambio · '
          'IMC ${formatearNumero(medicion.imc)}',
        ),
        trailing: IconButton(
          tooltip: 'Borrar medición',
          icon: const Icon(Icons.delete_outline),
          onPressed: alBorrar,
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------
// Registrar una medición nueva
// ---------------------------------------------------------------------

class _PantallaNuevaMedicion extends StatefulWidget {
  const _PantallaNuevaMedicion({this.anterior});

  /// La última medición, para prellenar la estatura y mostrar como
  /// referencia los valores anteriores.
  final MedicionAntropometrica? anterior;

  @override
  State<_PantallaNuevaMedicion> createState() => _PantallaNuevaMedicionState();
}

class _PantallaNuevaMedicionState extends State<_PantallaNuevaMedicion> {
  final GlobalKey<FormState> _formulario = GlobalKey<FormState>();
  final TextEditingController _peso = TextEditingController();
  late final TextEditingController _estatura;
  final TextEditingController _cintura = TextEditingController();
  final TextEditingController _cadera = TextEditingController();
  final TextEditingController _pecho = TextEditingController();
  final TextEditingController _brazo = TextEditingController();
  final TextEditingController _muslo = TextEditingController();

  bool _guardando = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    // La estatura de un adulto casi no cambia: se prellena con la
    // anterior. Lo demás se deja vacío para que se mida de nuevo.
    final double? estatura = widget.anterior?.estaturaCm;
    _estatura = TextEditingController(
      text: estatura == null ? '' : formatearNumero(estatura),
    );
  }

  @override
  void dispose() {
    for (final TextEditingController c in <TextEditingController>[
      _peso, _estatura, _cintura, _cadera, _pecho, _brazo, _muslo,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _guardar() async {
    if (!_formulario.currentState!.validate()) return;

    setState(() {
      _guardando = true;
      _error = null;
    });
    try {
      final MedicionAntropometrica nueva =
          await Repositorios.perfiles.registrarMedicion(
        pesoKg: leerNumero(_peso.text)!,
        estaturaCm: leerNumero(_estatura.text)!,
        cinturaCm: leerNumero(_cintura.text),
        caderaCm: leerNumero(_cadera.text),
        pechoCm: leerNumero(_pecho.text),
        brazoCm: leerNumero(_brazo.text),
        musloCm: leerNumero(_muslo.text),
      );
      if (mounted) Navigator.of(context).pop(nueva);
    } on ErrorDeDatos catch (e) {
      if (mounted) setState(() => _error = e.mensaje);
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  /// "Antes: 72,5" debajo del campo, si hay medición anterior.
  String? _antes(double? valor) =>
      valor == null ? null : 'Antes: ${formatearNumero(valor)}';

  Widget _campo({
    required TextEditingController controlador,
    required String etiqueta,
    required String? Function(String?) validador,
    String? ayuda,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: TextFormField(
        controller: controlador,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        decoration: InputDecoration(
          labelText: etiqueta,
          helperText: ayuda,
          border: const OutlineInputBorder(),
        ),
        validator: validador,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final TextTheme textos = Theme.of(context).textTheme;
    final ColorScheme esquema = Theme.of(context).colorScheme;
    final MedicionAntropometrica? a = widget.anterior;

    return Scaffold(
      appBar: AppBar(title: const Text('Nueva medición')),
      body: SafeArea(
        child: Form(
          key: _formulario,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
            children: <Widget>[
              Text(
                'Se guarda con la fecha de hoy. Tus mediciones anteriores '
                'no se modifican.',
                style:
                    textos.bodyMedium?.copyWith(color: esquema.onSurfaceVariant),
              ),
              const SizedBox(height: 20),
              _campo(
                controlador: _peso,
                etiqueta: 'Peso (kg)',
                validador: validarPeso,
                ayuda: _antes(a?.pesoKg),
              ),
              _campo(
                controlador: _estatura,
                etiqueta: 'Estatura (cm)',
                validador: validarEstatura,
              ),
              const SizedBox(height: 6),
              Text('Circunferencias en cm (opcionales)',
                  style: textos.titleSmall),
              const SizedBox(height: 12),
              _campo(
                controlador: _cintura,
                etiqueta: 'Cintura',
                validador: validarCircunferencia,
                ayuda: _antes(a?.cinturaCm),
              ),
              _campo(
                controlador: _cadera,
                etiqueta: 'Cadera',
                validador: validarCircunferencia,
                ayuda: _antes(a?.caderaCm),
              ),
              _campo(
                controlador: _pecho,
                etiqueta: 'Pecho',
                validador: validarCircunferencia,
                ayuda: _antes(a?.pechoCm),
              ),
              _campo(
                controlador: _brazo,
                etiqueta: 'Brazo',
                validador: validarCircunferencia,
                ayuda: _antes(a?.brazoCm),
              ),
              _campo(
                controlador: _muslo,
                etiqueta: 'Muslo',
                validador: validarCircunferencia,
                ayuda: _antes(a?.musloCm),
              ),
              const SizedBox(height: 6),
              if (_error != null) ...<Widget>[
                _Aviso(texto: _error!),
                const SizedBox(height: 16),
              ],
              FilledButton(
                onPressed: _guardando ? null : _guardar,
                child: _guardando
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Guardar medición'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------
// Piezas compartidas de este archivo
// ---------------------------------------------------------------------

class _Aviso extends StatelessWidget {
  const _Aviso({required this.texto});

  final String texto;

  @override
  Widget build(BuildContext context) {
    final ColorScheme esquema = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: esquema.errorContainer,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(Icons.info_outline, size: 20, color: esquema.onErrorContainer),
          const SizedBox(width: 10),
          Expanded(
            child: Text(texto, style: TextStyle(color: esquema.onErrorContainer)),
          ),
        ],
      ),
    );
  }
}
