# UFIT

Aplicación móvil de gimnasio. Proyecto de **Ingeniería de Software 1** — Grupo 8, Universidad Industrial de Santander.

Permite a los usuarios registrarse, consultar el aforo del gimnasio, reservar máquinas y clases, entrar con un código QR, armar sus rutinas a partir del catálogo de ejercicios y llevar su progreso físico.

- **Stack:** Flutter (Dart) + Supabase (PostgreSQL)
- **Plataforma:** Android
- **Equipo:** David y Sergio
- **Entrega final:** 20 de noviembre de 2026

## Poner a andar el proyecto

### 1. Requisitos

Windows 10/11 de 64 bits, 8 GB de RAM y ~20 GB libres en el disco C.

| Herramienta | Versión |
|---|---|
| Flutter | 3.47.4 (stable) |
| Dart | 3.13.3 |
| Android SDK | 36.0.0 |
| Android NDK | 28.2.13676358 |
| SDK Command-line Tools | **22.0** |

Instala, en este orden: [Git for Windows](https://git-scm.com/download/win) → [Android Studio](https://developer.android.com/studio) → [VS Code](https://code.visualstudio.com) con la extensión **Flutter** → el SDK de Flutter (desde VS Code: `Ctrl+Shift+P` → *Flutter: New Project* → **Download SDK** → carpeta `C:\dev` → **Add SDK to PATH**).

> **La ruta importa.** Nada de este proyecto puede vivir en carpetas con espacios, tildes, ni dentro de OneDrive o Documentos. Todo va en `C:\dev\`.

### 2. NDK y cmdline-tools (hazlo antes de compilar)

Android Studio → **More Actions** → **SDK Manager** → pestaña **SDK Tools** → marca **Show Package Details**:

- En **NDK (Side by side)**, instala la versión `28.2.13676358`.
- En **Android SDK Command-line Tools**, desmarca la `23.0` e instala la `22.0`.

Google jubiló la herramienta `sdkmanager` en las cmdline-tools 23, pero Gradle sigue llamándola: la compilación falla con `exit value -1073740791` y un `Package ndk not found` que no explica nada. Con la 22.0 funciona ([flutter#191558](https://github.com/flutter/flutter/issues/191558)).

### 3. Licencias y verificación

```powershell
flutter doctor --android-licenses   # responde "y" a todo
flutter doctor
```

Debe quedar todo en ✓ salvo **Visual Studio**, que se ignora: solo hace falta para apps de escritorio de Windows.

### 4. Correr la app

```powershell
git clone https://github.com/<usuario>/ufit.git C:\dev\ufit
cd C:\dev\ufit
flutter pub get
flutter run
```

Con la app corriendo: `r` recarga los cambios al instante, `R` reinicia, `q` sale.

## Estructura del código

Cada carpeta tiene **un solo dueño**. Es la regla que evita conflictos de Git: nadie edita archivos de la carpeta del otro.

| Carpeta | Dueño | Requerimientos |
|---|---|---|
| `lib/core` | Ambos, solo en la sesión del sábado | Navegación, tema, modelo de datos, utilidades |
| `lib/features/cuenta` | David | RF1, RF8, RF10 |
| `lib/features/reservas` | David | RF2, RF3, RF4, RF9 |
| `lib/features/gimnasio` | Sergio | RF5, RF6, RF7 |
| `lib/features/entrenamiento` | Sergio | RF11 |
| `lib/features/admin` | Sergio | RF12, RF13 |

## Cómo se trabaja

**Ramas**

- `main` — la rama del proyecto. Siempre tiene que compilar. Nunca se commitea estando parado en ella.
- `feat/<módulo>-rf<NN>` — una rama por requerimiento, viva máximo una semana.

**Flujo de cada requerimiento**

```powershell
git switch main
git pull --rebase origin main
git switch -c feat/reservas-rf02
# ... trabajas, commiteas ...
git pull --rebase origin main   # antes de abrir el PR
git push -u origin feat/reservas-rf02
```

Luego abres el Pull Request contra `main` en GitHub. **Lo revisa y aprueba el otro**, no tú mismo. El merge lo hace GitHub, no se sube nada directo a `main`.

**Versiones**

Cada entrega se marca con una etiqueta sobre `main`: `v0.1` (cimientos), `v0.5` (MVP), `v0.9` (alcance completo), `v1.0` (entrega final). Los tags son los que permiten volver a cualquier entrega.

**Commits**

Formato `tipo(alcance): mensaje (RFn)` — por ejemplo `feat(reservas): validar cupo antes de confirmar (RF2)`.

Tipos: `feat` funcionalidad nueva · `fix` corrección · `chore` configuración o mantenimiento · `docs` documentación · `test` pruebas · `refactor` reorganización sin cambio de comportamiento.

**Issues**

Hay un issue por requerimiento en GitHub Projects. Referencia el número en el PR para que quede el rastro de quién hizo qué.

## Hitos

| Fecha | Hito |
|---|---|
| 12 sep | Stack elegido y repositorio creado |
| 19 sep | Modelo de datos congelado y esqueleto integrado |
| 26 sep | RF1 y RF5 integrados |
| 10 oct | Primer corte de integración |
| 20 oct | MVP completo (RF1–RF5, RF11) |
| 24 oct | Congelamiento de alcance |
| 31 oct | Congelamiento de funcionalidad |
| 10 nov | Pruebas terminadas |
| 18 nov | Tag `v1.0` |
