# Costo: zombies caminando por las calles (OSM)

> Estado: investigación + decisión · 2026-05-30
> Documento vivo. Captura el análisis de costo del pendiente "zombies por las calles" y la
> decisión de alcance, para no re-investigar y para futuros análisis si cambia el alcance.

## Decisión de alcance (lo más importante)
**Es valor VISUAL, no posición exacta.** El objetivo es que el **farmeo se vea**: en vez de
un número que incrementa, el jugador ve **zombies que spawnean, caminan por la calle, y la base
los mata a tiros** (y eso sube los recursos). No hace falta navegación realista punto-a-punto.

➡️ **Consecuencia: NO se necesita grafo de calles + pathfinding (A\*/flow-field).** Eso era para
movimiento exacto; acá es representación. Esto **baja el costo drásticamente**.

## Recomendación: enfoque "carriles de calle" (street-lanes)
Para que un zombie "camine por la calle" hacia la base alcanza con la **geometría de las calles
cercanas** como líneas, y caminar **a lo largo de la polyline** — sin algoritmo de pathfinding.

**MVP:**
1. **Una** consulta Overpass al colocar/cargar la base → calles (`highway=*`) en un radio chico,
   **cacheadas** en disco (Hive). Cero llamadas por frame.
2. Spawn de zombies en los **extremos** de esas calles (borde del radio de spawn).
3. Movimiento **interpolando a lo largo de la polyline** hacia la base (lerp). En intersecciones,
   elegir greedy el tramo que acerca a la base. Aproximado = suficiente (es visual).
4. **Torreta/base con rango** → al entrar el zombie, dispara (sprite de proyectil), el zombie
   muere y **dispara la recompensa** (hook a `TerritoryRepository`).

- **Costo monetario:** ~$0 (datos OSM gratis vía Overpass, una vez + caché).
- **Esfuerzo:** bajo-medio. **Runtime:** bajo (decenas de zombies + proyectiles).
- **Dónde vive:** **Flame** (esto *es* combate → ADR 0006). Primer paso barato posible con
  `MarkerLayer` de flutter_map para validar el visual con 2-3 zombies antes de meter Flame.

## Las 3 piezas del problema (referencia)
1. **Geometría/grafo de calles** del área jugable.
2. **Movimiento** (caminar por las calles).
3. **Render + escala** (varios zombies animados + disparos sin matar FPS).

### 1) Datos de calles — gratis
| Fuente | Costo | Notas |
|---|---|---|
| **Overpass API** | gratis | Fair-use (load-shedding; límites ~180 s / 512 MB por query). **No** para llamadas por frame → fetch **una vez** por área y **cachear**. Self-hosteable si escala. |
| **Extracto Geofabrik** (`.osm.pbf`) | gratis | Descargar región y procesar offline; bundlear/servir desde backend. |
| **Backend propio** (Etapa 6) | infra | Servir el grafo/geometría ya procesado por área. |

Un barrio (pocos km²) = miles de nodos/tramos → entra en memoria sin problema.
⚠️ Los tiles **raster** de MapTiler **no traen geometría** de calles → para saber *dónde* están
las calles hace falta **vector** (Overpass / extracto), no los tiles.

### 2) Movimiento — local, NO API de routing
Para muchos agentes pathando seguido, las APIs de routing se descartan (rate-limit/costo/latencia):
| Opción | Límite / precio (verificado may-2026) | Veredicto |
|---|---|---|
| **OpenRouteService** | Free = **2.000 requests/día** | No para hordas; sí routing puntual. |
| **Mapbox Directions** | 100k/mes gratis, luego **$2/1k** (100k–500k), $1.60/1k (500k–1M) | Una ruta por zombie/repath = inviable. |
| **OSRM / GraphHopper / Valhalla** (self-host, open source) | $0 licencia, pero mantenés server (GBs RAM) | Overkill para IA de juego. |
| **A\* / flow-field local en Dart** | $0 | La opción real **si** alguna vez se quiere movimiento exacto. |

