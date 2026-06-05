# 🟢 HANDOFF — Empezá acá para retomar

> Última actualización: **2026-06-04** (**mapa → combate Slice A**: iconos de amenaza 🧟 deterministas [gradiente de dificultad, doc 16] → bottom sheet con dificultad/enemigos → "Atacar" carga la escena; antes ese día combate Flame **Bloque B**: escenario de **cuadra entera con esquina al fondo** [template `residential.block`, área jugable derivada del largo de la calle] + **autos con collider**; y **Bloque A**: arma+cargador con recarga auto, HP de zombies, victoria por cupo, colectables drop de zombies, economía, joystick centrado, **perf optimizada** [~57 FPS en profile]; y antes: vida del jugador + Game Over + balance, y **tiles MapTiler 512px nativo** [`zoomOffset:-1`] → ~⅓ requests + letras default. Más atrás: escena iso 2.5D jugable en Flame, cámara ¾ lockeada, bandas de zoom + monitor, Inspector OSM, pivot *descriptor + templates* ADR 0007 Rev 2/3)
> Este documento es el punto de entrada para continuar el proyecto en otra sesión
> (o si se limpia el chat). Resume el estado, lo resuelto, lo pendiente y cómo seguir.

## Cómo retomar con Claude
Decile algo como: **"Leé `docs/HANDOFF.md` y seguimos por [el tema que elijas]."**
(La memoria del proyecto también persiste entre sesiones.)

---

## Qué es el proyecto (1 párrafo)
**MAP** (título provisional): juego móvil de **construcción, defensa y guerra territorial
social sobre el mapa real** del barrio del jugador. Fusiona apocalipsis zombie +
supervivencia + economía + alianzas/política. Núcleo = **jugar desde casa** (asíncrono);
capa opcional = **Modo Exploración** con GPS. Hecho por **un desarrollador en solitario**
(Daniel). Repo: **https://github.com/FDany90/map-game** (rama `main`).

---

## Estado general (roadmap)
| Etapa | Estado |
|---|---|
| 0 Visión & GDD | ✅ |
| 1 Arquitectura & ADRs | ✅ |
| 2 Datos & economía | 🟡 (economía ✅, modelo de datos ⬜) |
| 3 Mockups/UX | ⬜ |
| 4 Spike del mapa | ✅ (validado con flutter_map; prototipo jugable) |
| 5 Prototipo Modo Base | 🟡 (mapa + hexágonos + economía + caché + arquitectura por capas) |
| 6 Multijugador | ⬜ |
| 7 Modo Exploración | ⬜ |
| 8 Arte/pulido/launch | ⬜ |

---

## ✅ Decisiones resueltas (con links)
- **Stack:** Flutter (no Unity, no web app). [ADR 0001](decisions/0001-stack-flutter-flame.md)
- **Mapa:** se renderiza con **flutter_map** (no en Flame). Flame queda **diferido y acotado
  al combate**. [ADR 0006](decisions/0006-mapa-flutter-map-flame-combate.md) (reemplaza al 0002)
- **Tiles:** raster estilizados de **MapTiler**. [ADR 0004](decisions/0004-tiles-raster-estilizados.md) ·
  [ADR 0005](decisions/0005-proveedor-tiles-maptiler.md)
- **Backend:** BaaS (Supabase o Firebase), a confirmar. [ADR 0003](decisions/0003-backend-baas.md)
- **Economía:** modelo **limitado y activo (anti-idle)** — loot finito + ingreso por
  actividad (matar zombies + explorar); 3 recursos (Materiales / Energía / Combustible);
  territorio oscuro = amenaza + granja; limpiar antes de reclamar.
  [05-economia.md](05-economia.md)
- **Combate:** automático y resuelto en diferido (no requiere servidor de tiempo real).
- **Movimiento:** jugar desde casa (núcleo) + exploración opcional.
- **Investigación de mercado:** el nicho de MAP está **vacío** (nadie hace zombie territorial
  social sobre el mapa real desde casa). [10-investigacion-hallazgos.md](10-investigacion-hallazgos.md)
- **Costos MapTiler:** para nuestros tiles raster se factura por **REQUESTS** (Free 100k/mes;
  cada tile no cacheado = 1 request), NO por sesiones. La **caché** es la palanca #1.
  [08-cost-analysis-tiles.md](08-cost-analysis-tiles.md)
