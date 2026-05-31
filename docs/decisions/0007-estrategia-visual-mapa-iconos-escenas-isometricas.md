# ADR 0007 — Estrategia visual: mapa top-down con iconos + escenas isométricas generadas desde OSM

> Estado: **aceptada** · 2026-05-30
> Relacionada con: [0001](0001-stack-flutter-flame.md) (Flutter+Flame),
> [0004](0004-tiles-raster-estilizados.md) (tiles raster),
> [0006](0006-mapa-flutter-map-flame-combate.md) (flutter_map; Flame para combate).
> Docs: [12-building-extrusion.md](../12-building-extrusion.md) ·
> [13-modos-pantallas-backlog.md](../13-modos-pantallas-backlog.md) ·
> [14-osm-datos-referencia.md](../14-osm-datos-referencia.md).

## Contexto
Surgió la pregunta de cómo mostrar monstruos, edificios y personajes, y si el mapa podía verse
en perspectiva/3D. Análisis (ver doc 12):
- El **pitch/tilt real** sólo lo da un motor GL (MapLibre/Mapbox); `flutter_map` (raster, canvas
  2D) no lo tiene. Migrar a MapLibre **revertiría el ADR 0006** y complicaría meter el juego
  encima.
- Referencias como *TWD Survivors* logran su look isométrico con **arte fijo ilustrado a mano**,
  no con un mapa real. MAP **no puede** ilustrar a mano cada esquina del planeta: su núcleo es el
  **mapa real generado de datos**.

Tensión central: **mapa real geográfico (top-down, de datos)** vs **escena isométrica bella
(sprites, profundidad)**. No se resuelven en una sola vista.

## Decisión
Separar en **dos capas visuales**, cada una con el render que mejor le sienta:

1. **Mapa / territorio — top-down con ICONOS** (flutter_map, raster).
   - Sobre el mapa **NO** se renderizan sprites de zombies/edificios. Sólo **iconos**: base,
     grupo de zombies, dungeon, boss, etc.
   - Tocar un icono → **se entra** a la escena correspondiente (Base / Combate / Dungeon).
   - Liviano, legible, escala a barrio→país→mundo (encaja con Modo Mapa del doc 13 y con LOD).

2. **Escena de acción — ISOMÉTRICA 2.5D en Flame** (Base / Combate / Dungeon).
   - Sprites "billboard" (vista 3/4) con **sombra elíptica** para apoyar en el suelo.
   - **Generada proceduralmente desde los datos OSM de ese hexágono/punto** (ver abajo).

## Generación procedural de la escena desde OSM
La escena de combate/base se construye con los **atributos reales** de OSM (vía `OverpassService`
+ futuro `building=*`), no con un escenario genérico. Detalle de tags en el doc 14.

- **Calles:** tipo (`highway=` → avenida vs calle vs peatonal), `lanes`/`width` (ancho),
  `oneway`, `surface`, `sidewalk`, `name`. El **ángulo/bearing** se **calcula** de la geometría.
- **Edificios:** footprint (geometría) + `building:levels`/`height` (extrusión), `roof:shape`,
  `building=`/`amenity` (tipo/uso → sprite/color).
- **Nivel de fidelidad (roadmap):**
  - **Nivel 2 (objetivo inicial):** clasificar el hexágono (recta / esquina / T / cruce /
    avenida) y ensamblar la escena con **piezas isométricas modulares** orientadas según la calle
    real. "Se siente mi esquina" sin renderizar geometría exacta.
  - **Nivel 3 (evolución):** dibujar polylines y footprints reales en isométrico, fiel.

### Orientación: preservar el NORTE REAL (opción b)
La escena **respeta el ángulo verdadero** de las calles (no se rota para "acomodarlas" a un eje
isométrico cómodo). Prioriza **realismo y continuidad** mapa↔combate: la calle corre en su
dirección real; una avenida vertical se ve vertical. (Trade-off aceptado: a veces menos "cómodo"
visualmente que rotar, pero más fiel — que es el alma del proyecto.)

## Continuidad mapa ↔ escena
Tocar un hexágono entra a **ese** punto real: misma calle, mismo tipo, misma dirección, mismos
edificios. "Toco mi esquina y la pelea es en mi esquina" — diferenciador que ningún competidor
con escenarios fijos tiene.

## Consecuencias
**Positivas**
- Mantiene el stack y el ADR 0006 (flutter_map para mapa, Flame para acción). No requiere MapLibre.
- Reutiliza el pipeline OSM ya construido (`OverpassService`).
- El mapa queda liviano (iconos) → escala y baja costo de tiles; la belleza va en la escena.
- Identidad única: escenas generadas de tu barrio real.

**Negativas / riesgos**
- La generación procedural Nivel 2→3 es trabajo no trivial (clasificación de cruces, ensamblado
  modular, manejo de datos OSM faltantes/incompletos).
- Preservar el norte real puede dar composiciones menos "cómodas" en isométrico → cuidar cámara/encuadre.
- Calidad dependiente de la completitud de OSM en la zona (mitigable con defaults sensatos).
- Hace falta set de **assets isométricos modulares** (piezas de calle, edificios, props).

## Alternativas descartadas
- **Todo el mapa con pitch 3D (MapLibre GL):** revierte ADR 0006; complica el overlay de juego.
- **Escena genérica fija (calle siempre igual):** barata pero mata el diferenciador del barrio real.
- **Rotar la escena para acomodar la calle (opción a):** más legible, menos fiel → descartada a
  favor del norte real.
