---
name: flutter-caching-data
description: Local data caching and offline-first patterns for Flutter apps — pick the right store (shared_preferences, Hive/SQLite, file system), cache network images and map tiles, and build offline-first repositories. Use when adding persistence, reducing network/API requests, caching tiles or images, or making reads work offline.
metadata:
  type: local
  last_modified: 2026-05-30
---
# Caching de datos en Flutter

Guía práctica para decidir QUÉ guardar, DÓNDE, y CÓMO, minimizando requests de red y
habilitando lectura offline. Escrita para el proyecto MAP (mapa real + tiles + economía),
pero aplica a cualquier app Flutter.

## Contenido
- [Elegir la estrategia según el dato](#elegir-la-estrategia-según-el-dato)
- [Caché de tiles de mapa (flutter_map)](#caché-de-tiles-de-mapa-flutter_map)
- [Caché de imágenes de red](#caché-de-imágenes-de-red)
- [Repositorio offline-first](#repositorio-offline-first)
- [Errores comunes](#errores-comunes)
- [Checklist](#checklist)

## Elegir la estrategia según el dato

Mapeá cada dato a su naturaleza antes de elegir paquete:

| Tipo de dato | Ejemplos | Store recomendado |
|---|---|---|
| Preferencias / flags / UI state pequeño | tema, último zoom, onboarding visto | `shared_preferences` |
| Datos estructurados / colecciones consultables | inventario, hexágonos reclamados, entidades del juego | **SQLite** (`sqflite`/`drift`) o **Hive** (`hive`/`isar`) |
| Caché HTTP / imágenes / tiles | respuestas de API, sprites remotos, tiles de mapa | `cached_network_image`, `flutter_map_cache` + `dio_cache_interceptor` |
| Binarios / media grande | audio, descargas, exports | File system (`path_provider` + `dart:io`) |
| Estado de navegación entre cold starts | restaurar pantalla/scroll tras matar la app | `RestorationMixin` / `RestorationScope` |

Reglas:
- **No metas blobs grandes en `shared_preferences`** (es para escalares y strings chicos).
- **Datos que vas a consultar/filtrar** → base de datos, no JSON plano en un archivo.
- **Elegí UN store por tipo de dato** y aislalo detrás de un repositorio; no esparzas
  llamadas a `SharedPreferences.getInstance()` por toda la UI.
- Persistente vs efímero: `getApplicationDocumentsDirectory()` (sobrevive, respaldable) vs
  `getTemporaryDirectory()` (el SO lo puede limpiar — ideal para caché descartable).

## Caché de tiles de mapa (flutter_map)

Sin caché, cada pan/zoom re-descarga tiles y quema requests del proveedor (ej. MapTiler
factura por request). La caché es la palanca #1 de costo. Patrón validado en este repo:

```yaml
# pubspec.yaml
dependencies:
  flutter_map: ^7.0.2
  flutter_map_cache: ^1.5.1
  dio_cache_interceptor: ^3.5.0
  dio_cache_interceptor_hive_store: ^3.2.2   # store persistente en disco
  path_provider: ^2.1.4
```

```dart
// main.dart — crear el store ANTES de runApp
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final dir = await getTemporaryDirectory();          // caché descartable
  final tileStore = HiveCacheStore('${dir.path}/maptiler_tiles');
  runApp(MyApp(tileStore: tileStore));
}

// en el TileLayer
TileLayer(
  urlTemplate: 'https://api.maptiler.com/maps/$style/{z}/{x}/{y}.png?key=$key',
  userAgentPackageName: 'com.example.app',
  tileProvider: CachedTileProvider(
    maxStale: const Duration(days: 30),   // re-pedir recién a los 30 días
    store: tileStore,
  ),
),
```

Notas:
- `FileCacheStore` NO viene en el core de `dio_cache_interceptor`: los stores persistentes
  están en paquetes aparte (`..._hive_store`, `..._db_store`). `HiveCacheStore` abre su box
  lazy, no requiere `Hive.init`.
- Versioná `flutter_map_cache` con tu `flutter_map`: `flutter_map_cache ^1.5.x` ↔ `flutter_map ^7`;
  para `flutter_map ^8` necesitás `flutter_map_cache ^2`.
- **Verificación real:** correr la app y mirar que el box crezca en disco —
  `adb shell run-as <appId> ls -la cache/<dir>` debe mostrar un `dio_cache.hive` con tamaño > 0.
- En **widget tests no montes el `FlutterMap`**: dispara fetches de tiles (timers async vía dio)
  que quedan "pending" y rompen el test. Testeá la lógica/instanciación, o usá `MemCacheStore()`.

## Caché de imágenes de red

Para sprites/avatars remotos usá `cached_network_image` (cachea en memoria y disco con LRU):

```dart
CachedNetworkImage(
  imageUrl: url,
  placeholder: (c, _) => const SizedBox.square(dimension: 24, child: CircularProgressIndicator()),
  errorWidget: (c, _, __) => const Icon(Icons.broken_image),
)
```
Para precargar antes de mostrar: `precacheImage(CachedNetworkImageProvider(url), context)`.

## Repositorio offline-first

Patrón: la UI lee de un **stream local** (fuente de verdad = caché), y la red solo
**refresca** la caché. Así la app funciona sin conexión y la UI reacciona sola.

```
read():   emitir desde cache (rápido) → en paralelo fetch remoto → si OK, escribir en cache
                                          (el stream re-emite) → si falla, seguís con lo cacheado
write():  dual-write → escribir local con flag `synced=false` → intentar push remoto →
                       si OK marcar `synced=true`; un proceso de sync reintenta los pendientes
```

Claves:
- **Single source of truth = la caché local.** La red nunca alimenta la UI directo.
- Stream-based reads (`Stream<T>` desde Hive/drift) para que la UI se actualice al refrescar.
- Flag de sincronización por registro para reconciliar escrituras offline.
- Resolución de conflictos explícita (last-write-wins, o por versión/timestamp).

## Errores comunes
- Guardar listas/JSON grandes en `shared_preferences` → usar base de datos.
- Llamar a `getTemporaryDirectory()`/abrir el store dentro del `build()` → hacerlo una vez en
  `main()` o en un singleton/provider e inyectarlo.
- No setear `maxStale`/política de expiración → la caché nunca se refresca (o crece sin techo).
- Olvidar que `getTemporaryDirectory()` puede ser limpiado por el SO: para datos que NO se
  deben perder, usar `getApplicationDocumentsDirectory()`.
- Montar el mapa/imagen de red en widget tests sin mock → "pending timers".

## Checklist
- [ ] Clasifiqué cada dato (preferencia / estructurado / imagen-tile / binario) y elegí store.
- [ ] El store se crea una sola vez (en `main()` o provider), no en `build()`.
- [ ] Tiles e imágenes de red tienen caché con política de expiración (`maxStale`).
- [ ] Acceso a persistencia aislado detrás de un repositorio (no esparcido por la UI).
- [ ] Verifiqué que la caché escribe a disco (tamaño del box/archivo > 0).
- [ ] Los widget tests no dependen de red/timers sin mock.