- **Presupuesto de tiles + bandas de zoom (DECIDIDO 2026-05-31):** objetivo **≤100-200 requests/
  jugador/mes**. Se logra con **bandas de zoom discretas por modo** (Base local z18 · Mapa-ciudad
  z11-12 con iconos del backend · País z4-7), **sin z13-17 de roam libre**, área acotada por banda,
  y exploración = mapa de ciudad con iconos (NO GPS al inicio). `maxZoom` capeado 20→18. Se agregó
  un **monitor de requests in-app** (`TileRequestMonitor` + chip "🛰️ MapTiler: N", toca→resumen por
  zoom en consola) para medir por prueba, **botones de banda de zoom** (Ciudad z10/Barrio z14/Base
  z18 + recenter, saltos con `move()` instantáneo = sin tiles intermedios) y **zoom continuo
  desactivado** (pinch/doble-tap/scroll off → el zoom solo cambia por banda). **Tiles `tileSize: 512`
  nativo ADOPTADO (2026-06-04):** MapTiler ya entrega 512px (el SKU se factura así); declararlos 256
  los achicaba (etiquetas chicas) y pedía 4× más tiles. Con **`tileSize: 512` + `zoomOffset: -1`**
  (la cuenta da `2^offset=½`) → ~⅓ de requests + letras a tamaño default. **Resuelve el bug del
  intento del 2026-05-31** (sin offset abría a escala país). Validado en emulador (pide z16). Ver
  [08-cost-analysis-tiles.md](08-cost-analysis-tiles.md) +
  [13-modos-pantallas-backlog.md](13-modos-pantallas-backlog.md).

---

## 🎮 Estado del prototipo (`map_spike/`)
App Flutter que ya corre en emulador Android:
- Mapa **MapTiler oscuro** centrado en **Palermo, BA**.
- **Grilla de hexágonos** reclamables (tocar para reclamar; se pintan verde).
- **Mini-economía:** reclamar cuesta 10 suministros; cada hexágono produce +30/min; HUD en vivo.
- Controles de **zoom +/−**, **botón de cerrar** (FAB rojo → `SystemNavigator.pop()`) y label de zoom.
- **Caché de tiles en disco** (Hive vía `flutter_map_cache`): los tiles ya vistos se sirven
  localmente en vez de re-pedirse a MapTiler.
- **Arquitectura por capas (MVVM):** `domain/` (modelos) · `data/` (servicios + repositorios) ·
  `ui/features/map/` (ViewModel + views). La economía vive en `TerritoryRepository` (testeable).
  Ver [03-architecture.md](03-architecture.md).
- **Inspector OSM interactivo (FAB azul 🔵 `travel_explore`):** abre **donde está mirando el
  mapa real** (navegás con zoom/scroll, incluso a otro país, y lo inspeccionás ahí); **tocás
  un punto → consulta Overpass en vivo** (con caché) y dibuja **sobre el mapa real** las calles,
  edificios y áreas (leisure) de ese punto, con conteos y **cobertura de tags**. Radio 100/150/200 m.
  Muestra además **zona inferida** (`ZoneProfile`) y la **calle + altura** del punto (Nominatim
  reverse geocoding) con lat/lon copiables para chequear en Google Maps. Es la **Fase 1 del
  generador de escenas** del ADR 0007 (la materia prima para la escena de combate).
- **Escena de combate (preview) — FAB naranja "Ver escena" en el Inspector:** **Fase 2** del ADR
  0007. Render **top-down con profundidad falsa** (CustomPainter; migra a Flame al meter personajes)
  generado por código desde el punto OSM: **calle principal rotada SIEMPRE a vertical**, edificios
  extruidos (paredes + sombra) como bordes del corredor, **brújula** con el norte real, y
  **carve-out** de las calles transversales (esquinas despejadas). Las **paredes son siempre
  procedurales** (los footprints reales de OSM están a media cuadra y dispersos → se usan solo como
  **señal**: cantidad→densidad, pisos declarados→altura). Determinista por posición. 34 tests verdes.
- (En commits previos también se probó: oleada de zombies + torreta con FPS — combate.)

### Cómo correrlo
1. **Iniciar el emulador** (una de estas):
   - Desde **Android Studio → Device Manager → ▶ Pixel 7**, o
   - Por consola, **desacoplado** (importante, ver gotcha):
     `& "$env:LOCALAPPDATA\Android\Sdk\emulator\emulator.exe" -avd Pixel_7`
2. Esperar el boot (~30-60s).
3. Correr la app:
   `cd map_spike` → `flutter run -d emulator-5554`
4. En la consola de `flutter run`: `r` = hot reload, `R` = hot restart, `q` = salir.

