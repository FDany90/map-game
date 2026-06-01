# ADR 0007 — Estrategia visual: mapa top-down con iconos + escenas isométricas generadas desde OSM

> Estado: **aceptada** · 2026-05-30 · **revisada 2026-05-31** (Rev 1 y Rev 2, ver abajo)
> Relacionada con: [0001](0001-stack-flutter-flame.md) (Flutter+Flame),
> [0004](0004-tiles-raster-estilizados.md) (tiles raster),
> [0006](0006-mapa-flutter-map-flame-combate.md) (flutter_map; Flame para combate).
> Docs: [12-building-extrusion.md](../12-building-extrusion.md) ·
> [13-modos-pantallas-backlog.md](../13-modos-pantallas-backlog.md) ·
> [14-osm-datos-referencia.md](../14-osm-datos-referencia.md) ·
> [17-inferencia-morfologia-urbana.md](../17-inferencia-morfologia-urbana.md).

> ## ⚠️ Revisión 2026-05-31 (escena de combate — manda sobre lo de abajo)
> Tras analizar **assets 2D + aspect ratio del celular + cómo se ve un personaje**,
> se revisan varios puntos, **solo para la escena de combate** (el mapa sigue igual:
> top-down con iconos):
>
> 1. **Piso/escenario: top-down con "profundidad falsa"**, NO isométrico puro. Vista
>    cenital con edificios **levemente extruidos** + **sombras largas** (sensación 2.5D).
>    Motivo: el isométrico tiene la **perspectiva horneada** en cada sprite → no se rota a
>    un ángulo arbitrario y obliga a sets por dirección. El top-down se **rota a cualquier
>    grado** sin romperse → viable para dev solo y para arte generado.
> 2. **Personajes (jugador/zombies): sprites "billboard" de frente** parados sobre el piso,
>    con **sombra elíptica** que los ancla. NO se dibujan desde arriba (la coronilla no se
>    lee). Patrón de Enter the Gungeon / Binding of Isaac / Survivor.io / Vampire Survivors.
>    Como el billboard siempre mira a cámara, **no se rompe al rotar la calle**. (Esto ya
>    estaba en el ADR; se mantiene. Lo que cambia es solo el piso: iso → top-down.)
> 3. **Orientación: la calle principal se rota SIEMPRE a VERTICAL** (eje largo del cel).
>    Descartado "diagonal" y "norte real" para el combate. Motivo: la visión es **calle al
>    ~80% de la pantalla** con edificios como **borde decorativo** a los costados → una calle
>    horizontal en cel vertical desaprovecha la pantalla. El **norte real** se conserva como
>    **dato** y se muestra con una **brújula** en la escena (continuidad sin perder jugabilidad).
> 4. **Escenarios preferidos: ESQUINAS y calles verticales.** La esquina es el mejor
>    escenario (calle vertical de eje + transversal entrando horizontal a los costados → da
>    profundidad y juego lateral). Una recta sola es más "pasillo". Regla de generación: si
>    el punto cae en cruce/esquina → usarla; si cae en recta → **buscar la esquina más cercana**
>    dentro del hexágono (determinista por `hexId`).
> 5. **Paredes del corredor: SIEMPRE procedurales** (no los footprints reales de OSM). Al
>    renderizar la Fase 2 se vio que los edificios reales están **a media cuadra y agrupados a
>    un lado** → como paredes del corredor servían mal (escena **vacía** aun con 12-39 edificios
>    reales). Se usan solo como **señal**: cantidad→densidad, `building:levels`/`height`→altura.
>    El dibujo es generado y **determinista por posición**, con **carve-out** de cruces (esquinas
>    despejadas). El híbrido (real + relleno) se reserva para un render fiel al mapa (Nivel 3),
>    no para el combate. Detalle en [17-inferencia-morfologia-urbana.md](../17-inferencia-morfologia-urbana.md).
>
> En consecuencia, la sección "2. Escena ISOMÉTRICA 2.5D" y "Orientación: preservar el NORTE
> REAL (opción b)" de abajo quedan **superadas para el combate** por esta revisión. El resto
> del ADR (mapa con iconos, generación procedural desde OSM, continuidad mapa↔escena) sigue
> vigente. Estilo de arte: **código primero** (cero assets), luego pack CC0 (Kenney).

