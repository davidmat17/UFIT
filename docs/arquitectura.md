# Arquitectura: cohesión y acoplamiento

Cómo está organizado el código de UFIT y por qué. Complementa el [diagrama de componentes](diagrama-componentes.md), que muestra las piezas, y el [modelo de datos](modelo-de-datos.md), que describe la información.

Estado al 22 de septiembre de 2026.

---

## Resumen

| Criterio | Cómo se cumple | Cómo se comprueba |
|---|---|---|
| Alta cohesión | Cada módulo agrupa un área del negocio completa, con sus pantallas y su acceso a datos | `lib/features/` tiene cinco carpetas, una por área, y ninguna carpeta "varios" |
| Bajo acoplamiento entre módulos | Ningún módulo importa a otro; se comunican a través de la base de datos | `flutter test test/arquitectura_test.dart` |
| Bajo acoplamiento con el backend | Las pantallas dependen de puertos abstractos, no del SDK de Supabase | La misma prueba, segundo caso |
| Dependencias en un solo sentido | El núcleo no conoce los módulos; los módulos conocen el núcleo | La misma prueba, tercer caso |

La última columna es lo importante: **estas no son afirmaciones, son pruebas que se ejecutan.** Si alguien rompe una regla, la construcción falla.

---

## Estructura

```
lib/
├── main.dart                    ← punto de composición
├── core/                        ← lo compartido
│   ├── datos/
│   │   ├── errores.dart         ← errores en vocabulario del proyecto
│   │   ├── repositorios.dart    ← registro de puertos
│   │   └── puertos/             ← las cinco interfaces abstractas
│   ├── modelos/                 ← entidades del dominio
│   ├── supabase/                ← cliente y traducción de errores
│   ├── tema/
│   └── rutas.dart
├── features/                    ← los cinco módulos
│   └── <módulo>/
│       ├── datos/               ← adaptador: implementa el puerto
│       └── pantallas/           ← interfaz de usuario
└── desarrollo/                  ← andamio temporal
```

---

## Cohesión

**Cohesión alta significa que lo que está junto tiene razón de estar junto.**

Los módulos se dividieron por área del negocio, no por tipo de archivo. El módulo de reservas contiene el calendario, la creación de la reserva, la cancelación, el lector de QR y el historial: todo lo que una persona hace alrededor de reservar un cupo. Alguien que tenga que cambiar cómo funcionan las reservas trabaja en una sola carpeta.

La alternativa —agrupar por tipo: todas las pantallas juntas, todos los modelos juntos— produce baja cohesión: un cambio de una funcionalidad obliga a tocar cuatro carpetas distintas, y cada carpeta mezcla cosas que no tienen nada que ver entre sí.

**La señal de que se mantuvo:** no existe ninguna carpeta `utilidades`, `comunes` o `varios` dentro de los módulos. Ese tipo de carpeta es donde va a parar lo que no se supo dónde poner, y es el síntoma clásico de cohesión baja.

**Dónde la cohesión es más floja, dicho honestamente:** `lib/core` agrupa cosas que comparten el ser compartidas, no el tratar del mismo tema — el tema visual y la traducción de errores de red no tienen relación entre sí. Es un compromiso aceptado: la alternativa sería multiplicar paquetes pequeños, que en un proyecto de dos personas y once semanas cuesta más de lo que aporta.

---

## Acoplamiento

Son dos fronteras distintas y conviene no confundirlas.

### Frontera 1: entre módulos

**Ningún módulo importa a otro.** Se puede reescribir `features/reservas` entero sin que `features/gimnasio` se entere, porque no hay una sola línea que los conecte.

Cuando un módulo necesita información que produce otro, la pide a la base de datos, no al módulo vecino. El panel de estadísticas (RF12) lee las tablas `reservas` y `asistencias`; no llama a ninguna función del módulo de reservas.

Eso tiene una consecuencia organizativa directa: David y Sergio pueden trabajar al mismo tiempo sin bloquearse, y los conflictos de Git se vuelven casi imposibles, porque cada quien edita archivos que el otro no toca.

### Frontera 2: entre las pantallas y el backend

Aquí es donde estaba la deuda, y es lo que se corrigió.

**Antes:** las pantallas llamaban directamente a `SupabaseConfig.cliente.from('vista_disponibilidad').select(...)`. Una pantalla sabía que existía Supabase, cómo se llamaba la vista y qué forma tenía la consulta. Tres cosas que no le incumben.

**Ahora:** el núcleo define cinco **puertos** —clases abstractas que declaran qué necesita cada módulo—, y cada módulo tiene su **adaptador**, el único archivo que conoce Supabase.

```dart
// lib/core/datos/puertos/repositorio_gimnasio.dart
abstract class RepositorioGimnasio {
  Future<List<Zona>> zonas();
  Future<List<Maquina>> maquinas({int? zonaId});
  Future<String?> normativaVigente();
}
```

