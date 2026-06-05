# Amenazas en el mapa: iconos → popup → Atacar (ADR 0007)

> Estado: v0.1 — Slice A implementado y verificado (2026-06-04)
> Documento vivo. Cómo se ofrecen las **zonas de combate** sobre el mapa: cálculo
> determinista, sistema de iconos extensible, popup de detalle y entrada al combate.
> Relacionado: [ADR 0007](decisions/0007-estrategia-visual-mapa-iconos-escenas-isometricas.md) ·
> [16-modelo-hexagonos-bd.md](16-modelo-hexagonos-bd.md) (gradiente de dificultad) ·
> [13-modos-pantallas-backlog.md](13-modos-pantallas-backlog.md) (LOD).

## La idea
Sobre el mapa real se muestran **iconos de amenaza** (grupo de zombies, y a futuro
boss/dungeon/base). Al tocar uno: **popup (bottom sheet)** con el detalle (dificultad,
tipos de enemigos, cantidad) y un botón **"Atacar"** que carga la **escena de combate**.

## Cómo se calcula una "zona de combate" (sin BD, determinista)
Siguiendo el doc 16: **no se guarda nada**. Dada el área visible, para cada celda de una
grilla (hoy lat/lng simple; H3 en Etapa 2) un **hash determinista del id de celda** decide:
- **si hay** amenaza (sparse: `_spawnPct` ≈ 18% de las celdas),
- **dónde** (jitter determinista dentro de la celda),
- **qué dificultad** = **gradiente** `f(distancia al spawn) + textura ±1 por celda`
  (1 cerca/fácil … 5 lejos/difícil; a futuro pesar también densidad urbana OSM),
- **qué composición** de enemigos (más difícil = más y peores tipos).

→ Mismo lugar = misma amenaza para todos, **calculable sin almacenar nada** (igual que
tiles y calles). Vive en `data/services/threat_service.dart` (puro, testeable).

## Sistema de iconos (extensible a varios tipos)
Un solo modelo + un mapa `kind → icono`, así sumar "boss" = una línea:
- `domain/models/map_marker.dart`: `MapMarker { id, position, kind, difficulty, enemies }`
  con `MarkerKind { zombieGroup, boss, dungeon, base }` (cada uno con su emoji/label) y
  `EnemyGroup { type, count }`.
- `ui/features/map/views/widgets/threat_widgets.dart`: `ThreatMarker` (icono tappable, glyph
  y color salen del marker → sirve para cualquier kind) + `ThreatDetailSheet` (el popup) +
  `difficultyColor` (1 verde → 5 rojo, lenguaje visual compartido icono/popup).
- `MarkerLayer` de flutter_map en `map_screen.dart`; tap → `_showThreatSheet` →
  `showModalBottomSheet`; "Atacar" → `CombatPlayScreen`.
- El ViewModel (`MapViewModel`) expone `threats` y los **regenera al mover la cámara** más
  de una celda (deterministas → recalcular es barato y estable).

## Estado: Slice A (HECHO 2026-06-04)
**Vertical de un solo tipo (`zombieGroup`):** icono en el mapa (coloreado por dificultad, con
badge "Niv N") → bottom sheet (dificultad en pips, tipos de enemigos y cantidad) → "Atacar"
carga el combate **actual** (`residential.block` fijo). Verificado en emulador end-to-end;
gradiente visible (verde en el centro/spawn → rojo en los bordes). 4 tests de `ThreatService`
(determinismo + gradiente + composición).

## Backlog (próximas iteraciones)
- **B — la dificultad maneja el combate:** `CombatConfig` derivado de la amenaza
  (`targetKills`/`zombieHp`/ritmo) que `CombatGame` recibe en vez de constantes. Hoy la
  dificultad del popup es **informativa**.
- **C — boss/dungeon:** sumar los `MarkerKind` con su icono y variante de popup (varios iconos
  en pantalla). El modelo ya lo soporta.
- **LOD / clustering:** a zoom ciudad los iconos se amontonan → agrupar o mostrar solo los
  notables + contador (doc 13). Hoy se renderizan todos.
- **Solo amenazas cercanas (visibilidad acotada) — pedido 2026-06-04:** **no mostrar todos** los
  iconos posibles, solo los dentro de un **radio de la base/posición** del jugador (niebla de
  guerra, doc 16). Las lejanas no se ven hasta acercarse / explorar.
- **Atacar = recorrido, no instantáneo — pedido 2026-06-04:** una amenaza no se ataca "de una";
  el personaje **viaja** hasta ahí con **distancia (km) y tiempo reales según la ruta** (conecta
  con [11-zombies-calles-cost.md](11-zombies-calles-cost.md): `RoadGraph` + A\*, "tiempo según la
  distancia real"). El botón pasaría de "Atacar" a algo como "Ir (≈X km · Y min)".
- **Camino limpio — pedido 2026-06-04:** para llegar/atacar, la **ruta tiene que estar despejada**
  (amenazas/territorio oscuro intermedios limpiados antes) → conecta con "limpiar antes de
  reclamar" ([05-economia.md](05-economia.md)) y el control territorial.
- **Densidad urbana OSM** en el gradiente de dificultad (doc 16) y **H3** como id de celda.
- **POI real** en el nombre de la amenaza ("la esquina de Coto") desde el OSM.
