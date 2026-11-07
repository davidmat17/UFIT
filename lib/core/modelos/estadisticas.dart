/// Estadísticas de ocupación y uso del gimnasio (RF12), tal como las
/// calcula la función estadisticas_uso() de la base
/// (supabase/migraciones/017_rf12_estadisticas.sql).
library;

/// Los totales del periodo consultado.
class ResumenDeUso {
  const ResumenDeUso({
    required this.franjas,
    required this.reservas,
    required this.asistidas,
    required this.noAsistidas,
    required this.pendientes,
    required this.canceladas,
    this.ocupacionPromedio,
  });

  /// Franjas publicadas en el periodo (con el filtro de hora, si hay).
  final int franjas;

  /// Todas las reservas hechas, incluidas las canceladas.
  final int reservas;
  final int asistidas;
  final int noAsistidas;

  /// Confirmadas cuya franja todavía no termina.
  final int pendientes;
  final int canceladas;

  /// Porcentaje promedio de cupos ocupados por franja, de 0 a 100. null si
  /// no hay franjas en el periodo.
  final double? ocupacionPromedio;

  /// Reservas que ya pasaron sin cancelarse: sobre ellas se mide la
  /// asistencia efectiva.
  int get pasadas => asistidas + noAsistidas;

  /// Asistencia efectiva frente a reservas, de 0 a 100, o null si no hay
  /// reservas pasadas.
  double? get asistenciaEfectiva =>
      pasadas == 0 ? null : asistidas * 100 / pasadas;

  /// true si no hay nada que graficar (CU12, 4b).
  bool get sinDatos => reservas == 0;
}

/// Una fila de un desglose: por hora, por día de la semana o por zona.
class UsoPorGrupo {
  const UsoPorGrupo({
    required this.etiqueta,
    required this.reservas,
    required this.asistidas,
    this.franjas = 0,
    this.ocupacion,
    this.noAsistidas = 0,
    this.canceladas = 0,
  });

  /// "06:00", "Lunes", "Cardiovascular".
  final String etiqueta;
  final int franjas;

  /// Reservas vivas (sin las canceladas).
  final int reservas;
  final int asistidas;
  final int noAsistidas;
  final int canceladas;

  /// Ocupación promedio de las franjas del grupo, de 0 a 100. null en el
  /// desglose por zona, donde el cupo es de la franja y no de la zona.
  final double? ocupacion;
}

/// Las máquinas de una zona, por estado.
class InventarioDeZona {
  const InventarioDeZona({
    required this.zona,
    required this.disponibles,
    required this.fueraDeServicio,
  });

  final String zona;
  final int disponibles;
  final int fueraDeServicio;
}

class EstadisticasDeUso {
  const EstadisticasDeUso({
    required this.desde,
    required this.hasta,
    required this.resumen,
    this.porHora = const <UsoPorGrupo>[],
    this.porDia = const <UsoPorGrupo>[],
    this.porZona = const <UsoPorGrupo>[],
    this.inventario = const <InventarioDeZona>[],
  });

  final DateTime desde;
  final DateTime hasta;
  final ResumenDeUso resumen;
  final List<UsoPorGrupo> porHora;
  final List<UsoPorGrupo> porDia;
  final List<UsoPorGrupo> porZona;
  final List<InventarioDeZona> inventario;
}
