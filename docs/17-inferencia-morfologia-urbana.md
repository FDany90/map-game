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

## Radio de consulta: UNA sola (decisión 2026-05-31, revisada)
Una sola consulta de **~150 m** (default; ajustable 100/200 m) alcanza para **ambas
cosas a la vez** y de los **mismos datos**:
- **clasificar la zona** (mirar las calles del entorno: trama vs. pasto), y
- **representar** la escena (dibujar la calle/manzana del punto tocado).

> Se descartó la idea previa de **dos consultas** (una fina para dibujar + una de 200 m
> para clasificar): duplicaba las llamadas a OSM sin beneficio real — 150 m ya da
> contexto suficiente para concluir la categoría, y la calle del punto se extrae del
> mismo subconjunto ya descargado. Menos red, más simple. (Si en el futuro la escena de
> combate necesita un recorte más chico, se **filtra en cliente** sobre la escena ya
> traída, sin otra consulta.)

## Pipeline de generación (con y sin edificios)
1. **Traer la escena** (ya hecho: `OsmSceneRepository`).
2. **Clasificar la zona** (`ZoneProfile`): a partir de los tipos de calle + densidad,
   decidir denso / residencial / parque / rural. **Determinista** (ver abajo).
3. **Detectar manzanas:** los polígonos que las calles encierran (city blocks).
4. **Rellenar cada manzana** con edificios **procedurales** del tipo inferido:
   - franja de "lote" pegada a la calle, subdividida en parcelas;
   - cada parcela → un edificio (alto si denso, casa si residencial);
   - parques/abierto → sin edificios, con vegetación.
5. **Generar las paredes del corredor** (ver "Paredes procedurales" abajo).
6. **Extruir** todo (cajas por nº de pisos), top-down con profundidad falsa (ADR 0007 rev).

## Paredes procedurales (decisión Fase 2, 2026-05-31)
Al renderizar la escena de combate real se descubrió que **usar los footprints reales
de OSM como "paredes" del corredor no funciona**, ni siquiera cuando OSM **sí** trae
edificios:

> Probado en Palermo: puntos "denso urbano" con **12 y 39 edificios reales** → la escena
> salía **casi vacía**. Motivo: los footprints están **a media cuadra** y **agrupados a un
> lado** (a ~80-100 m del punto tocado), fuera del encuadre del corredor (~70 m); y como
> había ≥6 reales, el relleno inferido se **salteaba** → doble vacío.

**Decisión:** para el **corredor jugable**, las paredes son **siempre procedurales** —
alineadas a ambos lados de la calle vertical, deterministas por posición. Los edificios
reales de OSM se usan **solo como señal**, no como dibujo:
- **cantidad de edificios reales → densidad** del corredor (menos huecos si OSM trae muchos);
- **`building:levels`/`height` declarados → altura** de las paredes (si nadie declara, altura por zona).

Además se hace **carve-out de cruces**: si un lote pisa una calle transversal, se omite →
la **intersección queda despejada** (las esquinas son los escenarios clave del ADR 0007 rev).

> 🔭 El enfoque **híbrido** (dibujar footprints reales donde están + rellenar huecos) se
> reserva para un eventual **render fiel al mapa** (Nivel 3 del ADR 0007), no para el
> corredor de combate, donde la jugabilidad pide paredes limpias y consistentes.

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
