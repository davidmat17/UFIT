import 'package:flutter/material.dart';

/// Tema visual de UFIT.
///
/// Un solo lugar para colores, formas y tipografia: ninguna pantalla
/// define colores a mano. Si hay que cambiar la identidad visual de la
/// app, se cambia aqui y se propaga a todo.
class AppTheme {
  AppTheme._();

  /// Verde institucional del proyecto, el mismo de la presentacion.
  static const Color verdeUfit = Color(0xFF266E60);

  static ThemeData get claro => _construir(Brightness.light);
  static ThemeData get oscuro => _construir(Brightness.dark);

  static ThemeData _construir(Brightness brillo) {
    final ColorScheme esquema = ColorScheme.fromSeed(
      seedColor: verdeUfit,
      brightness: brillo,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: esquema,
      scaffoldBackgroundColor: esquema.surface,
      appBarTheme: AppBarTheme(
        backgroundColor: esquema.surface,
        foregroundColor: esquema.onSurface,
        elevation: 0,
        centerTitle: false,
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: esquema.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: esquema.outlineVariant),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size.fromHeight(48),
        ),
      ),
    );
  }
}
