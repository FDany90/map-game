# Building extrusion (edificios 3D) — análisis y recomendación

> Estado: análisis + recomendación preliminar · 2026-05-30
> Documento vivo. Si se confirma la vía recomendada, registrar como **ADR 0007**.
> Relacionado: [ADR 0004 (tiles raster)](decisions/0004-tiles-raster-estilizados.md) ·
> [ADR 0006 (flutter_map, no SDK GL)](decisions/0006-mapa-flutter-map-flame-combate.md) ·
> [07-map-art-direction.md](07-map-art-direction.md)

## Pregunta
¿Se puede configurar el mapa para que los **edificios** vengan con **extrusión 3D** en vez de
polígonos planos?

## Respuesta corta
**Con el stack actual, no.** MAP usa **tiles RASTER** de MapTiler (ADR 0004): cada tile es un
**PNG plano** donde los edificios ya vienen "horneados" como píxeles. **No son geometría → no hay
nada que extruir.** Lo que parece un "polígono" es solo el dibujo dentro de la imagen.

## Qué hace falta para extrusión 3D "de verdad"
1. **Vector tiles** (MapTiler vector / MVT) en vez de raster → ahí los edificios sí son geometría
   con atributo de altura (`render_height` / `building:levels`).
2. Un **renderer GL** con `fill-extrusion` + **pitch** de cámara: **MapLibre GL** (`maplibre_gl`)
   o el SDK de Mapbox.

⚠️ **El costo oculto:** eso implica **volver a un SDK de mapa nativo (GL)** — justo lo que el
**ADR 0006 descartó**. Elegimos flutter_map para **renderizar el juego nosotros** con
cámara/coordenadas compartidas. Con un SDK GL:
- Meter hexágonos / zombies / sprites encima y compartir la proyección se vuelve más difícil
  (usás las APIs de annotations/layers del SDK, con menos control).
- Cambia el **modelo de costos** (vector tiles ≠ raster en la facturación de MapTiler).
- Más **GPU/batería** (render 3D en vivo).
- Flame para combate (ADR 0006) conviviría peor con un canvas GL del mapa.

## Opciones
| Opción | 3D real | Mantiene stack (ADR 0006) | Esfuerzo | Control de estilo | Costo runtime |
|---|---|---|---|---|---|
| **A. Raster actual (plano)** | ❌ | ✅ | – | medio (estilo MapTiler) | bajo |
| **B. MapLibre GL + vector + `fill-extrusion`** | ✅ | ❌ (revierte 0006) | alto | bajo (estilo del SDK) | alto |
| **C. Footprints OSM + extrusión propia en Flame** ⭐ | ✅ (fake/estilizado) | ✅ | medio | **total** | medio |

## Recomendación: Opción C (extrusión propia, estilizada)
Como el juego es **estilizado** ("sprites sobre la grilla", look apocalíptico — doc 07), lo más
coherente es **fakear la extrusión** nosotros, con la **misma técnica que las calles** del spike
de zombies:

1. Traer **footprints de edificios** con **Overpass** (`way["building"](around:R,lat,lon); out geom;`)
   — una vez por área, **cacheado** (igual que `building=*` ≈ misma query que `highway`).
   Recordar el **User-Agent** (sin él Overpass da 406; ver `OverpassService`).
2. Renderizar cada footprint como **polígono extruido / isométrico** en **Flame**: el polígono de
   base + una "pared" con offset vertical (y opcional sombra) para fingir volumen. La altura sale
   de `building:levels` (o un valor fijo estilizado si no está).
3. **Estilo propio**: paredes oscuras, bordes neón/tenebrosos, edificios "tomados" (territorio
   oscuro) vs limpios — se integra con la dirección de arte y con los estados de hexágono.

**Ventajas:** mantenés el stack (flutter_map + Flame), **control total** del look, se integra con
los sprites/combate, y **costo monetario ~$0** (datos OSM gratis vía Overpass + caché). El costo
es de implementación + algo de runtime (drawing de polígonos en Flame, que es barato a escala de
un barrio).

**Limitación honesta:** no es 3D "navegable" con pitch libre como MapLibre; es **representación
estilizada** (isométrica / extrusión leve). Para MAP eso es **una ventaja** (estética propia), no
una falta — pero si el objetivo fuera un 3D fotorrealista navegable, ahí sí habría que ir a la
Opción B y reabrir el ADR 0006.

## Cuándo reconsiderar la Opción B (MapLibre GL)
- Si el diseño pide **cámara 3D con pitch/rotación** y edificios fotorrealistas como núcleo de la
  experiencia (no es el caso hoy: el mapa es **escenario**, no protagonista).
- Si se acepta el costo de reescribir el overlay del juego sobre las APIs del SDK.

## Costos de datos (referencia)
- **Overpass `building=*`**: gratis, fair-use → **una consulta por área, cacheada** (no por frame).
  Un barrio puede tener cientos de footprints → ok en memoria; filtrar por zona visible.
- **Vector tiles de MapTiler** (solo si se fuera a Opción B): facturación distinta a raster;
  revisar el plan antes de migrar.

## Próximo paso sugerido (si se quiere validar el look)
**Mini-spike de extrusión:** traer `building=*` de un radio chico en Palermo (cacheado) y dibujar
2-3 edificios extruidos/isométricos a mano (Flame o incluso un `CustomPainter` sobre flutter_map
para un primer vistazo) para evaluar la estética antes de comprometerse. Reutiliza el
`OverpassService` ya hecho.

## Decisión
**Preliminar:** Opción **C** (extrusión propia estilizada con footprints OSM). Se mantiene el
stack y la dirección de arte. Si se confirma tras el mini-spike visual, promover a **ADR 0007**.
