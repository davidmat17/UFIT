import 'package:flutter/material.dart';

import '../../../core/datos/errores.dart';
import '../../../core/datos/repositorios.dart';
import '../../../core/modelos/normativa.dart';
import '../reglas_normativa.dart';

/// RF6 - Consulta de normativa del gimnasio
///
/// Módulo: gimnasio | Responsable: Sergio
///
/// Muestra el reglamento vigente con su versión y fecha de última
/// actualización (HU14). No exige sesión: se abre desde la barra de
/// ayuda del ingreso y también desde el inicio. Sigue el CU06:
/// - 2a: sin internet muestra la última versión descargada, con su fecha.
/// - 2b: si no hay normativa publicada, lo dice.
class PantallaNormativa extends StatefulWidget {
  const PantallaNormativa({super.key});

  @override
  State<PantallaNormativa> createState() => _PantallaNormativaState();
}

class _PantallaNormativaState extends State<PantallaNormativa> {
  bool _cargando = true;
  String? _errorDeCarga;
  Normativa? _normativa;

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
    await _consultar();
    if (mounted) setState(() => _cargando = false);
  }

  /// Lo usa también "deslizar para actualizar".
  Future<void> _consultar() async {
    try {
      final Normativa? normativa =
          await Repositorios.gimnasio.normativaVigente();
      if (!mounted) return;
      setState(() {
        _normativa = normativa;
        _errorDeCarga = null;
      });
    } on ErrorDeDatos catch (e) {
      if (!mounted) return;
      setState(() => _errorDeCarga = e.mensaje);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Normativa del gimnasio')),
      body: _cuerpo(context),
    );
  }

  Widget _cuerpo(BuildContext context) {
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

    final Normativa? n = _normativa;
    final List<String> reglas =
        n == null ? const <String>[] : reglasDeLaNormativa(n.contenido);

    // CU06, flujo 2b: si no hay normativa publicada, se dice.
    if (n == null || reglas.isEmpty) {
      return RefreshIndicator(
        onRefresh: _consultar,
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: <Widget>[
            const SizedBox(height: 40),
            const _Vacio(
              icono: Icons.gavel_outlined,
              titulo: 'Aún no hay normativa publicada',
              texto: 'La administración del gimnasio todavía no ha '
                  'publicado el reglamento. Vuelve a consultar más tarde.',
            ),
            if (n != null) ...<Widget>[
              const SizedBox(height: 16),
              _LineaDeVersion(normativa: n, centrada: true),
            ],
          ],
        ),
      );
    }

    final TextTheme textos = Theme.of(context).textTheme;

    return RefreshIndicator(
      onRefresh: _consultar,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        children: <Widget>[
          // CU06, flujo 2a.
          if (n.desdeCopiaLocal) ...<Widget>[
            const _AvisoSinConexion(),
            const SizedBox(height: 16),
          ],
          Text(n.titulo, style: textos.headlineSmall),
          const SizedBox(height: 6),
          _LineaDeVersion(normativa: n),
          const SizedBox(height: 20),
          for (int i = 0; i < reglas.length; i++)
            _Regla(numero: i + 1, texto: reglas[i]),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------
// Piezas de esta pantalla
// ---------------------------------------------------------------------

class _LineaDeVersion extends StatelessWidget {
  const _LineaDeVersion({required this.normativa, this.centrada = false});

  final Normativa normativa;
  final bool centrada;

  @override
  Widget build(BuildContext context) {
    final TextTheme textos = Theme.of(context).textTheme;
    final ColorScheme esquema = Theme.of(context).colorScheme;

    return Text(
      'Versión ${normativa.version} · Actualizada el '
      '${fechaLarga(normativa.publicadaEn)}',
      textAlign: centrada ? TextAlign.center : TextAlign.start,
      style: textos.bodySmall?.copyWith(color: esquema.onSurfaceVariant),
    );
  }
}

class _Regla extends StatelessWidget {
  const _Regla({required this.numero, required this.texto});

  final int numero;
  final String texto;

  @override
  Widget build(BuildContext context) {
    final TextTheme textos = Theme.of(context).textTheme;
    final ColorScheme esquema = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Container(
            width: 28,
            height: 28,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: esquema.primaryContainer,
              shape: BoxShape.circle,
            ),
            child: Text(
              '$numero',
              style: textos.labelLarge
                  ?.copyWith(color: esquema.onPrimaryContainer),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(texto, style: textos.bodyLarge),
            ),
          ),
        ],
      ),
    );
  }
}

class _AvisoSinConexion extends StatelessWidget {
  const _AvisoSinConexion();

  @override
  Widget build(BuildContext context) {
    final ColorScheme esquema = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: esquema.secondaryContainer,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(Icons.cloud_off_outlined,
              size: 20, color: esquema.onSecondaryContainer),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Sin conexión. Estás viendo la última versión descargada; '
              'puede haber una más reciente.',
              style: TextStyle(color: esquema.onSecondaryContainer),
            ),
          ),
        ],
      ),
    );
  }
}

class _Vacio extends StatelessWidget {
  const _Vacio({
    required this.icono,
    required this.titulo,
    required this.texto,
  });

  final IconData icono;
  final String titulo;
  final String texto;

  @override
  Widget build(BuildContext context) {
    final TextTheme textos = Theme.of(context).textTheme;
    final ColorScheme esquema = Theme.of(context).colorScheme;

    return Column(
      children: <Widget>[
        Icon(icono, size: 44, color: esquema.onSurfaceVariant),
        const SizedBox(height: 12),
        Text(titulo, style: textos.titleMedium, textAlign: TextAlign.center),
        const SizedBox(height: 6),
        Text(
          texto,
          textAlign: TextAlign.center,
          style: textos.bodyMedium?.copyWith(color: esquema.onSurfaceVariant),
        ),
      ],
    );
  }
}

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
            child:
                Text(texto, style: TextStyle(color: esquema.onErrorContainer)),
          ),
        ],
      ),
    );
  }
}
