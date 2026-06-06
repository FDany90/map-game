# Stats mejorables (sistema de progresión)

> Estado: brainstorm / backlog · 2026-06-05 · Documento vivo (notas para el futuro, sin implementar).
> Relacionado: [20-campamento-base-mapa.md](20-campamento-base-mapa.md) (rango de ataque, base/camp) ·
> [19-mapa-amenazas.md](19-mapa-amenazas.md) (amenazas, viaje) · [05-economia.md](05-economia.md)
> (recursos, anti-idle) · [16-modelo-hexagonos-bd.md](16-modelo-hexagonos-bd.md) (gradiente de
> dificultad) · [08-cost-analysis-tiles.md](08-cost-analysis-tiles.md) (presupuesto de requests) ·
> HANDOFF (nota "sistema de estadísticas del personaje" + "crítico a la cabeza").

## Idea
A medida que el jugador progresa, varias cosas del mapa deberían **mejorar** (stats con niveles), no
ser constantes fijas. **Disparador:** el **rango de ataque** de grupos de zombies en el mapa (hoy
`MapViewModel.attackRadiusMeters = 300`, una `const`) debería ser un **stat mejorable**. Este doc
generaliza eso a un catálogo de stats mejorables para diseñarlas juntas y coherentes.

## Stat semilla: Rango de ataque 🎯
- **Qué hace:** radio dentro del cual podés atacar una amenaza desde un anclaje (posición / campamento
  / base). Más rango = atacás amenazas más lejos **sin moverte** (doc 20).
- **Cómo mejora (ideas):** nivel de base, investigación, equipo (mira/drone de reconocimiento),
  consumible temporal.
- **Interacciones / cuidados:**
  - **La base mejora más que el campamento** (incentiva fundar base donde vivís — refuerza el doc 20).
  - **Anti-idle (doc 05):** si el rango crece demasiado, atacás todo el barrio desde el sillón → se
    pierde el incentivo a explorar. Mantener el rango **acotado** y que **explorar (GPS) siempre
    alcance más lejos** que quedarse en casa.
  - **NO afecta el presupuesto de tiles (doc 08):** el rango opera sobre **markers del backend**, no
    sobre tiles del mapa. Subirlo no dispara requests de MapTiler. (Ojo distinto: el **radio de
    visión**, si algún día carga más tiles, sí tendría costo — ver abajo.)

## Catálogo de stats mejorables (por categoría)

### A. Alcance / radios (capa mapa)
| Stat | Qué mejora | Notas / cuidado |
|---|---|---|
| **Rango de ataque** 🎯 | atacar amenazas más lejos sin moverte | el stat semilla; acotar por anti-idle |
| **Radio de visión / niebla de guerra** | ver amenazas/POIs más lejos de tus anclajes | hoy se ven todas; a futuro acotar (doc 19) y volverlo stat |
| **Radio de recolección pasiva** | área desde la que la base "limpia"/farmea sola | conecta con producción y territorio oscuro (doc 05) |
| **Autonomía de exploración** | distancia máxima útil desde la base (Etapa 7, GPS) | gate de combustible; explorar > quedarse |

### B. Base y campamento (construcción)
| Stat | Qué mejora | Notas |
|---|---|---|
| **Nivel de base (tier)** | desbloquea slots/edificios, sube otros stats | eje central de progresión |
| **Capacidad de almacenamiento** | tope de recursos acumulables | empuja a gastar/activar (anti-idle) |
| **Producción por hexágono** | `yieldPerHexPerSecond` mejorable | economía (doc 05) |
| **Nº de campamentos simultáneos** | de 1 a varios | logística de farmeo a distancia |
| **Costo/tiempo de mover la base** | reubicar más barato | hoy la base es casi inamovible (doc 20) |
| **Defensa de la base** (HP/torretas) | aguantar hordas / PvP (futuro) | combate diferido (GDD) |

### C. Combate (stats del personaje, se proyectan al mapa)
| Stat | Qué mejora | Notas |
|---|---|---|
| **Daño / cadencia / cargador / recarga** | matar más rápido | ya existen en combate Flame; volverlas mejorables |
| **Crítico a la cabeza** (`critChance`) | one-shot a la cabeza | **ya anotado** en HANDOFF (zombies de 5 tiros + crit) |
| **Vida máxima / regeneración / curación** | sobrevivir más | hoy HP fijo 100 |
| **Velocidad de movimiento** | kitear mejor | skill principal hoy |

### D. Exploración / viaje (Etapa 7, GPS)
| Stat | Qué mejora | Notas |
|---|---|---|
| **Velocidad de viaje** | llegar antes a una amenaza | "atacar = recorrido" km+tiempo (doc 19) |
| **Eficiencia de combustible** | explorar más con menos | gate de combustible (GDD) |
| **Capacidad de carga (loot)** | traer más botín por incursión | risk/reward del gradiente (doc 16) |
| **Resistencia / stamina** | aguantar recorridos largos | |

### E. Economía / logística
| Stat | Qué mejora | Notas |
|---|---|---|
| **Costo de reclamar hexágono** | expandir territorio más barato | hoy fijo 10 |
| **Velocidad de construcción/mejora** | colas más rápidas | combate/construcción diferida |
| **Tasa de drop / recursos por kill** | farmear más por amenaza | cierra el loop farmeo→base (doc 20) |

## Vectores de mejora (CÓMO suben las stats)
Definir 1-2 al principio, no todos:
1. **Nivel de base / tier** — la espina dorsal (sube radios, almacenamiento, producción).
2. **Árbol de investigación / tecnología** — elegir en qué especializarte (ataque vs economía vs explo).
3. **Equipo / gear** — ítems que dropean y suben stats del personaje (combate/exploración).
4. **Consumibles temporales** — buffs por tiempo (ej. "drone de reconocimiento": +rango 1 h).
5. **Perks del personaje** — progresión RPG (nivel de jugador).

## Cuidados de diseño (transversales)
- **Anti-idle (doc 05):** ningún stat debería permitir "ganar sin jugar". Los radios acotados; explorar
  siempre rinde más que quedarse en casa.
- **Curva de dificultad (gradiente, doc 16):** las stats del jugador suben **a la par** que se anima a
  ir más lejos (más difícil, mejor botín). No romper el risk/reward.
- **Presupuesto de tiles (doc 08):** distinguir stats que tocan **markers del backend** ($0 en
  MapTiler) de las que podrían cargar **más tiles** (radio de visión amplio a más zoom). Las primeras
  son libres; las segundas, vigilar.
- **Base (asincrónico) vs Personaje (exploración):** separar el árbol de stats de la **base** (juego
  desde casa) del de **personaje** (combate/GPS). Son los dos modos del juego (doc 02).

## Dónde vive (cuando se implemente)
- Modelo puro `domain/models/player_stats.dart` (testeable), leído por `TerritoryRepository`/`MapViewModel`.
- **Primer paso natural:** migrar `MapViewModel.attackRadiusMeters` de `const` a un campo de
  `PlayerStats` (sin cambiar la regla de proximidad del doc 20). Es el stat semilla.
- Producción (Etapa 6): las stats persistidas por jugador en el backend.

## Decisiones abiertas
- ¿Cuántos vectores de mejora al inicio? (recomendado: empezar con **nivel de base** solo.)
- Valores/curvas (rango base 300 m → ¿hasta cuánto? con qué costo por nivel).
- ¿El campamento mejora algo o es siempre el escalón "barato y fijo"?
- ¿Stats globales del jugador o por-asentamiento (cada base con su nivel)?
