# Dirección de arte del mapa

> Estado: borrador v0.1 · relacionado con Etapa 3 (UX) y Etapa 4 (spike del mapa)
> Documento vivo.

## Principio rector

**El mundo real es el *escenario*, no las piezas de juego.** El mapa real (las calles de
tu casa, tu avenida con su nombre, las manzanas de tu barrio) es el terreno reconocible y
atmosférico. El juego de verdad son **nuestros sprites sobre la grilla de hexágonos**,
dibujados encima. El jugador no "captura" su casa real: reclama territorio (hexágonos) y
construye *sus* estructuras arriba.

## Qué se ve del mundo real

Usando datos de **OpenStreetMap** (vía el proveedor de tiles), se ve:
- Calles y **avenidas reales**, con sus **nombres** (mostramos las principales, atenuamos
  las menores: legibilidad + atmósfera).
- Manzanas y huellas de edificios reales (en el Nivel A, pintadas dentro del mapa).
- Agua, parques, vías.

Todo **re-estilizado** con la identidad del juego (no el mapa gris de Google).

## Estilo visual

Paleta oscura / post-apocalíptica:
- Asfalto agrietado, vegetación invadiendo, agua negra.
- El **territorio oscuro (infestado)** se "corrompe" visualmente respecto del territorio seguro.
- El estilo se diseña en el editor del proveedor (MapTiler Customize) y se sirve ya pintado.

## Capas de render (de abajo hacia arriba)

```
CAPA 4  Efectos      → disparos, explosiones, niebla de infección
CAPA 3  Unidades     → monstruos, defensas (sprites animados)
CAPA 2  Construcción → edificios del jugador (torretas, muros)
CAPA 1  Hexágonos    → grilla H3 (claro / oscuro / vecino / rival)
─────────────────────────────────────────────────────────────
CAPA 0  MAPA REAL    → barrio real (calles + nombres + manzanas) re-estilizado
```

## Niveles de fidelidad de edificios

| Nivel | Qué muestra | Esfuerzo | Cuándo |
|-------|-------------|----------|--------|
| **A** ✅ | Calles + nombres + manzanas reales; edificios "pintados" dentro del mapa (no interactivos). Las construcciones son sprites del jugador sobre los hexágonos | Bajo | **Prototipo** |
| B | Huellas de edificios reales "skineadas" como props del juego (requiere tiles vectoriales) | Medio | Meta futura |
| C | Cada edificio real es un objeto interactivo del juego | Alto | Muy a futuro, si el juego lo pide |

**Decisión para el prototipo: Nivel A** con tiles **raster ya estilizados** (ver
[ADR 0004](decisions/0004-tiles-raster-estilizados.md)).

## Qué ve el jugador al abrir la app (Nivel A)

> Vista cenital de **su manzana real**, asfalto oscuro y agrietado, su avenida con el
> nombre tenue, una **grilla de hexágonos** encima; sus edificios (sprites) en los
> hexágonos reclamados; unos hexágonos más allá, en penumbra corrupta, el **territorio
> oscuro** de donde salen los monstruos.

## Proveedor de tiles

**MapTiler** (ver [ADR 0005](decisions/0005-proveedor-tiles-maptiler.md)) — elegido por
encajar con la arquitectura de renderizar tiles en nuestro propio motor.
