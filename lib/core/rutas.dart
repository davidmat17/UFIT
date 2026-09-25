/// Nombres de las rutas de navegacion.
///
/// Se usan constantes en vez de escribir el texto a mano en cada
/// Navigator.pushNamed: si alguien se equivoca en una letra, el error
/// sale al compilar y no en tiempo de ejecucion.
class Rutas {
  Rutas._();

  static const String inicio = '/';

  /// Pantalla de desarrollo: comprueba la conexión con Supabase.
  static const String diagnostico = '/diagnostico';

  // Cuenta y perfil
  static const String rf01Autenticacion = '/rf01-autenticacion';
  static const String rf08Antropometria = '/rf08-antropometria';
  static const String rf10DatosPersonales = '/rf10-datos-personales';

  // Reservas y asistencia
  static const String rf02Reservas = '/rf02-reservas';
  static const String rf03CancelarReserva = '/rf03-cancelar-reserva';
  static const String rf04AsistenciaQr = '/rf04-asistencia-qr';
  static const String rf09Historial = '/rf09-historial';

  // Informacion del gimnasio
  static const String rf05Catalogo = '/rf05-catalogo';
  static const String rf06Normativa = '/rf06-normativa';
  static const String rf07Instructores = '/rf07-instructores';

  // Entrenamiento
  static const String rf11Rutinas = '/rf11-rutinas';

  // Administracion
  static const String rf12Estadisticas = '/rf12-estadisticas';
  static const String rf13GestionContenidos = '/rf13-gestion-contenidos';
}
