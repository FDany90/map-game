# Persistencia del save + plan económico (que se sienta el avance)

> Estado: decisiones tomadas 2026-06-05 · plan por fases · Documento vivo.
> Relacionado: [05-economia.md](05-economia.md) (anti-idle, loot finito, 3 recursos) ·
> [20-campamento-base-mapa.md](20-campamento-base-mapa.md) (camp/base, loop combate→recursos) ·
> [21-stats-mejorables.md](21-stats-mejorables.md) (stats) · [16-modelo-hexagonos-bd.md](16-modelo-hexagonos-bd.md)
> (BD sparse, fachada del repo) · [08-cost-analysis-tiles.md](08-cost-analysis-tiles.md) (patrón JSON
> en Application Support, ya usado por el monitor de requests).

## El problema
Todo el estado de juego vive **en memoria** (`TerritoryRepository`): suministros, hexágonos
reclamados, campamento, base, posición. **Cada corrida (`flutter run`) lo resetea** → no se siente
avance. Hay que **persistir el save del jugador** localmente.

## Qué se guarda (el "save")
Un único snapshot local del jugador:
- recursos (hoy `supplies`; futuro: 3 recursos de doc 05)
- hexágonos reclamados (set de ids)
- campamento (posición) y base (posición + `hexId`)
- **`lastSeen`** (timestamp epoch) — para la economía offline
- `version` (para migraciones futuras)
- futuro: `PlayerStats` (doc 21), nivel de base, inventario

## DECISIÓN 1 — Producción offline: **catch-up acotado** (2026-06-05)
"Que se sienta el avance" **NO** es "me hice rico durmiendo", sino "mi territorio/base/recursos siguen
ahí y mejores". Pero al reabrir se premia un poco:
- Al cargar, se calcula `elapsed = now − lastSeen` y se aplica producción por **`min(elapsed, tope)`**.
- **Tope inicial: 60 min** (tunable). Más allá del tope, el tiempo offline **no** rinde → empuja a
  jugar activo (respeta el anti-idle del doc 05). Se aplica **una sola vez** al cargar.
- Lo **permanente** (territorio, base, recursos en banco, stats) es lo que de verdad acumula el avance;
  el catch-up es solo un mimo al volver.

## DECISIÓN 2 — Avanzar **persistir primero** (2026-06-05)
Pasos chicos y jugables, no todo junto:

### Paso 1 — Persistencia del save ✅ HECHO (2026-06-05) · economía simple de hoy
- `domain/models/player_save.dart` — snapshot serializable (`toJson`/`fromJson`, `version`). Modelo puro.
- `data/services/save_store.dart` — carga/guarda el JSON en **Application Support** (`player_save.json`),
  **debounced** (mismo patrón que el monitor de requests). IO aislado acá.
- `TerritoryRepository` gana `toSave()` y `restore(PlayerSave)` **puros y testeables** (sin IO). El
  store y el ciclo de vida quedan **afuera** del repo → el repo sigue siendo fuente única de verdad y
  testeable, y es el **seam** que en Etapa 6 se reemplaza por el backend sin tocar UI/VM (doc 16).
- **Wiring:** `main()` carga el save → `repo.restore(save)` → aplica el catch-up acotado (`produce`
  por el tiempo capeado) → corre la app. Se guarda **debounced en cada acción** + **al pausar la app**
  (`AppLifecycleState.paused`). El `reset` también borra el save.
- Tests: roundtrip `PlayerSave` JSON, roundtrip `toSave/restore` del repo, catch-up capeado.

### Paso 2 — Economía nueva (doc 05)
- **Loot finito** que se agota (el motor anti-idle) + **ingreso por actividad**.
- **Cerrar el loop combate→recursos** (pendiente del doc 20): ganar el combate suma recursos al mapa.
- Pasar de `supplies` único a **3 recursos** (Materiales / Energía / Combustible).

### Paso 3 — Etapa 2/6: modelo de datos formal + backend
- El `SaveStore` local pasa a ser la **fachada** del BaaS (Supabase/Firebase); tabla `hexagons` sparse
  (doc 16). Reconciliación, caché local, multijugador.

> **Verificado en emulador (2026-06-05):** reclamar hexes → se escribe `player_save.json`
> (`{supplies, claimedHexIds:[83,70], version:1, ...}`); forzar cierre + relanzar → arranca con los
> 2 hexes y suministros >50 (no fresco), con el catch-up offline sumado. Write/Load/Catch-up OK.
>
> ⚠️ **Lección 1 (bug encontrado y arreglado):** el debounce que **cancela y reinicia** el timer en
> cada llamada **nunca escribe** si la fuente es de alta frecuencia (el tick de economía, 4×/s,
> reseteaba el timer de 2 s antes de que disparara). Fix: **coalescer sin resetear**
> (`_saveTimer ??= Timer(...)`, guardando el último estado). Mismo bug latente tenía el monitor de
> requests (doc 08) → arreglado igual.
>
> ⚠️ **Lección 2 (2026-06-05) — guardar al cerrar debe ser SINCRÓNICO:** el guardado al cerrar era
> async (`writeAsString`). Con **Home** el proceso sigue vivo y completa → persiste; pero el **botón
> rojo de cerrar** (`SystemNavigator.pop()`) **finaliza la actividad al instante** y el write async no
> llegaba a terminar → se perdía lo último (se sentía como "reseteó"). Fix: `flushSync`
> (`writeAsStringSync`) y, en el botón de cerrar, **guardar antes de `pop()`**. El JSON es chico → el
> costo del write bloqueante es despreciable y solo pasa en el cierre.

## Cuidados de diseño
- **Anti-idle (doc 05):** el catch-up capeado no debe volverse renta pasiva; el grueso del ingreso es
  actividad.
- **Migraciones:** `version` en el save desde el día 1 (cambiar el modelo no debe romper saves viejos
  → si la versión no coincide, migrar o resetear con aviso).
- **Robustez:** si el JSON está corrupto/ausente → arrancar como save nuevo (no crashear), igual que el
  monitor.
- **Repo puro:** la IO/persistencia/ciclo de vida vive en el store/wiring, no en `TerritoryRepository`
  (testeabilidad + seam de backend intacto).

## Decisiones abiertas (para cuando toque)
- Valor del **tope de catch-up** (60 min inicial) y si escala con el nivel de base (doc 21).
- ¿El save es por jugador único local hoy; cómo migra a multi-cuenta/backend?
- Momento exacto de pasar a 3 recursos (Paso 2) y cómo se mapean los `supplies` actuales.
