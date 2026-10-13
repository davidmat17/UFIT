import '../../core/modelos/ejercicio.dart';
import '../../core/modelos/maquina.dart';
import '../../core/modelos/zona.dart';

/// Reglas del catálogo de máquinas (RF5), sin nada de pantalla.
///
/// Viven aparte para poder probarlas sin construir widgets: qué se
/// muestra, cómo se busca y cómo se agrupa por categoría.

/// Una categoría del catálogo con las máquinas que le tocan.
///
/// En la base, la categoría de una máquina es su zona: cardiovascular,
/// fuerza o musculación.
class GrupoDeCatalogo {
  const GrupoDeCatalogo({required this.zona, required this.maquinas});

  final Zona zona;
  final List<Maquina> maquinas;
}

/// Las máquinas que se muestran al usuario.
///
/// Una máquina "retirada" está dada de baja (RF13) y ya no hace parte
/// del inventario, así que no se muestra. Una en mantenimiento sí se
/// muestra, marcada como fuera de servicio (CU05, flujo 4a).
List<Maquina> maquinasVisibles(List<Maquina> todas) => todas
    .where((Maquina m) => m.estado != EstadoMaquina.retirada)
    .toList();

/// El texto del estado tal como lo ve el usuario.
String textoDelEstado(EstadoMaquina estado) => switch (estado) {
      EstadoMaquina.disponible => 'Disponible',
      EstadoMaquina.mantenimiento => 'Fuera de servicio',
      EstadoMaquina.retirada => 'Retirada',
    };

/// Pasa a minúsculas y quita las tildes, para que "musculacion"
/// encuentre "Musculación" y "BICEPS" encuentre "bíceps".
String normalizar(String texto) {
  const Map<String, String> sinTilde = <String, String>{
    'á': 'a',
    'é': 'e',
    'í': 'i',
    'ó': 'o',
    'ú': 'u',
    'ü': 'u',
  };
  final StringBuffer salida = StringBuffer();
  for (final String letra in texto.toLowerCase().trim().split('')) {
    salida.write(sinTilde[letra] ?? letra);
  }
  return salida.toString();
}

/// Si la máquina coincide con lo que se escribió en la búsqueda.
///
/// Se busca en el nombre y la descripción de la máquina, y en el nombre
/// y el grupo muscular de sus ejercicios (CU05, paso 3: búsqueda por
/// texto o por grupo muscular). Una búsqueda vacía deja pasar todo.
bool coincideConBusqueda(Maquina maquina, String busqueda) {
  final String buscado = normalizar(busqueda);
  if (buscado.isEmpty) return true;

  final List<String> dondeBuscar = <String>[
    maquina.nombre,
    maquina.descripcion ?? '',
    for (final Ejercicio e in maquina.ejercicios) ...<String>[
      e.nombre,
      e.grupoMuscular,
    ],
  ];

  return dondeBuscar.any((String t) => normalizar(t).contains(buscado));
}

/// Arma el catálogo agrupado por categoría.
///
/// Respeta el orden de las zonas como llegan de la base, omite las
/// zonas inactivas y las que se quedan sin máquinas después de filtrar.
/// [zonaElegida] en null significa "todas las categorías".
List<GrupoDeCatalogo> agruparPorCategoria({
  required List<Zona> zonas,
  required List<Maquina> maquinas,
  int? zonaElegida,
  String busqueda = '',
}) {
  final List<Maquina> filtradas = maquinasVisibles(maquinas)
      .where((Maquina m) => coincideConBusqueda(m, busqueda))
      .toList();

  final List<GrupoDeCatalogo> grupos = <GrupoDeCatalogo>[];
  for (final Zona zona in zonas) {
    if (!zona.activa) continue;
    if (zonaElegida != null && zona.id != zonaElegida) continue;

    final List<Maquina> deLaZona = filtradas
        .where((Maquina m) => m.zonaId == zona.id)
        .toList()
      ..sort((Maquina a, Maquina b) => a.nombre.compareTo(b.nombre));

    if (deLaZona.isNotEmpty) {
      grupos.add(GrupoDeCatalogo(zona: zona, maquinas: deLaZona));
    }
  }
  return grupos;
}
