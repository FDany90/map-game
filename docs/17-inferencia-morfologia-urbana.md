# Inferencia de morfología urbana (cuando OSM no trae edificios)

> Estado: estrategia de diseño · 2026-05-31
> Documento vivo. Cómo generar la escena isométrica (ADR 0007) cuando OSM trae
> **calles pero pocos o ningún edificio** — el caso más común en la práctica.
> Relacionado: [ADR 0007](decisions/0007-estrategia-visual-mapa-iconos-escenas-isometricas.md) ·
> [14-osm-datos-referencia.md](14-osm-datos-referencia.md).

## El problema (verificado en el Inspector OSM)
Al probar varios puntos (Palermo, microcentro, bosques, y otros países) se confirmó:
**en la mayoría de los lugares OSM NO trae edificios** (`building=*` ausente). Las
**calles, en cambio, casi siempre vienen**. Por lo tanto:

> ⚠️ El generador de escenas **NO puede depender de los footprints de edificios.**
> Debe **inferir** si la zona es de edificios altos, de casas bajas, o abierta, y
> **dibujarla con pocos datos** — usando las calles como espina dorsal.

## Qué trae OSM, por confiabilidad
1. **Calles: casi siempre.** Y traen `highway=` (tipo), a veces `lanes`/`oneway`/`name`.
   → es la señal más rica y disponible.
2. **Edificios: a veces y desparejo.** Footprint + a veces `building:levels`.
3. **Resto** (`height`, `roof:shape`, `width`): casi nunca. No depender de ellos.

## Estrategia: inferir el "carácter de zona" desde las calles
Como las calles sí vienen, se deduce la morfología:

| Señal OSM (que SÍ viene) | Carácter inferido | Cómo se dibuja |
|---|---|---|
| **trama** (muchas calles) + avenidas/edificios | **denso urbano** | torres / edificios altos (varios pisos) |
| `residential` en cuadrícula apretada | **barrio de casas / PH** | casas bajas (1-3 pisos) |
| muchos `footway`/`path` + `leisure` | **parque / abierto** | césped, árboles, pocos o ningún edificio |
| **1-2 calles (avenida) y NADA alrededor** | **ruta / corredor** | la calle cruzando, pasto/banquinas, casi sin construcción |
| `track`/`unclassified`, calles dispersas | **rural / descampado** | casas dispersas, mucho terreno vacío |
| **cantidad de calles** (`streetCount`) | proxy de "qué tan urbano" | escala la altura/densidad de relleno |

> ⚠️ **Denso ≠ una sola avenida.** "Denso urbano" exige **trama** (varias calles que
> se cruzan) y/o **edificios mapeados** — NO la mera presencia de una avenida. Una
> avenida sola con pasto al lado es **ruta / corredor**, no ciudad.
>
> ⚠️ **Bug corregido (recorte al radio):** Overpass con `out geom` devuelve la calle
> **entera** (puede medir km), no solo el tramo dentro del círculo. Sumar esa longitud
> cruda inflaba la densidad (medido: 6148 m/ha con UNA avenida). Solución: **recortar
> cada calle a la intersección con el círculo** del radio consultado. Para *contar*
> calles se usa `scene.streets.length` directamente (Overpass `around:` ya filtra por
> cercanía).

### Variantes futuras (cuando haga falta)
- 🏭 **Industrial:** `landuse=industrial`, `building=industrial/warehouse`, galpones grandes.
- 🌊 **Costa / agua:** `natural=water`, `waterway`, línea de costa.
- 🏟️ **Plaza / equipamiento:** `amenity` o `leisure` puntuales dominantes.

## Radio de CLASIFICACIÓN ≠ radio de la ESCENA (decisión 2026-05-31)
Son dos cosas distintas y usan radios distintos:

| Concepto | Radio | Para qué |
|---|---|---|
| **Clasificación de zona** | **~200 m** (contexto) | decidir *qué tipo* de barrio es. Necesita ver alrededor: una avenida sola a 50 m es ambigua; a 200 m se ve si hay **trama** (ciudad) o sólo **pasto** (ruta/rural). |
| **Escena de combate** | **~50-100 m** | lo que se **dibuja y se juega**: tu calle / avenida / parche de parque (recorrido < 100 m). |

El Inspector hace **dos consultas** (ambas cacheadas): la fina (chips 50/100/150 m) para
el overlay/stats, y una de **200 m sólo para clasificar**. Así el carácter de la cuadra lo
define el barrio que la rodea, pero la escena sigue siendo chica (encaja con ADR 0007).

## Pipeline de generación (con y sin edificios)
1. **Traer la escena** (ya hecho: `OsmSceneRepository`).
2. **Clasificar la zona** (`ZoneProfile`): a partir de los tipos de calle + densidad,
   decidir denso / residencial / parque / rural. **Determinista** (ver abajo).
3. **Detectar manzanas:** los polígonos que las calles encierran (city blocks).
4. **Rellenar cada manzana** con edificios **procedurales** del tipo inferido:
   - franja de "lote" pegada a la calle, subdividida en parcelas;
   - cada parcela → un edificio (alto si denso, casa si residencial);
   - parques/abierto → sin edificios, con vegetación.
5. **Si hay footprints reales de OSM → usarlos** (son la verdad); **los huecos** se
   completan con edificios inferidos. Híbrido: real donde existe, inferido donde no.
6. **Extruir** todo a isométrico (cajas por nº de pisos), **norte real** (ADR 0007).

## Regla de oro: determinismo (no random por frame)
La inferencia **no puede ser aleatoria cada vez** (rompería continuidad y la economía
determinista por `hexId`, ver [16-modelo-hexagonos-bd.md](16-modelo-hexagonos-bd.md)).
- Sembrar todo lo "aleatorio" (cuántas parcelas, alturas, dónde un árbol) con un
  **PRNG sembrado por la posición/`hexId`** → el mismo punto genera **siempre la misma
  ciudad**. Distinto punto, distinta ciudad, pero estable.
- "Tocá tu esquina → es tu esquina, siempre igual" (ADR 0007) aplica también a lo inferido.

## Defaults sensatos (nunca romper por dato faltante)
- Sin `building:levels` ni `height` → altura por **carácter de zona** (denso ~6-12 pisos,
  residencial ~1-3).
- Sin `width`/`lanes` → ancho por `highway=` (avenida ancha, residential angosta).
- Sin edificios → **inferir y rellenar** (este documento).
- Sin calles (rarísimo) → escena mínima genérica del bioma.

## Consecuencia para la Fase 2
La Fase 2 (primer render isométrico en Flame) debe incluir, desde el principio, el
**modo "sin edificios"**: clasificar zona + rellenar manzanas inferidas. Probarla
justamente en puntos **sin** `building=*` (que son la mayoría) es la verdadera prueba.
