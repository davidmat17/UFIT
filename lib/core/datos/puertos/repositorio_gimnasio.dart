import '../../modelos/maquina.dart';
import '../../modelos/zona.dart';

/// Puerto de información del gimnasio (RF5, RF6, RF7).
abstract class RepositorioGimnasio {
  Future<List<Zona>> zonas();

  /// El catálogo, opcionalmente filtrado por zona. Cada máquina trae
  /// sus ejercicios asociados (RF5).
  Future<List<Maquina>> maquinas({int? zonaId});

  /// El texto de la normativa vigente, o null si no hay ninguna publicada.
  Future<String?> normativaVigente();
}