### ⚠️ La API key (secrets)
La key de MapTiler **NO está en el repo**: vive en `map_spike/lib/secrets.dart` (gitignored).
En esta máquina ya existe. Si clonás en otra: copiá `secrets.example.dart` → `secrets.dart`
y poné tu key de [cloud.maptiler.com](https://cloud.maptiler.com).
*(La key actual quedó expuesta en el chat — conviene restringirla por dominio o rotarla.)*

---

## 🛠️ Entorno (esta máquina, Windows 11)
- ✅ Flutter 3.44 · Android Studio + emulador **Pixel_7 (API 37)** · Git 2.54
- ✅ **Node.js v24 / npm 11** (instalado para el CLI `npx skills add`). Gotcha: cambios de PATH
  no aplican a shells ya abiertas → refrescar el PATH o abrir una consola nueva.
- **Skills en `.claude/skills/`**: ver sección **"🧠 Skills del proyecto"**. Los **locales**
  cargan sin reiniciar; los oficiales de Flutter pueden requerir reiniciar Claude Code.

### ⚠️ Gotchas operativos
- Si el emulador se lanza desde una **tarea en segundo plano**, se **cierra** al terminar la
  tarea. Lanzarlo **desacoplado** (`Start-Process` / call operator) o desde Android Studio.
- En el emulador, **pinch** = `Ctrl` + arrastrar; las letras del mapa se ven chicas porque
  el emulador se muestra al ~33% (en celular real se ve mejor; la solución de fondo es un
  estilo propio de MapTiler).

---

## 🧠 Skills del proyecto (se auto-usan cuando corresponde)
Claude los dispara solo según su descripción; a mano: `/<nombre>`. Detalle en `CLAUDE.md`.
- **`flutter-apply-architecture-best-practices`** (oficial) — estructurar/refactorizar a capas
  (UI-MVVM · Data · Domain). Se usó para reorganizar `map_spike/`.
- **`flutter-fix-layout-issues`** (oficial) — errores de layout (overflows, constraints).
- **`flutter-caching-data`** (local, a medida) — persistencia/caché: tiles, imágenes,
  offline-first. Se usó para la caché de tiles.
- **`mobile-game-ui-design`** (local, a medida) — UI/UX mobile-first del juego: HUD sobre mapa
  vivo, ergonomía táctil, feedback de hexágonos, recursos, HUD por modo, performance.

> ⚠️ **Lección skills.sh:** mezcla skills reales con **entradas fabricadas** que no existen en
> el repo fuente (confirmados falsos: `flutter-caching-data` en `flutter/skills`,
> `davila7/.../mobile-design`). **Verificar siempre el `SKILL.md` contra el raw de GitHub** antes
> de instalar. Por eso los de caching y UI los escribimos **locales y a medida**.

---

## 📚 Mapa de documentos (`docs/`)
- [00-roadmap.md](00-roadmap.md) — etapas y estado
- [01-vision.md](01-vision.md) — pitch, pilares
- [02-game-design.md](02-game-design.md) — GDD: loop, 2 modos
- [03-architecture.md](03-architecture.md) — stack (flutter_map)
- [05-economia.md](05-economia.md) — economía limitada/activa
- [07-map-art-direction.md](07-map-art-direction.md) — arte del mapa
- [08-cost-analysis-tiles.md](08-cost-analysis-tiles.md) — costos MapTiler (por sesión)
- [09-referencias.md](09-referencias.md) — juegos: qué tomar/evitar
- [10-investigacion-hallazgos.md](10-investigacion-hallazgos.md) — research con fuentes
- [11-zombies-calles-cost.md](11-zombies-calles-cost.md) — costo/opciones del movimiento de zombies (visual)
- [12-building-extrusion.md](12-building-extrusion.md) — edificios 3D: opciones y recomendación (extrusión propia)
- [13-modos-pantallas-backlog.md](13-modos-pantallas-backlog.md) — backlog de modos/pantallas (Menú, Base, Mapa, Exploración, Dungeon, LOD)
- [14-osm-datos-referencia.md](14-osm-datos-referencia.md) — OSM/Overpass: atributos para escenas, costo/conectividad, caché
- [15-placement-bases-vecinos.md](15-placement-bases-vecinos.md) — anti-solapamiento de bases de vecinos (grilla + clustering)
- [16-modelo-hexagonos-bd.md](16-modelo-hexagonos-bd.md) — BD de hexágonos: generación lazy (sparse, se materializa al jugar)
- [17-inferencia-morfologia-urbana.md](17-inferencia-morfologia-urbana.md) — generar la escena cuando OSM **no trae edificios** (inferir zona desde calles + rellenar manzanas, determinista)
- [18-scene-descriptor-templates.md](18-scene-descriptor-templates.md) — **pivot**: escena por *descriptor + templates orientados* (zona + topología + tags + POIs), NO geometría real (ADR 0007 Rev 2)
- [19-mapa-amenazas.md](19-mapa-amenazas.md) — **amenazas en el mapa**: iconos deterministas (gradiente doc 16) → popup → "Atacar" → escena (Slice A hecho; B/C en backlog)
- [spike-01-maptiler-flutter.md](spike-01-maptiler-flutter.md) — guía del spike
- [decisions/](decisions/) — ADRs 0001-0007

---

## ⬜ Temas pendientes / próximos pasos (priorizados)
0. ✅ **HECHO (2026-05-30) — Caché de tiles en `map_spike`:** se agregó `flutter_map_cache`
   + `dio_cache_interceptor` + `HiveCacheStore` (persistente en disco, `getTemporaryDirectory`)
   al `TileLayer` (`CachedTileProvider`, `maxStale: 30 días`). `flutter analyze` limpio y test
   en verde. **Por qué:** sin caché cada pan/zoom recargaba tiles y quemaba requests de MapTiler
   (medido: **9.392 en un día** de testeo, ~9% del cupo Free de 100k/mes). Era la palanca #1 de
   costo. ✅ **Validado en emulador** (box `dio_cache.hive` ~10 MB en disco). Opcional: medir el
   ahorro real en el dashboard de MapTiler.
0b. ✅ **HECHO (2026-05-30) — Arquitectura por capas en `map_spike` + botón de cerrar:** se
   refactorizó el `main.dart` monolítico a capas (`domain` / `data` / `ui`-MVVM) con el skill
   `flutter-apply-architecture-best-practices`. La economía quedó en `TerritoryRepository`
   (testeable: 7 tests) y la UI en `MapViewModel` + views; se extrajo `EconomyHud`. Se agregó un
   FAB de cerrar (`SystemNavigator.pop()`). `flutter analyze` limpio, 8 tests verdes, corre en
   emulador. Estructura documentada en [03-architecture.md](03-architecture.md).
1. **Cerrar Etapa 2 — Modelo de datos** (`04-data-model.md`): entidades Hexágono, Base,
   Edificio, Recurso, Unidad y relaciones → prepara el backend.
2. **Implementar el nuevo modelo de economía en el prototipo:** loot **finito** que se agota
   + **drops de zombies** al morir + limpiar territorio oscuro antes de reclamar (sentir el
   anti-idle).
3. **Estilo propio en MapTiler Customize:** look apocalíptico + fuentes más grandes.
4. **Zombies caminando por las calles (VISUAL — alcance decidido 2026-05-30):** es **valor
   visual** para que el farmeo se *vea* (zombies spawnean, caminan por la calle, la base los mata
   a tiros y suben recursos), **no** posición exacta. → **No requiere grafo/A\***: enfoque
   "carriles de calle" (calles de Overpass cacheadas una vez → caminar por la polyline hacia la
   base). Vive en Flame (combate, ADR 0006). Costo ~$0. Detalle y opciones en
   [11-zombies-calles-cost.md](11-zombies-calles-cost.md).
   ✅ **Spike L0 HECHO (2026-05-30):** `OverpassService` trae calles reales (ojo: Overpass exige
   **User-Agent** o da 406) + `ZombieSpikeViewModel`/`ZombieSpikeScreen` (zombies caminan por la
   polyline, torreta dispara y mata, suben recursos). Verificado en emulador con calles OSM reales.
   Entrada: FAB verde 🐛 en el mapa. ✅ **Caché en disco** vía `StreetsRepository` (best-practice:
   caché/offline/fallback en el repositorio, no en el service): orden caché→Overpass→fallback;
   `OverpassService` quedó puro (endpoint + mirror, lanza si falla). **Falta:** pasar a Flame al escalar.
5. **Segunda investigación** (huecos del informe): Ingress/portales, EVE/sovereignty,
   anti-ballena más allá de escudos, y **densidad mínima de jugadores por barrio** (el
   problema del mapa vacío).
6. **Nombre del juego:** el repo es `map-game`; el título comercial está **sin definir**.
   Candidatos: *Reclaim*, *Barrio Cero*, *MAP*, *Perímetro*.
7. **Backend/multiplayer (Etapa 6):** confirmar Supabase vs Firebase; diseñar sincronización
   del territorio.
8. **Modo Exploración (Etapa 7):** GPS en vivo + combate activo + gate de combustible.
9. **Edificios 3D (extrusión):** decisión preliminar = extrusión propia estilizada con footprints
   `building=*` de Overpass en Flame (NO MapLibre, que revertiría el ADR 0006). Si se valida con un
   mini-spike visual, promover a ADR 0007. Ver [12-building-extrusion.md](12-building-extrusion.md).
10. **Backlog de modos/pantallas** (ideas, sin decidir): Menú · Modo Base (acotar zoom-out a la
    zona) · Modo Mapa (país/provincia/mundo, clanes dominantes, ranking) · Modo Exploración ·
    Modo Dungeon · **LOD** (mostrar/ocultar elementos por nivel de zoom). Ver
    [13-modos-pantallas-backlog.md](13-modos-pantallas-backlog.md).
11. **Estrategia visual decidida (ADR 0007):** mapa top-down con **iconos** (base/zombies/dungeon/
    boss) + al tocar se entra a **escena isométrica 2.5D en Flame** (Base/Combate/Dungeon)
    **generada proceduralmente desde OSM** (calles: tipo/ancho/sentido + bearing real; edificios:
    footprint + niveles/altura/techo). Nivel 2 (piezas modulares orientadas) → Nivel 3 (geometría
    fiel); **preservar el norte real**. Ver
    [decisions/0007-estrategia-visual-mapa-iconos-escenas-isometricas.md](decisions/0007-estrategia-visual-mapa-iconos-escenas-isometricas.md)
    + [14-osm-datos-referencia.md](14-osm-datos-referencia.md). **Overpass es gratis/sin key**
    (fair-use); en producción va **detrás del backend** (Etapa 6), no llamado por cada jugador.
    - ✅ **Fase 1 HECHA (2026-05-31) — Inspector OSM:** se preservan los **tags** (antes las
      calles los descartaban): `domain/models/osm_feature.dart` (geometría + tags + bearing real
      calculado) + `osm_scene.dart`; `OverpassService.fetchSceneAround` (query combinada
      `highway`+`building`+`leisure`, conserva tags) + `OsmSceneRepository` (caché en disco, patrón
      `StreetsRepository`, sin fallback sintético); feature `ui/features/osm_inspector/`
      (mapa interactivo, tap→consulta en vivo, overlay sobre mapa real, radio 50/100/150 m).
      Verificado en emulador; `flutter analyze` limpio; 13 tests (8 previos + 5 de `OsmFeature`).
      **Gotcha:** `latlong2` exporta una clase `Path` que pisa la de Flutter en `CustomPainter` →
      importar con `hide Path`.
    - 📊 **Hallazgos de datos (sondeo Palermo/microcentro):** la **geometría es 100% confiable**;
      los **tags son desparejos por zona** → `width` casi nunca viene (calcular de `highway`+`lanes`),
      `height` 0% en Palermo pero ~95% en microcentro, `roof:shape` ≈ inútil hoy. **Defaults/inferencia
      robustos = el grueso del trabajo** del generador.
    - ✅ **Fase 2 HECHA (2026-05-31) — escena de combate por código:** `domain/models/combat_scene_layout.dart`
      (lógica pura, determinista) proyecta lat/lon→metros, **rota la calle principal a vertical**
      (`rot = π/2 − ángulo`), genera las **paredes siempre proceduralmente** a ambos lados, hace
      **carve-out** de cruces (esquinas despejadas) y expone el **norte real** para la brújula. Render
      `ui/features/combat_scene/` (CustomPainter top-down: paredes extruidas + sombra + brújula).
      `flutter analyze` limpio; **34 tests** (7 del layout, incl. regresión "denso urbano con
      edificios reales igual genera paredes — no queda vacío"). Verificado en emulador.
      **Decisión clave (paredes procedurales):** los footprints reales de OSM están a media cuadra y
      agrupados a un lado → como "paredes" del corredor servían mal (escena vacía aun con 12-39
      edificios reales). Se usan solo como **señal** (cantidad→densidad, `building:levels`/`height`→altura);
      el dibujo es generado y determinista por posición. Ver [17-inferencia-morfologia-urbana.md](17-inferencia-morfologia-urbana.md).
    - 🔄 **PIVOT 2026-05-31 (ADR 0007 Rev 2) — escena por *descriptor + templates*, NO geometría:**
      al renderizar la Fase 2, colocar edificios desde geometría real dio bugs duros y recurrentes
      (desalineados, calle inclinada, **norte invertido**). Diagnóstico: reproducir geometría fiel hace
      que **cada esquina del planeta sea un caso borde**, y es **innecesario** (la fidelidad al mapa real
      ya vive en la capa mapa; el combate es un zoom táctico estilizado). **Se adopta el Nivel 2 puro:**
      la escena se arma con **templates hechos a mano** que se **eligen y orientan** con OSM. La vara de
      "se siente mi lugar" se cumple sin geometría: **nombre de calle**, casas/edificios por zona, **1-2
      sentidos**, **variedad** de sprites, y **POIs reales con nombre** (Coto, la escuela) en la esquina.
      **Se jubila** `_inferBuildings` (placement); **se conserva** `ZoneProfile`, norte/bearing, siembra
      determinista, Inspector. **Se enriquece** con **topología** (esquina/intersección/mitad de cuadra/
      fin, por conteo de cruces) + **tags de calle** (`maxspeed`/`surface`/`lit`/`sidewalk`/`oneway`) +
      **POIs** (`shop`/`amenity`). **Spec completa:** [18-scene-descriptor-templates.md](18-scene-descriptor-templates.md).
      Los arreglos de geometría del 2026-05-31 (re-centrado en x=0, norte normalizado, edificios siguiendo
      la polilínea — 39 tests) quedan como **checkpoint**; el preview (`CombatScenePainter`) sigue hasta
      tener templates.
    - 🔄 **REV 3 2026-05-31 (ADR 0007) — look: isométrico 2.5D con sprites 3D pre-renderizados:**
      con la escena ya por **templates** (no geometría), se vuelve a **isométrico 2.5D** (queda mejor:
      fachadas + profundidad). El motivo que descartó iso en Rev 1 era la **rotación** (bearing real),
      que la Rev 2 eliminó (calle siempre vertical + brújula) → iso vuelve a ser viable. **Stack sin
      cambios:** el juego sigue en **Flame 2D**; el 3D es solo **producción de assets** — se hornean
      kits 3D CC0 (Kenney/Quaternius) a **sprites PNG a un ángulo ¾ fijo** en Blender (técnica clásica:
      Diablo/StarCraft). **Unity sigue descartado** (Flutter por el mapa). Trade-off honesto: "iso
      estricto" y "calle perfectamente vertical" son incompatibles → se elige **calle vertical + vista
      ¾** (fachada + techo). Detalle en [ADR 0007 Rev 3](decisions/0007-estrategia-visual-mapa-iconos-escenas-isometricas.md).
    - ✅ **HECHO (2026-05-31) — modelo de template + preview iso (doc 18 fases 3-4):**
      `domain/models/scene_template.dart` (slots en *street-space* `u`/`v`/`levels`, puro y determinista;
      3 templates iniciales: `residential.midBlock`, `residential.corner`, `denseUrban.intersection`),
      `ui/features/combat_scene/views/widgets/iso_template_painter.dart` (proyección iso ¾, calle vertical,
      cajas placeholder con fachada/techo/sombra) y `iso_template_preview_screen.dart` (selector de template
      + sliders de inclinación/cámara en vivo). **Entrada:** FAB violeta 🟣 (`view_in_ar`) en el mapa — no
      necesita OSM. Tests: `scene_template_test.dart`.
    - ✅ **HECHO (2026-06-01) — cámara ¾ ELEGIDA + lockeada:** tras tunear con los sliders (zoom/cámara X/
      inclinación iso/profundidad), se fijó la config del escenario: **zoom 4.10 · skew 0.35 · pitch 0.49 ·
      panX 0.01** (default en `IsoTemplatePainter` y en la preview screen). **Es el ángulo al que se
      renderizan los sprites en Blender** (ADR 0007 Rev 3). Ajustes de template: calle ancha (0.40), veredas
      angostas (0.08), edificios pegados al borde (u ±0.42, **fila alineada sin jitter**), autos sobre la
      calzada, calle larga (l 1.9). El painter recorta a sus límites (`clipRect`).
    - ✅ **HECHO (2026-06-01) — escena de combate JUGABLE en Flame (ADR 0001/0006):** se agregó `flame: ^1.18`
      y se migró la escena a Flame. `ui/features/combat_scene/game/combat_game.dart` (`CombatGame extends
      FlameGame`): **jugador se mueve estilo dungeon** con `JoystickComponent`, **cámara lo sigue** (lerp por
      `cameraV`), **zombies** spawnean adelante y caminan hacia él, **auto-disparo** al más cercano en rango
      (línea), contador de **Kills**. El escenario reusa `IsoTemplatePainter` en **modo cámara** (param
      `cameraV` + `player`/`enemies`/`shots`). `combat_play_screen.dart` (GameWidget). **Entrada:** FAB violeta
      → ▶ play en el AppBar. Verificado en emulador.
    - ✅ **HECHO (2026-06-04) — vida del jugador + Game Over + balance:** el jugador tiene **HP (100)**;
      los zombies que lo alcanzan **muerden** (daño con cooldown por zombie: `_biteInterval` 0.7s,
      `_biteDamage` 9, `_contactRange` 0.085), con **flash rojo** de feedback + **barra de vida** en el HUD;
      al llegar a 0 hay **Game Over** (overlay Flame `kGameOverOverlay` con Bajas + Reintentar/Salir;
      `pauseEngine` + `restart()`). Balance: **rampa de dificultad** (spawn de 1.1s→0.45s en 90s),
      **zombies de 2 tiros**, disparo 0.40s rango 0.75, máx 16. El skill pasa a ser **kitear** (el jugador
      es más rápido). `flutter analyze` limpio. **Pendiente:** play-test de tuning fino + vida del jugador
      regenerable/curación (a futuro).
    - ✅ **HECHO (2026-06-04) — Bloque A "loop de combate completo" + perf:** se decidió por consulta
      (recarga auto / victoria por cupo / drops de zombies). **Arma con cargador** (`magazineSize` 12) con
      **recarga automática** al vaciarse (`reloadTime` 1.4s, barra "Recargando…"); **HP de zombies** como stat
      (`zombieHp` 2) + **barrita de vida** sobre el zombie dañado; **victoria por cupo** (`targetKills` 20 →
      overlay `kVictoryOverlay` "Escenario completado"; el spawn se corta al cubrir el cupo); **colectables
      drop de zombies** (munición caja amarilla / vida cruz verde, se juntan caminando encima; la munición
      corta la recarga); **economía** (+5 recursos/kill). **Joystick centrado** en el eje horizontal, ~25%
      desde abajo. **HUD** vida/objetivo/recursos/munición. **Perf:** se cachearon el **gradiente de fondo** y
      los **`TextPainter`** (eran un `layout()` por edificio por frame = causa de los hitches de GC) y se
      apagan las etiquetas de slot en combate (`labelSlots:false`). **Contador de FPS dev** (`CombatGame.showFps`).
      **Medición (profile, emulador): ~57 FPS** → los freezes eran **debug+emulador, no el juego**. 47 tests verdes.
    - 📝 **NOTA / backlog (feature pedida 2026-06-04, NO implementada) — crítico en la cabeza como STAT del
      personaje:** que matar un zombie cueste **5 disparos** por defecto, pero el personaje tenga una **chance de
      golpe crítico a la cabeza** que lo mata **de un tiro**. Va dentro del sistema de **estadísticas del
      personaje** (futuro): `zombieHp` sube a 5 y el disparo tira `critChance` → si crítico, daño = HP del zombie.
    - ✅ **HECHO (2026-06-04) — Bloque B (escenario):** **(1) cuadra entera + esquina:** nuevo template
      `residential.block` (calle `l 2.2` con **cruce/esquina al fondo** + landmark `Coto`, edificios lineando
      ambos lados), **default de combate** (primero en `SceneTemplates.all`). El **área jugable se deriva del
      largo de la calle** (`SceneTemplate.playBoundsV` = `v ± l/2` con margen; para `l 1.9` da los límites
      históricos → sin regresión), así una calle más larga = cuadra más grande sin tocar el motor. La línea de
      carril del painter también se deriva del slot `street`. **(2) autos con collider:** los slots `prop` se
      vuelven rects de colisión (`_pushOutOfCars`, círculo-AABB con `_bodyR` 0.045); jugador y zombies no los
      atraviesan (cobertura táctica). Test del template relajado a `v∈[-0.4,1.4]` (la esquina al fondo). 47 tests
      verdes; verificado en emulador (jugador frenado por el auto, cuadra atravesable, victoria). **Pendiente
      menor:** la esquina al fondo conviene mirarla con calma + tuning del template.
    - ✅ **HECHO (2026-06-04) — Mapa→combate Slice A (amenazas con iconos):** decidido por consulta
      (grilla determinista simple / bottom sheet / vertical zombieGroup). Sobre el mapa se muestran
      **iconos de amenaza** generados **sin BD, deterministas** por posición (gradiente de dificultad, doc 16):
      `domain/models/map_marker.dart` (`MapMarker` + `MarkerKind {zombieGroup,boss,dungeon,base}` extensible +
      `EnemyGroup`), `data/services/threat_service.dart` (puro, grilla lat/lng + hash → sparse 18% + gradiente
      distancia-al-spawn ±textura), `ui/.../widgets/threat_widgets.dart` (`ThreatMarker` tappable coloreado por
      dificultad + `ThreatDetailSheet` bottom sheet). `MapViewModel` expone `threats` y los regenera al mover la
      cámara; `MarkerLayer` + `_showThreatSheet` en `map_screen`; **"Atacar"** → `CombatPlayScreen` (template
      actual). Verificado end-to-end en emulador (gradiente visible: verde centro→rojo bordes). 51 tests verdes
      (+4 de `ThreatService`). Spec: [19-mapa-amenazas.md](19-mapa-amenazas.md).
    - ⬜ **Backlog mapa→combate (próximas iteraciones, decididas como pendientes):**
      **(B)** la dificultad **maneja el combate** vía `CombatConfig` (la amenaza define `targetKills`/`zombieHp`/
      ritmo; hoy el popup es informativo); **(C)** iconos de **boss/dungeon** (varios tipos; el modelo ya lo
      soporta); **LOD/clustering** (a zoom ciudad los iconos se amontonan, doc 13); **densidad OSM** en el
      gradiente + **H3** como id de celda; **POI real** en el nombre de la amenaza.
    - ⬜ **Próximos (combate):** (b) **descriptor OSM (Fase A)** para que la calle real elija/oriente el template;
      (c) **sprites** (pipeline Blender al ángulo ¾ lockeado). Backlog: **crítico a la cabeza** como stat
      (zombies de 5 tiros + `critChance`) y tuning fino de combate.
    - ⬜ **Fase A del pivot (descriptor):** implementar `SceneDescriptor` (zona ya está + topología +
      name + oneway/lanes/surface/lit + lista de landmarks/POIs) como **lógica pura testeable**, y la
      **detección de topología** (cruces/ramas/ángulos), y el **selector** descriptor→template orientado.
      Ver fases en [18-scene-descriptor-templates.md](18-scene-descriptor-templates.md).
    - ⬜ **Assets (pipeline pre-render) + Flame:** modelar/bajar kit 3D CC0 (Kenney City Kit / Quaternius)
      → render orto a ángulo ¾ fijo en Blender (sombra horneada) → PNG/atlas → reemplazar las cajas
      placeholder por sprites; migrar a Flame con personajes **billboard**, reusando descriptor + template.
12. **Pathfinding del personaje a un punto (ascenso a L2):** mandar mi personaje por las **calles
    reales** a un destino (zombies/dungeon) con **tiempo según la distancia real**. Falta `RoadGraph`
    (grafo: intersecciones = nodos compartidos en OSM) + A\*; el "caminar" (`_advance`) ya existe.
    ~150 líneas, $0, local, reusa calles cacheadas. Detalle en
    [11-zombies-calles-cost.md](11-zombies-calles-cost.md).
13. **Anti-solapamiento de bases de vecinos:** si varios vecinos de una cuadra juegan, sus bases
    no deben pisarse. Preliminar: territorio **discreto por hexágono** (1 base/hex; si está ocupado
    → hex libre más cercano) + **clustering/LOD** para legibilidad visual. Ver
    [15-placement-bases-vecinos.md](15-placement-bases-vecinos.md). Confirmar en Etapa 2 (datos).
14. **Modelo de BD de hexágonos (clave para Etapa 2):** NO se pre-puebla el planeta (miles de
    millones de hexágonos). **Generación lazy**: hex ausente = "sin explorar" (default gratis); se
    **materializa** al interactuar, sembrando contenido **determinista por `hexId` (H3)** + datos
    OSM. BD sparse (solo lo jugado), mismo patrón que calles/tiles. **Dificultad = GRADIENTE
    determinista** (no random): cerca del spawn/urbano = fácil, lejos/descampado = difícil
    (risk-reward, sale del OSM). **Onboarding seguro:** se nace sin base, solo personaje, en safe
    zone de baja dificultad; se empieza explorando. Ver
    [16-modelo-hexagonos-bd.md](16-modelo-hexagonos-bd.md).

**Recomendado para arrancar la próxima sesión:** cerrar la **Etapa 2 (modelo de datos)** o
**implementar el modelo de economía nuevo en el prototipo** (lo que tenga más ganas). La
arquitectura por capas ya deja un lugar claro para ambos: el modelo de datos extiende
`domain/models/` y la economía nueva entra en `TerritoryRepository`.

---

## 🔁 Flujo de git
Repo: `https://github.com/FDany90/map-game` · rama `main`.
Para subir cambios: `git add -A` → `git commit -m "..."` → `git push`.
