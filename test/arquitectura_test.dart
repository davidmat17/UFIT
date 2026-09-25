import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Pruebas de arquitectura.
///
/// No comprueban qué hace la app, sino cómo está construida. Convierten
/// las reglas de acoplamiento en algo que el compilador de pruebas
/// verifica en cada ejecución, en vez de un acuerdo que se olvida.
///
/// Si una de estas falla, el arreglo no es cambiar la prueba: es mover
/// el import al sitio que corresponde.
void main() {
  const List<String> modulos = <String>[
    'cuenta',
    'reservas',
    'gimnasio',
    'entrenamiento',
    'admin',
  ];

  /// lib/main.dart es el punto de composición y puede verlo todo.
  /// lib/desarrollo/ es el andamio del menú de desarrollo y desaparece
  /// cuando el RF1 tome el arranque de la app.
  const List<String> exentos = <String>['lib/main.dart', 'lib/desarrollo/'];

  String ruta(File f) => f.path.replaceAll(r'\', '/');

  bool estaExento(String p) => exentos.any((String e) => p.contains(e));

  List<File> archivosDart(String carpeta) => Directory(carpeta)
      .listSync(recursive: true)
      .whereType<File>()
      .where((File f) => f.path.endsWith('.dart'))
      .toList();

  List<String> importesDe(File f) => f
      .readAsLinesSync()
      .map((String l) => l.trim())
      .where((String l) => l.startsWith('import '))
      .toList();

  test('ningún módulo importa a otro módulo', () {
    final List<String> infracciones = <String>[];

    for (final File archivo in archivosDart('lib/features')) {
      final String p = ruta(archivo);
      final String propio =
          modulos.firstWhere((String m) => p.contains('/features/$m/'));

      for (final String linea in importesDe(archivo)) {
        for (final String otro in modulos.where((String m) => m != propio)) {
          if (linea.contains('/$otro/')) {
            infracciones.add('$p importa el módulo $otro:\n    $linea');
          }
        }
      }
    }

    expect(
      infracciones,
      isEmpty,
      reason: 'Los módulos deben ser independientes entre sí. '
          'Si uno necesita datos de otro, los pide a la base de datos '
          'a través de su propio repositorio.\n${infracciones.join('\n')}',
    );
  });

  test('las pantallas no conocen Supabase', () {
    final List<String> infracciones = <String>[];

    for (final File archivo in archivosDart('lib/features')) {
      final String p = ruta(archivo);
      if (!p.contains('/pantallas/')) continue;

      for (final String linea in importesDe(archivo)) {
        if (linea.toLowerCase().contains('supabase')) {
          infracciones.add('$p importa Supabase:\n    $linea');
        }
      }
    }

    expect(
      infracciones,
      isEmpty,
      reason: 'Una pantalla habla con su repositorio, nunca con la base. '
          'Mueve la consulta al adaptador del módulo '
          '(features/<módulo>/datos/).\n${infracciones.join('\n')}',
    );
  });

  test('el núcleo no depende de los módulos', () {
    final List<String> infracciones = <String>[];

    for (final File archivo in archivosDart('lib/core')) {
      final String p = ruta(archivo);
      if (estaExento(p)) continue;

      for (final String linea in importesDe(archivo)) {
        if (linea.contains('features/') || linea.contains('desarrollo/')) {
          infracciones.add('$p depende de un módulo:\n    $linea');
        }
      }
    }

    expect(
      infracciones,
      isEmpty,
      reason: 'Lo compartido no puede conocer lo específico. '
          'Si el núcleo necesita algo de un módulo, define un puerto '
          'y deja que main.dart lo conecte.\n${infracciones.join('\n')}',
    );
  });

  test('cada módulo implementa el puerto de su propio repositorio', () {
    for (final String modulo in modulos) {
      final Directory datos = Directory('lib/features/$modulo/datos');

      expect(
        datos.existsSync(),
        isTrue,
        reason: 'El módulo $modulo no tiene carpeta datos/ con su adaptador.',
      );

      final List<File> adaptadores = archivosDart(datos.path);
      expect(
        adaptadores,
        isNotEmpty,
        reason: 'El módulo $modulo no tiene ningún adaptador en datos/.',
      );
    }
  });
}