> ## ⚠️ Revisión 2 — 2026-05-31 (escena por *descriptor + templates*, manda sobre Rev 1 punto 5)
> Al renderizar la Fase 2 (colocar edificios desde geometría real, `_inferBuildings`)
> aparecieron bugs duros y recurrentes: **edificios desalineados** respecto a la calle,
> **calle inclinada**, **norte invertido**. Diagnóstico: reproducir geometría real fielmente
> hace que **cada esquina del planeta sea un caso borde** → bugs difíciles de encontrar. Y es
> **innecesario**: la fidelidad al mapa real ya vive en la **capa mapa** (flutter_map); el
> combate es un **zoom táctico estilizado**.
>
> **Se adopta el Nivel 2 "puro"** (que este ADR ya proponía como objetivo inicial): la escena
> se arma con **templates hechos a mano** que se **eligen y orientan** con datos OSM, en vez de
> colocar geometría. La vara de "se siente mi lugar" (definida con el usuario) es modesta y se
> cumple sin geometría exacta: **nombre de la calle**, casas/edificios acordes a la zona, **1 ó
> 2 sentidos**, **variedad** de sprites, y **POIs reales con su nombre** (Coto, Farmacity, la
> escuela) en el slot de esquina.
>
> - **Se jubila:** `CombatSceneLayout._inferBuildings` (placement desde geometría/polilíneas).
>   `CombatScenePainter` queda como preview hasta tener templates.
> - **Se conserva:** `ZoneProfile` (zona), norte/bearing, siembra determinista, Inspector/fetch OSM.
> - **Se enriquece** con: detección de **topología** (esquina/intersección/mitad de cuadra/fin,
>   por conteo de cruces), **tags de calle como temática** (`maxspeed`, `surface`, `lit`,
>   `sidewalk`, `oneway`/`lanes`, `name`), y **POIs con nombre** (`shop`/`amenity`/`building`).
>
> Spec completa: [18-scene-descriptor-templates.md](../18-scene-descriptor-templates.md).

> ## ⚠️ Revisión 3 — 2026-05-31 (look: **isométrico 2.5D con sprites 3D pre-renderizados**, manda sobre Rev 1 punto 1)
> Con la escena ya armada por **templates** (Rev 2) — no por geometría real — **se vuelve a
> isométrico 2.5D** para el combate (lo que este ADR proponía originalmente), porque queda
> mejor: los edificios muestran **fachada** (se leen como edificios, no como techos vistos de
> arriba) y la escena gana profundidad (look tipo TWD Survivors / Survivor.io).
>
> **Por qué ahora sí (y antes no):** el ÚNICO motivo por el que la Rev 1 pasó a top-down fue la
> **rotación** — se quería respetar el *bearing real* de la calle, y el iso tiene la perspectiva
> horneada en el sprite (no se rota a un ángulo arbitrario). La **Rev 2 eliminó ese requisito**:
> la calle va **siempre a vertical** y el norte real se muestra solo con **brújula**. Sin
> rotación arbitraria, la perspectiva horneada deja de ser un problema → iso vuelve a ser viable.
>
> **Stack sin cambios — el 3D es solo producción de assets, NO runtime:**
> - El juego **sigue en Flame 2D** (ADR 0001/0006). Flame nunca ve un polígono 3D.
> - Los assets se **pre-renderizan** (hornean) de modelos 3D CC0 (Kenney/Quaternius) a **sprites
>   PNG 2D** en Blender, a un **ángulo ¾ fijo**, con **sombra horneada**, una sola vez (offline).
> - Es la técnica clásica de iso pre-renderizado (Diablo I/II, StarCraft, Age of Empires). Ideal
>   para dev solo y sin habilidad de dibujo: modelar/bajar una vez → renderás → atlas → Flame.
> - **Unity sigue descartado** (ADR 0001): se elige Flutter por el **mapa real**; el iso por
>   sprites pre-renderizados da el look 3D sin motor 3D ni revertir el stack.
>
> **Aclaración técnica (el trade-off honesto):** "isométrico **estricto**" (ejes del piso a
> ±26.57°) y "calle **perfectamente vertical**" son **geométricamente incompatibles** (rotar una
> vista iso 45° la aplana a una vista frontal). Se resuelve **a favor de la calle vertical**: la
> escena es una **vista ¾ (dimétrica/oblicua)** con leve inclinación — calle vertical, edificios
> con **fachada + techo** (y un poco de lateral según la inclinación). Como el sprite se hornea a
> **ese** ángulo ¾ fijo y no se rota, no hacen falta sets por dirección. (En el lenguaje del
> proyecto le decimos "iso 2.5D"; la precisión es: ¾ con calle vertical.)
>
> **Personajes:** siguen siendo **billboard de frente** con sombra elíptica (sin cambios).
> **Se reemplaza** el preview top-down (`CombatScenePainter`) por un **preview iso de slots** (cajas
> placeholder) para validar el layout antes de tener assets. El resto de Rev 2 (descriptor +
> templates, topología, POIs, siembra determinista, brújula) **sigue vigente**.

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

### Orientación: ~~preservar el NORTE REAL (opción b)~~ → SUPERADA (ver Revisión 2026-05-31)
> ⚠️ **Reemplazada para el combate por "calle siempre vertical + brújula"** (ver Revisión arriba).
> Se mantiene el texto original como registro de la decisión previa.

~~La escena **respeta el ángulo verdadero** de las calles (no se rota para "acomodarlas" a un eje
isométrico cómodo). Prioriza **realismo y continuidad** mapa↔combate: la calle corre en su
dirección real; una avenida vertical se ve vertical.~~

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
