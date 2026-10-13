import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../../core/modelos/ejercicio.dart';
import '../../../core/modelos/maquina.dart';
import '../reglas_catalogo.dart';

/// RF5 - Ficha de una máquina del catálogo
///
/// Módulo: gimnasio | Responsable: Sergio
///
/// Muestra los datos de la máquina y los ejercicios que se pueden hacer
/// en ella, cada uno con sus instrucciones de ejecución (CU05, paso 5;
/// HU13). No consulta la base: recibe la máquina ya cargada por el
/// catálogo, con sus ejercicios.
class PantallaDetalleMaquina extends StatelessWidget {
  const PantallaDetalleMaquina({
    super.key,
    required this.maquina,
    required this.categoria,
  });

  final Maquina maquina;

  /// Nombre de la zona a la que pertenece: Cardiovascular, Fuerza o
  /// Musculación.
  final String categoria;

  @override
  Widget build(BuildContext context) {
    final TextTheme textos = Theme.of(context).textTheme;
    final ColorScheme esquema = Theme.of(context).colorScheme;
    final Maquina m = maquina;

    return Scaffold(
      appBar: AppBar(title: Text(m.nombre)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: <Widget>[
          ImagenDeMaquina(url: m.imagenUrl, alto: 240, completa: true),
          const SizedBox(height: 16),
          Text(m.nombre, style: textos.headlineSmall),
          const SizedBox(height: 8),
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  categoria,
                  style: textos.bodyMedium?.copyWith(color: esquema.primary),
                ),
              ),
              EtiquetaDeEstado(estado: m.estado),
            ],
          ),
          if (!m.estaDisponible) ...<Widget>[
            const SizedBox(height: 16),
            _Nota(
              texto: 'Esta máquina está fuera de servicio por ahora. Puedes '
                  'consultar sus ejercicios, pero no está disponible para '
                  'usarla en el gimnasio.',
            ),
          ],
          const SizedBox(height: 16),
          Card(
            child: Column(
              children: <Widget>[
                ListTile(
                  leading: const Icon(Icons.place_outlined),
                  title: const Text('Zona'),
                  subtitle: Text(categoria),
                ),
                ListTile(
                  leading: const Icon(Icons.fitness_center),
                  title: const Text('Unidades en el gimnasio'),
                  subtitle: Text('${m.cantidad}'),
                ),
              ],
            ),
          ),
          if ((m.descripcion ?? '').trim().isNotEmpty) ...<Widget>[
            const SizedBox(height: 16),
            Text(m.descripcion!, style: textos.bodyLarge),
          ],
          const SizedBox(height: 24),
          Text(
            m.ejercicios.isEmpty
                ? 'Ejercicios'
                : 'Ejercicios (${m.ejercicios.length})',
            style: textos.titleMedium,
          ),
          const SizedBox(height: 8),
          if (m.ejercicios.isEmpty)
            Text(
              'Esta máquina todavía no tiene ejercicios registrados.',
              style:
                  textos.bodyMedium?.copyWith(color: esquema.onSurfaceVariant),
            )
          else
            for (final Ejercicio e in m.ejercicios)
              _TarjetaEjercicio(ejercicio: e),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------
// Piezas que también usa el catálogo
// ---------------------------------------------------------------------

/// La etiqueta de color con el estado de la máquina.
class EtiquetaDeEstado extends StatelessWidget {
  const EtiquetaDeEstado({super.key, required this.estado});

  final EstadoMaquina estado;

  @override
  Widget build(BuildContext context) {
    final ColorScheme esquema = Theme.of(context).colorScheme;
    final bool disponible = estado == EstadoMaquina.disponible;
    final Color fondo =
        disponible ? esquema.secondaryContainer : esquema.errorContainer;
    final Color letra =
        disponible ? esquema.onSecondaryContainer : esquema.onErrorContainer;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: fondo,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(
            disponible ? Icons.check_circle_outline : Icons.build_outlined,
            size: 14,
            color: letra,
          ),
          const SizedBox(width: 4),
          Text(
            textoDelEstado(estado),
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: letra,
            ),
          ),
        ],
      ),
    );
  }
}

