# 18 — Escena de combate por *descriptor + templates orientados* (Nivel 2)

> 2026-05-31 · Reemplaza el enfoque de **colocar edificios desde geometría real**
> (Fase 2, `_inferBuildings`) por **templates hechos a mano** que se eligen y
> orientan con datos OSM. Decisión en [ADR 0007](decisions/0007-estrategia-visual-mapa-iconos-escenas-isometricas.md)
> (Revisión 2 / 2026-05-31). Relacionado: [14-osm-datos-referencia.md](14-osm-datos-referencia.md),
> [17-inferencia-morfologia-urbana.md](17-inferencia-morfologia-urbana.md).
>
> **Render (ADR 0007 Rev 3):** los templates se dibujan en **isométrico 2.5D — vista ¾ con la
> calle vertical** (no top-down). Los sprites finales se **pre-renderizan** de kits 3D CC0
> (Kenney/Quaternius) a PNG 2D a un ángulo ¾ fijo; el juego sigue en **Flame 2D** (el 3D es
> solo producción de assets, offline). El preview valida el layout con **cajas placeholder iso**.

## Por qué este cambio

Reproducir geometría real **fielmente** (footprints, polilíneas exactas) hace que
**cada esquina del planeta sea un caso borde nuevo** → bugs difíciles de encontrar
(edificios desalineados, calle inclinada, norte invertido — todos vistos al renderizar
la Fase 2). Además es innecesario: **la fidelidad al mapa real ya vive en la capa mapa**
(flutter_map, tiles reales). La escena de combate es un **zoom táctico estilizado**; el
jugador acepta que sea representativa.

**La vara de "se siente mi lugar"** (definida por el usuario) es modesta y alcanzable
sin geometría exacta:
- ver el **nombre de su calle**,
- que haya **casas o edificios** acordes a la zona,
- **1 ó 2 sentidos**,
- **variedad/aleatoriedad** en los sprites (casas, edificios, autos),
- y **POIs reconocibles con su nombre real** cerca (Coto, Farmacity, la escuela…).

→ Todo eso se logra con **clasificar + temazar + orientar**, sin una sola coordenada
de edificio. Se elimina la clase entera de bugs de geometría.

## Qué se conserva del trabajo previo
- **`ZoneProfile.fromScene`** (zona inferida) — corazón del descriptor.
- **Norte real + bearing** de la calle principal (para *orientar* el template).
- **Siembra determinista por posición** (`hexId` / lat-lon) — tu lugar siempre igual.
- **Inspector OSM + `OverpassService` + `OsmSceneRepository`** (la materia prima).

## Qué se jubila
- `CombatSceneLayout._inferBuildings` colocando edificios desde geometría real /
  caminando polilíneas. El `CombatScenePainter` queda como preview hasta tener templates.

---

## `SceneDescriptor` (lo que se extrae de OSM)

Objeto chico, **robusto** (todo es clasificación/conteo, no placement):

### Zona y topología
- `zoneType` — de `ZoneProfile`: `denseUrban` / `residential` / `roadCorridor` (avenida/ruta)
  / `openGreen` / `rural` / `unknown`.
- `topology` — **detectada por conteo de cruces** (ver abajo): `midBlock` (una sola calle)
  / `corner` (esquina o T, 3 ramas) / `intersection` (cruce, 4+ ramas) / `deadEnd`.

### Calle principal → **temática, no geometría** (tags que ya conservamos)
| Tag OSM | Uso en la escena |
|---|---|
| `name` ("Virrey Avilés") | **Cartel de calle** visible en la escena |
| `highway` (residential/primary/…) | Clase de calle → template + ancho base |
| `maxspeed` (40) | Ancho de calzada + marcas de carril |
| `lanes` | Nº de carriles → ancho |
| `oneway` (yes/no) | **Flechas de 1 ó 2 sentidos** |
| `surface` (sett/asphalt/…) | **Textura** del piso (adoquín vs asfalto) |
| `lit` (yes) | Faroles encendidos |
| `sidewalk` (both/left/right) | Veredas a los lados |
| `lane_markings` | Líneas pintadas |

### Orientación
- `realNorth` (rad) + `mainBearing` — para rotar el template y dibujar la brújula.
  La calle principal se lleva a **vertical** (ADR 0007 rev), con `rot` normalizado a
  (−π/2, π/2] (norte nunca invertido) y usando el **tramo más cercano al jugador** para
  el ángulo (calle recta donde uno está parado).

