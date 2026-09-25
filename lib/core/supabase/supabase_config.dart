import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Arranque de la conexión con Supabase.
///
/// Las credenciales salen del archivo .env, que no está en el
/// repositorio. Si falta o está incompleto, la app arranca igual y
/// muestra el error en pantalla, en vez de quedarse en blanco.
class SupabaseConfig {
  SupabaseConfig._();

  /// Acepta los dos nombres que usa Supabase: el corto y el que trae el
  /// botón Connect del panel, con el prefijo NEXT_PUBLIC_ heredado de
  /// Next.js. Así funciona sin importar de dónde se copiaron las llaves.
  static String? _variable(List<String> nombres) {
    for (final String nombre in nombres) {
      final String? valor = dotenv.env[nombre];
      if (valor != null && valor.trim().isNotEmpty) return valor.trim();
    }
    return null;
  }

  static Future<void> inicializar() async {
    await dotenv.load(fileName: '.env');

    final String? url = _variable(<String>[
      'SUPABASE_URL',
      'NEXT_PUBLIC_SUPABASE_URL',
    ]);

    final String? clave = _variable(<String>[
      'SUPABASE_PUBLISHABLE_KEY',
      'NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY',
      'SUPABASE_ANON_KEY',
      'NEXT_PUBLIC_SUPABASE_ANON_KEY',
    ]);

    if (url == null || clave == null) {
      throw Exception(
        'El archivo .env no tiene la URL o la clave de Supabase. '
        'Claves encontradas: ${dotenv.env.keys.join(", ")}. '
        'Se esperaba SUPABASE_URL y SUPABASE_PUBLISHABLE_KEY, '
        'o sus versiones con prefijo NEXT_PUBLIC_.',
      );
    }

    // publishableKey reemplaza al antiguo anonKey, que Supabase retira
    // a finales de 2026.
    await Supabase.initialize(url: url, publishableKey: clave);
  }

  /// Punto de entrada a la base de datos desde cualquier pantalla.
  static SupabaseClient get cliente => Supabase.instance.client;
}
