import 'package:flutter/material.dart';

import '../../../core/datos/repositorios.dart';
import '../../../core/modelos/perfil.dart';

/// Piezas de pantalla que comparten el RF12 y el RF13.

void mostrarMensaje(BuildContext context, String texto) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(texto)));
}

/// Pide confirmación con un diálogo. true si la persona aceptó.
Future<bool> confirmar(
  BuildContext context, {
  required String titulo,
  required String mensaje,
  required String aceptar,
  String cancelar = 'Cancelar',
}) async {
  final bool? r = await showDialog<bool>(
    context: context,
    builder: (BuildContext contexto) => AlertDialog(
      title: Text(titulo),
      content: Text(mensaje),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(contexto).pop(false),
          child: Text(cancelar),
        ),
        TextButton(
          onPressed: () => Navigator.of(contexto).pop(true),
          child: Text(aceptar),
        ),
      ],
    ),
  );
  return r ?? false;
}

class AvisoAdmin extends StatelessWidget {
  const AvisoAdmin({super.key, required this.texto, this.esError = true});

  final String texto;
  final bool esError;

  @override
  Widget build(BuildContext context) {
    final ColorScheme esquema = Theme.of(context).colorScheme;
    final Color fondo =
        esError ? esquema.errorContainer : esquema.surfaceContainerHighest;
    final Color color =
        esError ? esquema.onErrorContainer : esquema.onSurfaceVariant;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: fondo,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(Icons.info_outline, size: 20, color: color),
          const SizedBox(width: 10),
          Expanded(child: Text(texto, style: TextStyle(color: color))),
        ],
      ),
    );
  }
}

class CargandoAdmin extends StatelessWidget {
  const CargandoAdmin({super.key});

  @override
  Widget build(BuildContext context) => const Padding(
        padding: EdgeInsets.symmetric(vertical: 40),
        child: Center(
          child: CircularProgressIndicator(semanticsLabel: 'Cargando'),
        ),
      );
}

/// Un error con el botón de reintentar.
class ErrorConReintento extends StatelessWidget {
  const ErrorConReintento({
    super.key,
    required this.mensaje,
    required this.alReintentar,
  });

  final String mensaje;
  final VoidCallback alReintentar;

  @override
  Widget build(BuildContext context) => ListView(
        padding: const EdgeInsets.all(16),
        children: <Widget>[
          AvisoAdmin(texto: mensaje),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: alReintentar,
            child: const Text('Reintentar'),
          ),
        ],
      );
}

/// Muestra [hijo] solo si quien tiene la sesión es administrador; si no,
/// explica que la sección es solo para administradores. La barrera real
/// está en la base: esto solo evita mostrar una pantalla que fallaría.
class SoloAdministrador extends StatefulWidget {
  const SoloAdministrador({
    super.key,
    required this.titulo,
    required this.construir,
  });

  final String titulo;
  final WidgetBuilder construir;

  @override
  State<SoloAdministrador> createState() => _SoloAdministradorState();
}

class _SoloAdministradorState extends State<SoloAdministrador> {
  late Future<Perfil?> _perfil = Repositorios.perfiles.perfilActual();

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Perfil?>(
      future: _perfil,
      builder: (BuildContext context, AsyncSnapshot<Perfil?> s) {
        if (s.connectionState != ConnectionState.done) {
          return Scaffold(
            appBar: AppBar(title: Text(widget.titulo)),
            body: const CargandoAdmin(),
          );
        }
        if (s.hasError) {
          return Scaffold(
            appBar: AppBar(title: Text(widget.titulo)),
            body: ErrorConReintento(
              mensaje: 'No se pudo comprobar tu rol. Revisa tu conexión.',
              alReintentar: () => setState(() {
                _perfil = Repositorios.perfiles.perfilActual();
              }),
            ),
          );
        }
        if (s.data?.esAdministrador != true) {
          return Scaffold(
            appBar: AppBar(title: Text(widget.titulo)),
            body: const Padding(
              padding: EdgeInsets.all(16),
              child: AvisoAdmin(
                texto: 'Esta sección es solo para el administrador del '
                    'gimnasio.',
              ),
            ),
          );
        }
        return widget.construir(context);
      },
    );
  }
}
