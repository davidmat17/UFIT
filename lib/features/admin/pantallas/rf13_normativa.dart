import 'package:flutter/material.dart';

import '../../../core/datos/errores.dart';
import '../../../core/datos/repositorios.dart';
import '../../../core/modelos/administracion.dart';
import '../reglas_admin.dart';
import 'piezas_admin.dart';

/// RF13 - Pestaña "Normativa" del panel de contenidos.
///
/// Publica versiones nuevas de la normativa (la anterior queda en el
/// histórico, CU13 4a) y ajusta el plazo para cancelar reservas (RF3).
/// Si otro administrador publicó mientras tanto, avisa en lugar de
/// sobrescribir (CU13, 5b).
class PestanaNormativa extends StatefulWidget {
  const PestanaNormativa({super.key});

  @override
  State<PestanaNormativa> createState() => _PestanaNormativaState();
}

class _PestanaNormativaState extends State<PestanaNormativa> {
  final GlobalKey<FormState> _form = GlobalKey<FormState>();
  final TextEditingController _titulo = TextEditingController();
  final TextEditingController _contenido = TextEditingController();

  bool _cargando = true;
  bool _publicando = false;
  String? _error;

  NormativaAdmin? _actual;
  int _horas = 3;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  @override
  void dispose() {
    _titulo.dispose();
    _contenido.dispose();
    super.dispose();
  }

  Future<void> _cargar() async {
    setState(() {
      _cargando = true;
      _error = null;
    });
    try {
      final NormativaAdmin? actual = await Repositorios.admin.normativaActual();
      final int horas = await Repositorios.admin.horasAntelacionCancelar();
      if (!mounted) return;
      setState(() {
        _actual = actual;
        _horas = horas;
        _titulo.text = actual?.titulo ?? 'Normativa del gimnasio';
        _contenido.text = actual?.contenido ?? '';
        _cargando = false;
      });
    } on ErrorDeDatos catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.mensaje;
        _cargando = false;
      });
    }
  }

  Future<void> _publicar() async {
    if (!(_form.currentState?.validate() ?? false)) return;
    final int base = _actual?.version ?? 0;

    final bool ok = await confirmar(
      context,
      titulo: '¿Publicar la versión ${base + 1}?',
      mensaje: 'Todos los usuarios verán la nueva versión de inmediato. La '
          'versión $base queda guardada en el histórico.',
      aceptar: 'Publicar',
    );
    if (!ok || !mounted) return;

    setState(() => _publicando = true);
    try {
      final RespuestaPublicacion r = await Repositorios.admin.publicarNormativa(
        titulo: _titulo.text,
        contenido: _contenido.text,
        versionBase: base,
      );
      if (!mounted) return;
      setState(() => _publicando = false);

      switch (r.resultado) {
        case ResultadoPublicacion.publicada:
          final DateTime cuando = r.publicadaEn ?? ahoraEnColombia();
          mostrarMensaje(
            context,
            'Versión ${r.version} publicada el ${fechaLarga(cuando)} a las '
            '${horaDelReloj(cuando)}.',
          );
          await _cargar();
        case ResultadoPublicacion.versionCambio:
          // CU13, 5b: no se sobrescribe. El texto escrito se conserva en
          // pantalla hasta que el administrador decida recargar.
          await showDialog<void>(
            context: context,
            builder: (BuildContext c) => AlertDialog(
              title: const Text('La normativa cambió'),
              content: Text(
                'Otro administrador publicó la versión ${r.version} mientras '
                'editabas. No se sobrescribió nada. Recarga para ver su '
                'versión y vuelve a aplicar tus cambios.',
              ),
              actions: <Widget>[
                TextButton(
                  onPressed: () => Navigator.of(c).pop(),
                  child: const Text('Entendido'),
                ),
              ],
            ),
          );
        case ResultadoPublicacion.desconocido:
          mostrarMensaje(context, 'No se pudo publicar. Inténtalo de nuevo.');
      }
    } on ErrorDeDatos catch (e) {
      if (!mounted) return;
      setState(() => _publicando = false);
      mostrarMensaje(context, e.mensaje);
    }
  }

  Future<void> _guardarHoras(int horas) async {
    final int antes = _horas;
    setState(() => _horas = horas);
    try {
      await Repositorios.admin.guardarHorasAntelacionCancelar(horas);
      if (mounted) {
        mostrarMensaje(
          context,
          'Plazo actualizado: las reservas se cancelan hasta '
          '${horas == 1 ? '1 hora' : '$horas horas'} antes.',
        );
      }
    } on ErrorDeDatos catch (e) {
      if (!mounted) return;
      setState(() => _horas = antes);
      mostrarMensaje(context, e.mensaje);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_cargando) return const CargandoAdmin();
    if (_error != null) {
      return ErrorConReintento(mensaje: _error!, alReintentar: _cargar);
    }

    final TextTheme textos = Theme.of(context).textTheme;
    final NormativaAdmin? actual = _actual;

    return Form(
      key: _form,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: <Widget>[
          Text('Normativa', style: textos.titleMedium),
          const SizedBox(height: 4),
          Text(
            actual == null
                ? 'Todavía no se ha publicado ninguna versión.'
                : 'Vigente: versión ${actual.version}, publicada el '
                    '${fechaLarga(actual.publicadaEn)} a las '
                    '${horaDelReloj(actual.publicadaEn)}.',
            style: textos.bodyMedium,
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _titulo,
            decoration: const InputDecoration(
              labelText: 'Título *',
              border: OutlineInputBorder(),
            ),
            validator: validarTituloNormativa,
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _contenido,
            minLines: 8,
            maxLines: 20,
            decoration: const InputDecoration(
              labelText: 'Reglamento y condiciones de uso *',
              helperText: 'Una regla por línea.',
              border: OutlineInputBorder(),
              alignLabelWithHint: true,
            ),
            validator: validarContenidoNormativa,
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: _publicando ? null : _publicar,
            icon: const Icon(Icons.publish),
            label: Text(_publicando
                ? 'Publicando…'
                : 'Publicar versión ${(actual?.version ?? 0) + 1}'),
          ),
          const SizedBox(height: 28),
          Text('Plazo para cancelar reservas', style: textos.titleMedium),
          const SizedBox(height: 4),
          Text(
            'Cuántas horas antes de la franja se puede cancelar una reserva.',
            style: textos.bodyMedium,
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<int>(
            key: ValueKey<int>(_horas),
            initialValue: _horas,
            decoration: const InputDecoration(border: OutlineInputBorder()),
            items: <DropdownMenuItem<int>>[
              for (int h = 0; h <= 24; h++)
                DropdownMenuItem<int>(
                  value: h,
                  child: Text(h == 0
                      ? 'Hasta que empiece la franja'
                      : (h == 1 ? '1 hora antes' : '$h horas antes')),
                ),
            ],
            onChanged: (int? v) {
              if (v != null && v != _horas) _guardarHoras(v);
            },
          ),
        ],
      ),
    );
  }
}
