import '../../modelos/franja_con_instructor.dart';
import '../../modelos/maquina.dart';
import '../../modelos/normativa.dart';
import '../../modelos/zona.dart';

/// Puerto de información del gimnasio (RF5, RF6, RF7).
abstract class RepositorioGimnasio {
  Future<List<Zona>> zonas();

  /// El catálogo, opcionalmente filtrado por zona. Cada máquina trae
  /// sus ejercicios asociados (RF5).
  Future<List<Maquina>> maquinas({int? zonaId});

  /// La normativa vigente con su versión y fecha, o null si no hay
  /// ninguna publicada (RF6). No exige sesión iniciada.
  ///
  /// Sin conexión devuelve la última versión descargada, marcada con
  /// [Normativa.desdeCopiaLocal]. Si tampoco hay copia, lanza
  /// ErrorDeDatos de tipo sinConexion.
  Future<Normativa?> normativaVigente();

  /// Las franjas entre [desde] y [hasta] (ambas incluidas) con el
  /// instructor asignado a cada una, si tiene (RF7). Exige sesión
  /// iniciada. Siempre consulta la base, así que refleja los cambios que
  /// haya hecho el administrador (CU07, flujo 4a).
  Future<List<FranjaConInstructor>> agendaInstructores({
    required DateTime desde,
    required DateTime hasta,
  });
}
