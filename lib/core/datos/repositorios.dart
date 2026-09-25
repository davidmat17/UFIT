import 'puertos/repositorio_admin.dart';
import 'puertos/repositorio_entrenamiento.dart';
import 'puertos/repositorio_gimnasio.dart';
import 'puertos/repositorio_perfiles.dart';
import 'puertos/repositorio_reservas.dart';

/// Registro de los repositorios que la app está usando.
///
/// El núcleo solo conoce los puertos —las clases abstractas—, nunca las
/// implementaciones. Quién los llena se decide en main.dart, que es el
/// único sitio autorizado a conocer Supabase y los módulos a la vez.
///
/// En las pruebas se llama a [registrar] con dobles de prueba, y las
/// pantallas funcionan sin red ni base de datos.
class Repositorios {
  Repositorios._();

  static late RepositorioPerfiles perfiles;
  static late RepositorioGimnasio gimnasio;
  static late RepositorioReservas reservas;
  static late RepositorioEntrenamiento entrenamiento;
  static late RepositorioAdmin admin;

  static void registrar({
    required RepositorioPerfiles perfiles,
    required RepositorioGimnasio gimnasio,
    required RepositorioReservas reservas,
    required RepositorioEntrenamiento entrenamiento,
    required RepositorioAdmin admin,
  }) {
    Repositorios.perfiles = perfiles;
    Repositorios.gimnasio = gimnasio;
    Repositorios.reservas = reservas;
    Repositorios.entrenamiento = entrenamiento;
    Repositorios.admin = admin;
  }
}