/// La foto de la máquina, o un ícono si no tiene o no carga.
///
/// Usa caché en disco: la primera vez descarga la foto y la guarda en el
/// celular; las siguientes la muestra al instante, incluso sin conexión
/// (CU05, flujo 4b).
class ImagenDeMaquina extends StatelessWidget {
  const ImagenDeMaquina({
    super.key,
    required this.url,
    required this.alto,
    this.completa = false,
  });

  final String? url;
  final double alto;

  /// true muestra la foto entera (en la ficha); false la recorta para
  /// llenar el cuadro (en la miniatura del catálogo).
  final bool completa;

  /// Wikimedia rechaza las descargas que no dicen qué aplicación las
  /// pide. Desde la migración 006 las fotos salen del Storage de
  /// Supabase y no lo necesitan, pero se deja por si alguna dirección
  /// sigue apuntando a Wikimedia.
  static const Map<String, String> _encabezados = <String, String>{
    'User-Agent': 'UFIT/1.0 (prototipo academico, Ingenieria de Software 1, UIS)',
  };

  @override
  Widget build(BuildContext context) {
    final ColorScheme esquema = Theme.of(context).colorScheme;

    final Widget sinFoto = Container(
      height: alto,
      width: double.infinity,
      color: esquema.surfaceContainerHighest,
      alignment: Alignment.center,
      child: Icon(
        Icons.fitness_center,
        size: alto * 0.4,
        color: esquema.onSurfaceVariant,
      ),
    );

    final String direccion = (url ?? '').trim();

    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: direccion.isEmpty
          ? sinFoto
          : Container(
              height: alto,
              width: double.infinity,
              color: esquema.surfaceContainerHighest,
              child: CachedNetworkImage(
                imageUrl: direccion,
                httpHeaders: _encabezados,
                height: alto,
                width: double.infinity,
                fit: completa ? BoxFit.contain : BoxFit.cover,
                fadeInDuration: const Duration(milliseconds: 200),
                // Mientras descarga, el cuadro gris con una rueda.
                placeholder: (_, _) => const Center(
                  child: SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
                errorWidget: (_, _, _) => sinFoto,
              ),
            ),
    );
  }
}

// ---------------------------------------------------------------------
// Piezas de este archivo
// ---------------------------------------------------------------------

class _TarjetaEjercicio extends StatelessWidget {
  const _TarjetaEjercicio({required this.ejercicio});

  final Ejercicio ejercicio;

  @override
  Widget build(BuildContext context) {
    final TextTheme textos = Theme.of(context).textTheme;
    final ColorScheme esquema = Theme.of(context).colorScheme;
    final Ejercicio e = ejercicio;
    final String instrucciones = (e.instrucciones ?? '').trim();

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(e.nombre, style: textos.titleMedium),
            const SizedBox(height: 4),
            Text(
              'Grupo muscular: ${e.grupoMuscular}',
              style: textos.bodySmall?.copyWith(color: esquema.primary),
            ),
            if ((e.descripcion ?? '').trim().isNotEmpty) ...<Widget>[
              const SizedBox(height: 8),
              Text(e.descripcion!, style: textos.bodyMedium),
            ],
            const SizedBox(height: 12),
            Text('Cómo se hace', style: textos.labelLarge),
            const SizedBox(height: 4),
            Text(
              instrucciones.isEmpty
                  ? 'Las instrucciones de este ejercicio todavía no están '
                      'registradas.'
                  : instrucciones,
              style: instrucciones.isEmpty
                  ? textos.bodyMedium
                      ?.copyWith(color: esquema.onSurfaceVariant)
                  : textos.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }
}

class _Nota extends StatelessWidget {
  const _Nota({required this.texto});

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