**Dart/Flutter:** no hay A\* on-device "llave en mano"; los packages (`flutter_osm_plugin`,
`OSM-Routing-Client-Dart`) **envuelven OSRM por REST**. Un A\*/Dijkstra propio es simple (~150
líneas, en `Isolate`) — pero **para el alcance actual (visual) ni eso hace falta**.

### 3) Render + escala
- **Flame** es el hogar correcto para sprites animados + proyectiles (ADR 0006: Flame para combate).
- flutter_map (`MarkerLayer`/capa propia) sirve para un primer paso con pocos zombies.
- Coordenadas: los zombies viven en lat/lng; hay que **compartir la proyección** entre
  flutter_map y Flame (integración que ADR 0006 dejó pendiente para el combate).

## Escalera de costo (de barato a caro) — por si cambia el alcance
| Nivel | Qué es | $ | Esfuerzo | Runtime | ¿Aplica hoy? |
|---|---|---|---|---|---|
| **L0 Carriles de calle** ⭐ | Caminar por polylines de calles cacheadas hacia la base; sin pathfinding | $0 | bajo-medio | bajo | **Sí (recomendado)** |
| L1 Flow-field | Dijkstra una vez desde el objetivo → campo de flujo; cientos de agentes | $0 | medio | bajo | Solo si se quiere movimiento "real" barato |
| L2 A\* por agente | Ruta individual real por zombie (Isolate + cache) | $0 | medio-alto | medio | Solo si hace falta precisión por agente |
| L3 Routing API | Geometría de calle precisa (OSRM/ORS/Mapbox) | $0–$$ | bajo | red/latencia | Solo routing **del jugador** (Exploración) |

## Alineación con el diseño
- El **combate es diferido/automático en Modo Base** (ADR 0001): el farmeo "real" se resuelve en
  números; esta feature es la **representación visual** de ese cálculo. No mueve la simulación.
- En **Modo Exploración** (GPS en vivo) ver zombies venir por tu calle suma más; ahí podría
  justificarse subir de nivel en la escalera. Para Base, **L0 alcanza**.

## Implementación del spike (arquitectura)
Reorganizado siguiendo `flutter-apply-architecture-best-practices`:
- **`OverpassService`** (data/services): "puro", solo habla con la API (endpoint principal +
  mirror `kumi.systems`); **lanza** `OverpassException` si todo falla. Requiere **User-Agent**
  (sin él Overpass da **406**).
- **`StreetsRepository`** (data/repositories): **fuente única de verdad** de las calles, con la
  resiliencia: **caché en disco** (JSON en documents, persistente, una bajada por área →
  funciona offline + respeta fair-use) → **Overpass** → **fallback** sintético. El origen se
  expone como `StreetsSource { overpass, cache, fallback }` (visible en el HUD).
- **`ZombieSpikeViewModel`** depende del **repositorio** (no del service); modelo `Zombie` en
  domain; la View solo renderiza.

## Próximo paso sugerido
**Mini-spike L0:** Overpass para traer las calles de un radio chico en Palermo (cacheado) →
spawnear 2-3 zombies en los extremos → caminarlos por la polyline hacia la base (lerp) →
torreta con rango que dispara y los mata → medir el costo de runtime real en el emulador.
Primero con `MarkerLayer`; pasar a Flame al subir el conteo/animación.

## Fuentes
- [Overpass API — OSM Wiki](https://wiki.openstreetmap.org/wiki/Overpass_API) ·
  [Commons / límites](https://dev.overpass-api.de/overpass-doc/en/preface/commons.html)
- [OpenRouteService — API Restrictions](https://openrouteservice.org/restrictions/)
- [Mapbox Pricing](https://www.mapbox.com/pricing) ·
  [Pricing by product](https://docs.mapbox.com/accounts/guides/pricing/)
- [GraphHopper open source](https://www.graphhopper.com/open-source/) ·
  [GraphHopper (GitHub)](https://github.com/graphhopper/graphhopper)
- [OSM-Routing-Client-Dart](https://github.com/liodali/OSM-Routing-Client-Dart) ·
  [flutter_osm_plugin](https://pub.dev/packages/flutter_osm_plugin)
