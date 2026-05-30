# 🟢 HANDOFF — Empezá acá para retomar

> Última actualización: **2026-05-30** (caché de tiles implementada)
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
| 5 Prototipo Modo Base | 🟡 (mapa + hexágonos + economía mínima andando) |
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

---

## 🎮 Estado del prototipo (`map_spike/`)
App Flutter que ya corre en emulador Android:
- Mapa **MapTiler oscuro** centrado en **Palermo, BA**.
- **Grilla de hexágonos** reclamables (tocar para reclamar; se pintan verde).
- **Mini-economía:** reclamar cuesta 10 suministros; cada hexágono produce +30/min; HUD en vivo.
- Controles de **zoom +/−** y label de zoom.
- **Caché de tiles en disco** (Hive vía `flutter_map_cache`): los tiles ya vistos se sirven
  localmente en vez de re-pedirse a MapTiler.
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
- ❌ Node.js (no hace falta)
- **Skills de Flutter** instaladas en `.claude/skills/` (arquitectura + fix-layout) →
  **requieren reiniciar Claude Code** para activarse.

### ⚠️ Gotchas operativos
- Si el emulador se lanza desde una **tarea en segundo plano**, se **cierra** al terminar la
  tarea. Lanzarlo **desacoplado** (`Start-Process` / call operator) o desde Android Studio.
- En el emulador, **pinch** = `Ctrl` + arrastrar; las letras del mapa se ven chicas porque
  el emulador se muestra al ~33% (en celular real se ve mejor; la solución de fondo es un
  estilo propio de MapTiler).

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
- [spike-01-maptiler-flutter.md](spike-01-maptiler-flutter.md) — guía del spike
- [decisions/](decisions/) — ADRs 0001-0006

---

## ⬜ Temas pendientes / próximos pasos (priorizados)
0. ✅ **HECHO (2026-05-30) — Caché de tiles en `map_spike`:** se agregó `flutter_map_cache`
   + `dio_cache_interceptor` + `HiveCacheStore` (persistente en disco, `getTemporaryDirectory`)
   al `TileLayer` (`CachedTileProvider`, `maxStale: 30 días`). `flutter analyze` limpio y test
   en verde. **Por qué:** sin caché cada pan/zoom recargaba tiles y quemaba requests de MapTiler
   (medido: **9.392 en un día** de testeo, ~9% del cupo Free de 100k/mes). Era la palanca #1 de
   costo. **Falta:** validar en emulador y, si se quiere, medir el ahorro real en el dashboard.
1. **Cerrar Etapa 2 — Modelo de datos** (`04-data-model.md`): entidades Hexágono, Base,
   Edificio, Recurso, Unidad y relaciones → prepara el backend.
2. **Implementar el nuevo modelo de economía en el prototipo:** loot **finito** que se agota
   + **drops de zombies** al morir + limpiar territorio oscuro antes de reclamar (sentir el
   anti-idle).
3. **Estilo propio en MapTiler Customize:** look apocalíptico + fuentes más grandes.
4. **Zombies caminando por las calles:** requiere el **grafo de calles** (OSM) + pathfinding
   (routing API o A\* local). Conecta con "monstruos sueltos por la calle".
5. **Segunda investigación** (huecos del informe): Ingress/portales, EVE/sovereignty,
   anti-ballena más allá de escudos, y **densidad mínima de jugadores por barrio** (el
   problema del mapa vacío).
6. **Nombre del juego:** el repo es `map-game`; el título comercial está **sin definir**.
   Candidatos: *Reclaim*, *Barrio Cero*, *MAP*, *Perímetro*.
7. **Backend/multiplayer (Etapa 6):** confirmar Supabase vs Firebase; diseñar sincronización
   del territorio.
8. **Modo Exploración (Etapa 7):** GPS en vivo + combate activo + gate de combustible.
9. **Reactivar las skills** de Flutter (reiniciar Claude Code).

**Recomendado para arrancar la próxima sesión:** cerrar la **Etapa 2 (modelo de datos)** o
**implementar el modelo de economía nuevo en el prototipo** (lo que tenga más ganas).

---

## 🔁 Flujo de git
Repo: `https://github.com/FDany90/map-game` · rama `main`.
Para subir cambios: `git add -A` → `git commit -m "..."` → `git push`.
