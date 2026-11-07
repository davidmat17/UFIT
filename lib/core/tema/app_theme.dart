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

  /// Verde del storyboard de la Entrega 2B, sobre fondo azul noche. Es el
  /// del tema oscuro, que es el que usa la app.
  static const Color verdeStoryboard = Color(0xFF5BB534);

  static ThemeData get claro => _construir(Brightness.light);
  static ThemeData get oscuro => _construir(Brightness.dark);

  static ThemeData _construir(Brightness brillo) {
    final ColorScheme esquema = brillo == Brightness.dark
        ? _esquemaOscuro()
        : ColorScheme.fromSeed(seedColor: verdeUfit, brightness: brillo);

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
        color: brillo == Brightness.dark
            ? esquema.surfaceContainerLow
            : esquema.surface,
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

  /// El tema oscuro del storyboard: fondo azul noche, tarjetas un poco más
  /// claras con borde fino y el verde con toda su saturación (la variante
  /// "fidelity" respeta el color de partida en vez de suavizarlo).
  static ColorScheme _esquemaOscuro() => ColorScheme.fromSeed(
        seedColor: verdeStoryboard,
        brightness: Brightness.dark,
        dynamicSchemeVariant: DynamicSchemeVariant.fidelity,
      ).copyWith(
        surface: const Color(0xFF0E1621),
        onSurface: const Color(0xFFE8EEF5),
        onSurfaceVariant: const Color(0xFF9DAABB),
        surfaceContainerLowest: const Color(0xFF0A111A),
        surfaceContainerLow: const Color(0xFF141E2B),
        surfaceContainer: const Color(0xFF182332),
        surfaceContainerHigh: const Color(0xFF1D2939),
        surfaceContainerHighest: const Color(0xFF243246),
        outlineVariant: const Color(0xFF26354A),
      );
}
