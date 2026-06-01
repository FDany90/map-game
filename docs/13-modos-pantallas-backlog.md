# Backlog de modos de juego y pantallas

> Estado: **ideas / backlog (no decidido)** · 2026-05-30
> Documento vivo para no perder ideas de modos/pantallas. Cuando una se confirme, integrarla al
> [GDD (02-game-design)](02-game-design.md) y/o al [roadmap (00)](00-roadmap.md).
> Relacionado: [03-architecture.md](03-architecture.md) · [05-economia.md](05-economia.md) ·
> [12-building-extrusion.md](12-building-extrusion.md).

## Mapa de navegación (idea)
```
            ┌──────────────┐
            │     MENÚ      │
            └──────┬───────┘
       ┌───────────┼───────────┬───────────────┐
       ▼           ▼           ▼               ▼
   MODO BASE   MODO MAPA   EXPLORACIÓN     MODO DUNGEON
  (local)      (macro)      (GPS vivo)     (instanciado)
```

## Bandas de zoom por modo (DECIDIDO 2026-05-31)

Para controlar el costo de tiles (objetivo **≤100-200 requests/jugador/mes**), el juego usa
**bandas de zoom discretas por modo** en vez de zoom libre 3→20. Ver
[08-cost-analysis-tiles.md](08-cost-analysis-tiles.md) (sección "Diseño para un presupuesto
objetivo").

| Modo | Zoom | Área | Qué se ve |
|---|---|---|---|
| **Base local** | **z18** (cap actual) | tu barrio (acotado) | hexágonos, base, zombies, edificios |
| **Mapa-ciudad** (exploración NO-GPS) | **z11-12** | tu ciudad/metro (bbox) | **iconos** del backend: clanes, boss, dungeons, POIs |
| **País / región** | **z4-7** | macro | regiones por clan, ranking |

- **Sin z13-17 de roam libre** → se salta entre LODs, no hay zoom continuo.
- **`maxZoom` capeado a 18** en `AppConfig` (era 20).
- Iconos = backend → $0 de tiles; solo paga el fondo de mapa (barato a z bajo).

## Pantallas / modos

### 1. Menú (principal)
- Punto de entrada: jugar (entra a Base), acceso a Mapa / Exploración / Dungeon, ranking, ajustes.
- *Pendiente:* definir qué se muestra al abrir (¿directo a Base, o menú?).

### 2. Modo Base (refina el modo actual del prototipo)
- **Cargar la base del jugador + la zona cercana.**
- **No permitir alejar el zoom demasiado** (limitar zoom-out) → mantener el foco local.
- *Por qué:* el núcleo es jugar desde casa; acotar el área mantiene el foco, baja el costo de
  tiles (menos área = menos requests, ver [08-cost-analysis-tiles.md](08-cost-analysis-tiles.md))
  y evita que el Modo Base se "convierta" en el Modo Mapa.
- *Técnico:* setear `maxZoom`/`minZoom` y posiblemente `cameraConstraint`/bounds alrededor de la base.

### 3. Modo Mapa (vista macro / estratégica)
- **Cargar mapa de país, provincia o mundo**, con **diferentes niveles** (zoom-tiers).
- **Mostrar clanes dominantes** por región (quién controla qué territorio a gran escala).
- **Menú de ranking** (clanes, jugadores, territorios), etc.
- *Por qué:* da la capa "política/social" y la sensación de guerra territorial a gran escala.
- *Técnico:* NO mostrar hexágonos individuales acá → mostrar **agregados** (regiones coloreadas
  por clan). Depende fuerte de **LOD** (abajo) y del **backend** (territorio agregado por región).
  Atención al costo de tiles a escala país/mundo → caché y niveles de zoom acotados.

### 4. Modo Exploración (ya en diseño — Etapa 7)
- GPS en vivo + combate activo + gate de **combustible** ("explorar multiplica, no reemplaza").
- Ver [02-game-design.md](02-game-design.md) / [05-economia.md](05-economia.md).
- *Pendiente:* anti-spoofing de GPS (solo en este modo).

### 5. Modo Dungeon (instanciado)
- PvE instanciado / encuentros especiales fuera del mapa abierto (a definir: ¿generado,
  por evento, ligado a un hexágono "oscuro" especial?).
- *Pendiente:* definir el loop, recompensas y cómo se entra (desde Base/Mapa/Exploración).

## Pendiente técnico transversal

### LOD (Level of Detail) — mostrar/ocultar elementos por nivel
- Según el **zoom/nivel**, mostrar u ocultar elementos: hexágonos, zombies, edificios, labels,
  clanes, agregados regionales.
- *Por qué:* clave para **performance/batería** (no dibujar miles de cosas) y para que **Modo
  Mapa** muestre agregados (clanes) en vez de hexágonos individuales.
- *Ejemplos:* zoom alto (Base) → hexágonos + zombies + edificios; zoom medio → solo territorio
  propio/vecino; zoom bajo (Mapa) → regiones por clan, sin detalle fino.
- *Conexión:* se cruza con [12-building-extrusion.md](12-building-extrusion.md) (cuándo dibujar
  edificios) y con el costo de tiles por zoom-tier.

## Para integrar después
Cuando se confirmen, estos modos definen pantallas/navegación reales → llevar al GDD (02) y, si
implican etapas, al roadmap (00). Hoy quedan como **backlog**.
