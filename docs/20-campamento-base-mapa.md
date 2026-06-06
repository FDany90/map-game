# Campamento y Base en el mapa (construcción + anclaje + proximidad de ataque)

> Estado: v1 — Slice 1 implementado 2026-06-05 · Documento vivo.
> Relacionado: [16-modelo-hexagonos-bd.md](16-modelo-hexagonos-bd.md) (onboarding "nacés sin base",
> gradiente) · [15-placement-bases-vecinos.md](15-placement-bases-vecinos.md) (1 base por hex) ·
> [19-mapa-amenazas.md](19-mapa-amenazas.md) (amenazas → atacar) · [05-economia.md](05-economia.md).

## El problema / la idea
Para atacar un grupo de zombies el jugador debería estar **cerca de su base** o **ver su posición
actual (GPS)**. Pero **al nacer no hay base** (doc 16): primero hay que **farmear** recursos. Y hay
que **evitar que la gente funde bases en cualquier lado** — preferentemente la base se construye
**donde uno vive / juega la mayor parte del tiempo**.

## Diseño: progresión Sin base → Campamento → Base
| | **Campamento** ⛺ | **Base permanente** 🛡️ |
|---|---|---|
| Costo | bajo (`campCost` = 20) | alto (`baseCost` = 150) — hay que farmear |
| Dónde se pone | **en cualquier lado** (tocás el mapa) | **solo en tu posición actual** (presencia física) |
| Permanencia | temporal, **movible** (recolocar y volver a pagar) | **permanente** (mover = acción aparte y costosa, futuro) |
| Confirmación | no | **sí, fuerte** ("es permanente, elegí bien") |
| Unidad | un punto | anclada a un **hexágono** (`hexId`, doc 15) |

1. **Nacés con tu personaje, sin base**, en safe zone (doc 16).
2. **Farmeás** (matás amenazas cercanas / reclamás hexágonos que producen) → suministros.
3. Con poco esfuerzo: **Campamento** — primer refugio, colocable casi en cualquier lado, movible.
4. Con mucho farmeo: **Base permanente** — anclada, con confirmación, pensada para donde vivís.

## Anti-abuso (evitar bases en cualquier lado) — DECIDIDO 2026-06-05
**La base permanente solo se funda estando físicamente ahí (regla de presencia / GPS).** No se
puede fundar a control remoto tocando un punto lejano del mapa: para fundarla en otro lado, el
jugador **primero tiene que moverse hasta ahí**. El campamento sí es libre (es lo "barato y
temporal"); la fricción de anclaje aplica solo a la base real.

- **GPS simulado por ahora** (decisión 2026-06-05): la "posición del jugador" es un marker movible
  (lo movés tocando el mapa = "caminar"). En **Etapa 7** se reemplaza por el **GPS real** del
  dispositivo **sin cambiar la regla** (`foundBase(playerPosition:…)` ya recibe la posición; solo
  cambia la fuente del dato).
- Refuerzos de anti-abuso: **costo alto** (hay que farmear) + **confirmación fuerte** + **1 base por
  hex** (doc 15) + permanencia (mover = caro).

## Dos formas de atacar (proximidad)
Una amenaza es **atacable** solo si está dentro del **radio de ataque** (`attackRadiusMeters` = 300 m)
de **algún anclaje**: tu **posición** (GPS), tu **campamento** o tu **base**.
- **Modo Base** (asincrónico, desde casa): atacás lo que cae cerca de tu base/campamento.
- **Modo Exploración** (GPS): atacás lo que cae cerca de tu posición real.
- **Fuera de todos los radios** → "Atacar" se **deshabilita** con el motivo + la distancia. (Futuro:
  **viajar** con km+tiempo reales hasta la amenaza, doc 19; limpiar el camino, doc 05.)

El radio se dibuja en el mapa (`CircleLayer`) alrededor de cada anclaje → el jugador **ve** dónde
puede atacar (UI diegética, skill `mobile-game-ui-design`).

## Implementación (Slice 1 — 2026-06-05)
**Dominio** (puro, testeable):
- `domain/models/outpost.dart` — `OutpostKind {camp, base}` + `Outpost {kind, position, hexId?}`.
- `domain/models/build_result.dart` — `BuildResult {success, notEnoughSupplies, alreadyHasBase}`.
- `MarkerKind` sumó `camp` (⛺).

**Data:** `TerritoryRepository` (fuente única de verdad) sumó `camp`/`base`, costos
(`campCost`/`baseCost`), `placeCamp(pos)`, `foundBase(playerPosition:, hexId:)` y limpieza en
`reset()`. 7 tests nuevos (`test/outpost_test.dart`).

**ViewModel:** `playerPosition` (GPS simulado, nace en el spawn), `movePlayerTo`, `placeCamp`,
`foundBaseAtPlayer` (ancla al hex más cercano a la posición), `attackAnchors`, `canAttack(threat)`,
`distanceToNearestAnchor`.

**UI** (`map_screen` + `widgets/outpost_widgets.dart`):
- **FAB "Construir"** → bottom sheet con: *Mover mi ubicación* / *Poner-Mover campamento* / *Fundar
  base*. Cada opción muestra el **costo** y se **deshabilita con motivo** si no alcanza / ya hay base.
- **Modo colocación:** al elegir mover ubicación o poner campamento, un **banner** pide tocar el mapa;
  el siguiente toque ubica (en vez de reclamar hex). Cancelable.
- **Fundar base** → **diálogo de confirmación fuerte** → funda en la posición actual.
- **Markers:** posición del jugador (punto azul), campamento ⛺, base 🛡️.
- **`CircleLayer`** del radio de ataque por anclaje.
- **Popup de amenaza** (`ThreatDetailSheet`): "Atacar" habilitado solo si `canAttack`; si no, hint con
  la distancia.
- **Chip de estado:** Sin base → Campamento → Base.

## Pendiente / próximas iteraciones
- **Farm loop completo:** que **ganar un combate** sume suministros al mapa (hoy el combate tiene su
  economía local; falta el retorno `CombatPlayScreen` → `TerritoryRepository`). Es lo que cierra
  "matar zombies = farmear para fundar la base".
- **Mover la base** (acción costosa) — hoy `foundBase` falla si ya hay base.
- **Snap real al centro del hex** (hoy la base guarda la posición del jugador + `hexId` de anclaje).
- **GPS real** (Etapa 7) reemplaza la posición simulada.
- **Solo amenazas cercanas** (niebla de guerra, doc 19): hoy se muestran todas; atacar ya está acotado
  por proximidad, falta acotar también la **visibilidad**.
- **Costos/balance** (`campCost`/`baseCost`/`attackRadiusMeters`) a tunear con play-test.