### Landmarks (POIs reales cercanos) → **lo que más "se siente mi lugar"**
Lista de `{ kind, name, levels }` extraída de `shop=*`, `amenity=*`, `building=retail/commercial`:
- `kind` ∈ `supermarket` · `pharmacy` · `school` · `bank` · `restaurant`/`bar`/`cafe`
  · `fuel` (estación) · `kiosk` · `hospital`/`clinic` · `place_of_worship` · `police` · `generic`.
- `name` real ("Coto", "Instituto Bet-el") → **cartel** sobre el sprite.
- `levels` de `building:levels` para la altura.

Cada landmark va a un **slot destacado** del template (preferentemente la **esquina**).
El resto de slots = casas/edificios genéricos con **variedad determinista**.

---

## Detección de topología (solo contar, robusto)

1. De las calles del radio, calcular los **puntos de cruce** = donde dos calles
   *distintas* pasan a < ~4 m una de otra (vértices casi coincidentes o segmentos que
   se cruzan).
2. Tomar el cruce **más cercano al punto tocado** y medir su distancia.
3. Clasificar:

| Topología | Regla | Template |
|---|---|---|
| **`midBlock`** (una sola calle) | sin cruce a < ~30 m | Corredor recto, casas a ambos lados |
| **`corner`** (esquina / T) | cruce cercano con **3** ramas | Calle + transversal por un lado; **slot de esquina** para el POI |
| **`intersection`** | cruce cercano con **4+** ramas | Cruz (4 esquinas) |
| **`deadEnd`** | la calle termina (nodo extremo) a < ~15 m, sin cruce | Calle sin salida |

Los **ángulos** entre ramas distinguen esquina en L (~90°) de cruce recto.

---

## Biblioteca de templates

Layouts **hechos a mano** (datos en código o JSON), uno por combinación relevante de
`(zoneType × topology)`. Cada template = lista de **slots**:
- tipo de slot: `buildingRow` / `cornerLandmark` / `sidewalk` / `crossing` / `spawnPlayer` /
  `spawnEnemy` / `prop` (autos, contenedores…).
- posición **relativa** (normalizada al ancho/alto de la escena), no absoluta.

El template se **orienta al norte real** y se **escala** al radio. Los slots de tipo
edificio se llenan con sprites elegidos por **siembra determinista** (variedad estable);
los `cornerLandmark` se llenan primero con los **POIs reales** (con nombre); si sobran,
genéricos.

**Coordenadas de slot (street-space):** posición/tamaño **normalizados a la calle**, no a la
pantalla — `u` = a lo ancho de la calle (−1 izq … +1 der, 0 = eje), `v` = a lo largo (0 cerca/
abajo … 1 lejos/arriba), más `levels` (altura de extrusión). El render iso ¾ proyecta `(u,v,z)`
a pantalla; así el mismo template sirve para cualquier inclinación/escala sin reescribir slots.

Conjunto inicial sugerido (pocos, bien tuneados):
1. `residential · midBlock` — casas bajas, calle 2 sentidos.
2. `residential · corner` — casas + esquina con landmark.
3. `denseUrban · intersection` — edificios altos, cruz, 4 esquinas.
4. `roadCorridor · midBlock` — avenida/ruta ancha, pocos edificios.

---

## Fases de implementación
1. **`SceneDescriptor` + extracción de tags** (zona ya está; sumar topología, name,
   oneway/lanes/surface/lit, y la lista de landmarks). Lógica pura, **testeable**.
2. **Detección de topología** (cruces/ramas/ángulos). Pura, testeable.
3. **Modelo de template + 2-3 templates** (datos) + **selector** (descriptor → template,
   orientado y escalado). ✅ *modelo + templates iniciales hechos (placeholder).*
4. **Render preview iso** (slots → cajas/labels en vista ¾, calle vertical) para validar el
   layout sin assets. ✅ *`IsoTemplatePainter` + pantalla de preview con sliders de inclinación.*
5. **Assets (pipeline pre-render):** modelar/bajar kit 3D CC0 (Kenney City Kit / Quaternius) →
   render orto a **ángulo ¾ fijo** en Blender (sombra horneada) → PNG/atlas → reemplazar las
   cajas placeholder por sprites. Variedad por slot vía siembra determinista.
6. **Migrar a Flame** con personajes **billboard** de frente (reusa descriptor + template + atlas).

## Riesgos / cuidados
- Mapeo `shop`/`amenity` → `kind` debe tener **fallback `generic`** (OSM trae miles de valores).
- Si OSM no trae calles (sin datos) → template `midBlock` por defecto + zona `unknown`.
- Mantener **determinismo**: misma posición → mismo template, misma orientación, mismos sprites.