La pantalla escribe `Repositorios.gimnasio.zonas()` y no sabe nada más.

Esto es el patrón de **puertos y adaptadores**: el interior de la aplicación define lo que necesita, y las piezas de infraestructura se adaptan a ello, no al revés.

### Quién conecta las dos mitades

Si el núcleo no conoce los módulos y los módulos no se conocen entre sí, alguien tiene que decidir qué implementación llena cada puerto. Ese es `main.dart`, el **punto de composición**:

```dart
Repositorios.registrar(
  perfiles: const RepositorioPerfilesSupabase(),
  gimnasio: const RepositorioGimnasioSupabase(),
  ...
);
```

Es el único archivo autorizado a conocer el núcleo, los cinco módulos y Supabase al mismo tiempo. Concentrar ahí ese conocimiento es lo que permite que todo lo demás esté desacoplado.

El arranque sigue la misma idea. La compuerta de sesión del RF1 (`CompuertaDeSesion`) decide si se ve el ingreso, el registro o la app, pero no sabe qué es "la app": la recibe de `main.dart` como parámetro.

```dart
home: CompuertaDeSesion(inicio: (_) => const PantallaInicio()),
```

Así el módulo de cuenta controla el acceso sin importar ningún otro módulo. Cuando exista la pantalla principal real, se cambia esa línea y nada más.

---

## Qué compra esto, en concreto

**Cambiar de backend no toca ninguna pantalla.** Si mañana se reemplaza Supabase, se reescriben cinco adaptadores. Las trece pantallas quedan intactas.

**Las pantallas se pueden probar sin base de datos.** Se le entrega a la pantalla un repositorio falso que devuelve lo que uno quiera, incluido un error de red, y se comprueba que reaccione bien. Está demostrado en `test/widget_test.dart`: tres pruebas que corren sin internet.

```dart
class _GimnasioFalso implements RepositorioGimnasio {
  @override
  Future<List<Zona>> zonas() async => <Zona>[ /* datos inventados */ ];
}
```

Esa es la diferencia entre tener pruebas y decir que se tienen. Sin la frontera, probar la pantalla de disponibilidad exigiría conexión, una base real y datos preparados a mano.

**Los errores se muestran en español y sin jerga.** El adaptador traduce cualquier excepción del SDK a un `ErrorDeDatos` con un mensaje para la persona. Ninguna pantalla ve nunca un `PostgrestException`.

---

## Lo que esto NO resuelve


**Si cambia el modelo de datos compartido, se afectan todos los módulos que lean esa tabla.** Contra eso no hay patrón que proteja: lo que protege es el congelamiento del modelo que el equipo acordó, y el acuerdo de que modificarlo exige Pull Request revisado por los dos.

**Las entidades del dominio viven en el núcleo y las comparten los cinco módulos.** Es un acoplamiento aceptado a propósito: son el reflejo del modelo de datos, que ya es común. Separarlas por módulo obligaría a duplicar y traducir.

**El andamio de desarrollo sí conoce todos los módulos.** `lib/desarrollo/catalogo_requerimientos.dart` importa las trece pantallas para armar el menú de desarrollo. Está aislado en su propia carpeta y exento de las pruebas de arquitectura, y desaparece cuando exista la pantalla principal. Desde el RF1 ya solo se llega a él después de iniciar sesión. Está documentado aquí precisamente para que no pase por una violación involuntaria.

---

## Las pruebas de arquitectura

En `test/arquitectura_test.dart`. Se ejecutan con el resto:

```powershell
flutter test
```

Comprueban cuatro reglas:

1. **Ningún módulo importa a otro.** Recorre los archivos de `lib/features` y falla si uno menciona el nombre de otro módulo en un import.
2. **Las pantallas no conocen Supabase.** Falla si cualquier archivo bajo `pantallas/` importa el SDK.
3. **El núcleo no depende de los módulos.** Falla si algo en `lib/core` importa `features/` o `desarrollo/`.
4. **Cada módulo tiene su adaptador.** Falla si un módulo se queda sin carpeta `datos/`.

Cuando una falla, el mensaje dice qué archivo, qué import y qué hacer en su lugar. La respuesta correcta nunca es cambiar la prueba.

---

## Trabajar un requerimiento con esta estructura

El orden para cualquier RF:

1. **Revisar el puerto** del módulo en `lib/core/datos/puertos/`. Si falta un método, agregarlo ahí primero.
2. **Implementarlo en el adaptador**, en `lib/features/<módulo>/datos/`. Es el único sitio donde se escribe una consulta.
3. **Escribir la pantalla** en `pantallas/`, que llama a `Repositorios.<módulo>`.
4. **Probar la pantalla** con un repositorio falso, sin base de datos.
5. `flutter test` antes de abrir el Pull Request.

Los adaptadores que todavía no están implementados lanzan `UnimplementedError` con el requerimiento y el responsable en el mensaje, así que se sabe exactamente qué falta y de quién es.
