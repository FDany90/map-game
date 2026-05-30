# Arquitectura técnica

> Estado: borrador v0.2 · Etapa 1-4
> Documento vivo. Las decisiones grandes se registran como ADRs en `decisions/`.
>
> **Actualizado (Etapa 4):** tras el spike, el mapa se renderiza con **flutter_map** (Dart,
> no en Flame). El ADR 0002 quedó **reemplazado por el
> [0006](decisions/0006-mapa-flutter-map-flame-combate.md)**; Flame queda **diferido y
> acotado al combate**. Las secciones de "mapa dentro de Flame" y "tile loader" de abajo
> quedan como **referencia histórica**.

## Stack elegido

| Capa | Tecnología | ADR |
|------|-----------|-----|
| App (Android + iOS) | **Flutter** | [0001](decisions/0001-stack-flutter-flame.md) |
| Render del mapa + capas | **flutter_map** + capas propias (PolygonLayer, etc.) | [0006](decisions/0006-mapa-flutter-map-flame-combate.md) |
| Motor de combate | **Flame**, diferido/opcional (solo combate) | [0001](decisions/0001-stack-flutter-flame.md) · [0006](decisions/0006-mapa-flutter-map-flame-combate.md) |
| Tipo de tiles | **Raster estilizados** (Nivel A de fidelidad) | [0004](decisions/0004-tiles-raster-estilizados.md) |
| Grilla de hexágonos | **H3** (prototipo: grilla calculada a mano) | — |
| Proveedor de tiles | **MapTiler** (raster, plan gratuito) | [0005](decisions/0005-proveedor-tiles-maptiler.md) |
| Backend / multijugador | **BaaS: Supabase o Firebase** (a confirmar) | [0003](decisions/0003-backend-baas.md) |

## Diagrama de capas (render)

```
Flutter (app, menús, HUD, tiendas, login)
  └─ GameWidget (Flame)
       Cámara (zoom / pan compartidos)
       ├─ Capa Mapa      → TileComponent (carga tiles z/x/y, Web Mercator)
       ├─ Capa Hexágonos → grilla H3 (territorio: claro / oscuro / vecino / rival)
       ├─ Capa Edificios → torretas, muros, generadores
       ├─ Capa Unidades  → monstruos y defensas (SpriteAnimationComponent)
       └─ Capa Efectos   → disparos, explosiones
Backend (BaaS): quién posee cada hexágono + qué hay construido + economía
```

## (Histórico) Mapa dentro del motor — reemplazado por ADR 0006

> ⚠️ Esta sección describe el enfoque **original** (mapa renderizado en Flame con tile loader
> propio), **reemplazado** por el [ADR 0006](decisions/0006-mapa-flutter-map-flame-combate.md):
> el mapa va con flutter_map (que ya hace tiles, nombres, zoom y caché). Se conserva como
> referencia de por qué se evaluó y descartó.

En vez de usar un SDK de mapa nativo (MapLibre/Mapbox) y dibujar el juego encima
(dos sistemas de coordenadas que hay que sincronizar), **renderizamos los tiles del mapa
como una capa más dentro de Flame**. Así el mapa, los hexágonos, los edificios y los
sprites comparten **una sola cámara y un solo sistema de coordenadas**.

- Ventaja: zoom/pan parejos para todo; el combate animado sobre el mapa "simplemente funciona".
- Modelo mental idéntico al de Unity (todo en un canvas + cámara).
- Costo: implementar un **tile loader** propio. Ver ADR 0002.

### Tile loader (cómo funciona un "slippy map")

- El mundo se parte en una pirámide de tiles por nivel de zoom (`z`). Cada nivel es una
  grilla de tiles 256×256 identificados por `z/x/y` (quadtree: al acercar, cada tile se divide en 4).
- Conversión lat/lon → píxeles con la **proyección Web Mercator** (fórmula estándar).
- Dada la posición y el zoom de la cámara → calcular qué tiles `z/x/y` hacen falta,
  pedirlos al proveedor, cachearlos y dibujarlos.
- **Simplificación para el prototipo:** arrancar con **un único nivel de zoom fijo** y
  tiles de una sola escala. La pirámide completa se agrega cuando el loop ya sea divertido.

> Aclaración de terminología:
> - **"Capas de tiles" del mapa** (estilo Google) = la *pirámide de zoom* (z0, z1, z2…). Es
>   un solo mapa a distintas escalas, no varios mapas apilados.
> - **"Capas/layers" del juego** = lo que apilamos en Flame (mapa, hexágonos, edificios,
>   unidades, efectos, HUD), manejado por prioridad de render.

## Estructura del código del prototipo (`map_spike/`)

> Refactorizado a una arquitectura por **capas (MVVM)** con el skill
> `flutter-apply-architecture-best-practices` (2026-05-30). Separa UI / lógica / datos para
> escalar hacia el backend y mantener la lógica de juego testeable sin levantar la UI.

```
lib/
├── main.dart                          # composition root: caché de tiles + DI + runApp
├── config/app_config.dart             # constantes (centro, zoom, estilo/key de MapTiler)
├── domain/models/                     # Hex, ClaimResult (modelos puros, sin UI ni red)
├── data/
│   ├── services/hex_grid_service.dart         # geometría sin estado (grilla, hex más cercano)
│   └── repositories/territory_repository.dart  # fuente única de verdad: economía (seam backend)
└── ui/features/map/
    ├── view_models/map_view_model.dart   # ChangeNotifier: estado + tick económico + zoom + claim
    └── views/
        ├── map_screen.dart               # View (FlutterMap + capas) con ListenableBuilder
        └── widgets/economy_hud.dart      # HUD extraído (widget "tonto")
```

- **Inyección de dependencias** por constructor (manual; si crece → `get_it` / `provider`).
- **`TerritoryRepository`** es la fuente única de verdad de la economía: hoy en memoria, mañana
  fachada del BaaS (Etapa 6) **sin tocar la UI ni el ViewModel**. Cubierto por
  `test/territory_repository_test.dart` (7 casos).
- **Caché de tiles** integrada en el `TileLayer` (`CachedTileProvider` + `HiveCacheStore`); ver
  el skill `flutter-caching-data`.
- El diseño de la UI se guía con el skill `mobile-game-ui-design` (mobile-first, HUD sobre mapa).
- **Dónde crece cada cosa:** el **modelo de datos** (Etapa 2) extiende `domain/models/`; la
  **economía nueva** (loot finito, drops, territorio oscuro) entra en `TerritoryRepository`.

## Combate en diferido (Modo Base)

El combate de torretas se resuelve de forma **asíncrona**: al volver a la app se calcula
el resultado del tiempo ausente. No requiere servidor de tiempo real → backend simple
(estado + funciones), más barato y más fácil de mantener para un dev en solitario.

## Pendientes de arquitectura

- Confirmar BaaS (Supabase vs Firebase) — ADR 0003.
- Definir el modelo de datos (Etapa 2): hexágono, base, edificio, recurso, unidad.
- ✅ Caché de tiles (disco, Hive vía `flutter_map_cache`) implementada. Pendiente: medir el uso
  real contra el límite Free de MapTiler (100k requests/mes).
- Modelo de sincronización del estado del territorio entre jugadores.
