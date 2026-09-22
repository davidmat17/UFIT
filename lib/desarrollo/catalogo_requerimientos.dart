import 'modelo_requerimiento.dart';
import '../core/rutas.dart';

import '../features/admin/pantallas/rf12_estadisticas.dart';
import '../features/admin/pantallas/rf13_gestion_contenidos.dart';
import '../features/cuenta/pantallas/rf01_autenticacion.dart';
import '../features/cuenta/pantallas/rf08_antropometria.dart';
import '../features/cuenta/pantallas/rf10_datos_personales.dart';
import '../features/entrenamiento/pantallas/rf11_rutinas.dart';
import '../features/gimnasio/pantallas/rf05_catalogo.dart';
import '../features/gimnasio/pantallas/rf06_normativa.dart';
import '../features/gimnasio/pantallas/rf07_instructores.dart';
import '../features/reservas/pantallas/rf02_reservas.dart';
import '../features/reservas/pantallas/rf03_cancelar_reserva.dart';
import '../features/reservas/pantallas/rf04_asistencia_qr.dart';
import '../features/reservas/pantallas/rf09_historial.dart';

/// Los 13 requerimientos funcionales, en el orden del documento.
///
/// De esta lista salen tanto el menu de la pantalla de inicio como el
/// mapa de rutas de la app: agregar una pantalla nueva es agregar una
/// entrada aqui, en ningun otro lado.
final List<Requerimiento> catalogoRequerimientos = <Requerimiento>[
  Requerimiento(
    id: 'RF1',
    titulo: 'Registro e inicio de sesion de usuarios',
    modulo: Modulo.cuenta,
    ruta: Rutas.rf01Autenticacion,
    construir: (_) => const PantallaAutenticacion(),
  ),
  Requerimiento(
    id: 'RF2',
    titulo: 'Gestion de reservas de cupos en franjas horarias',
    modulo: Modulo.reservas,
    ruta: Rutas.rf02Reservas,
    construir: (_) => const PantallaReservas(),
  ),
  Requerimiento(
    id: 'RF3',
    titulo: 'Cancelacion de reservas',
    modulo: Modulo.reservas,
    ruta: Rutas.rf03CancelarReserva,
    construir: (_) => const PantallaCancelarReserva(),
  ),
  Requerimiento(
    id: 'RF4',
    titulo: 'Registro de asistencia mediante codigo QR',
    modulo: Modulo.reservas,
    ruta: Rutas.rf04AsistenciaQr,
    construir: (_) => const PantallaAsistenciaQr(),
  ),
  Requerimiento(
    id: 'RF5',
    titulo: 'Consulta de catalogo de maquinas y ejercicios',
    modulo: Modulo.gimnasio,
    ruta: Rutas.rf05Catalogo,
    construir: (_) => const PantallaCatalogo(),
  ),
  Requerimiento(
    id: 'RF6',
    titulo: 'Consulta de normativa del gimnasio',
    modulo: Modulo.gimnasio,
    ruta: Rutas.rf06Normativa,
    construir: (_) => const PantallaNormativa(),
  ),
  Requerimiento(
    id: 'RF7',
    titulo: 'Visualizacion de disponibilidad de instructores',
    modulo: Modulo.gimnasio,
    ruta: Rutas.rf07Instructores,
    construir: (_) => const PantallaInstructores(),
  ),
  Requerimiento(
    id: 'RF8',
    titulo: 'Registro y gestion de datos antropometricos',
    modulo: Modulo.cuenta,
    ruta: Rutas.rf08Antropometria,
    construir: (_) => const PantallaAntropometria(),
  ),
  Requerimiento(
    id: 'RF9',
    titulo: 'Consulta de historial de asistencia y reservas',
    modulo: Modulo.reservas,
    ruta: Rutas.rf09Historial,
    construir: (_) => const PantallaHistorial(),
  ),
  Requerimiento(
    id: 'RF10',
    titulo: 'Consulta y actualizacion de datos personales',
    modulo: Modulo.cuenta,
    ruta: Rutas.rf10DatosPersonales,
    construir: (_) => const PantallaDatosPersonales(),
  ),
  Requerimiento(
    id: 'RF11',
    titulo: 'Gestion de rutinas de ejercicio',
    modulo: Modulo.entrenamiento,
    ruta: Rutas.rf11Rutinas,
    construir: (_) => const PantallaRutinas(),
  ),
  Requerimiento(
    id: 'RF12',
    titulo: 'Visualizacion de estadisticas de ocupacion y uso',
    modulo: Modulo.admin,
    ruta: Rutas.rf12Estadisticas,
    construir: (_) => const PantallaEstadisticas(),
  ),
  Requerimiento(
    id: 'RF13',
    titulo: 'Gestion administrativa de contenidos del gimnasio',
    modulo: Modulo.admin,
    ruta: Rutas.rf13GestionContenidos,
    construir: (_) => const PantallaGestionContenidos(),
  ),
];

/// Los requerimientos de un modulo, en orden.
List<Requerimiento> requerimientosDe(Modulo modulo) =>
    catalogoRequerimientos.where((Requerimiento r) => r.modulo == modulo).toList();
