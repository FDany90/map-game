# Economía (spec)

> Estado: borrador v0.1 · Etapa 2
> Documento vivo. Los números son provisionales; lo fijo es el **modelo**.
> Relacionado con [02-diseño de juego](02-game-design.md) y los hallazgos de
> [10-investigación](10-investigacion-hallazgos.md).

## Principio rector: economía LIMITADA y ACTIVA (anti-idle)

> **El territorio NO produce para siempre.** Looteás recursos (finito), y el ingreso
> renovable viene de la **actividad** — matar zombies y explorar.

Esto diferencia a MAP del modelo idle/4X clásico ("dejar corriendo y juntar"): la economía
**obliga a interactuar** (defender, expandir, explorar) en vez de premiar la pasividad.
Al mismo tiempo, la defensa automática mantiene un goteo offline → sigue siendo amigable
con el jugador casual / "desde casa".

## Faucets (de dónde entran los recursos)

| Fuente | Tipo | Detalle |
|---|---|---|
| **Loot al limpiar/reclamar** un hexágono | 💥 Burst finito | Saqueás esa zona una vez |
| **Defensa (matar zombies en tu territorio)** | 🔁 Goteo renovable | Los zombies dejan drops; las torretas lo hacen solas → **funciona offline** |
| **Exploración** | 🗺️ Crecimiento | Recursos raros/grandes lejos; cómo crecés cuando tu zona se agota |
| **Hexágonos agotados** (looteados, sin zombies) | ⬇️ Casi nada | Empujan a expandir / explorar / defender |

## Propiedad emergente: el territorio oscuro es AMENAZA + GRANJA

El territorio oscuro (infestado) genera zombies. Como matar zombies da recursos:
- Querés tener **algo** de oscuro cerca → para farmear matando zombies.
- Pero **demasiado** oscuro te desborda.
- → **El jugador gestiona ese equilibrio** (riesgo vs ingreso). Diseño emergente que nace de
  unir "limpiar para reclamar" + "zombies dan recursos".

## Recursos (3)

| Recurso | Rol | Cómo se consigue | Se consume en |
|---|---|---|---|
| **Materiales** | Finito/activo — **el que obliga a explorar** | Loot de territorio + drops de zombies | Construir, mejorar, reclamar |
| **Energía** | Renovable/operativo — mantiene la base viva | **Generadores** (hasta un tope); NO se lootea | Operar defensas y edificios |
| **Combustible** | Gate de exploración | Producción **lenta** / loot ocasional | Salir en Modo Exploración |

Decisiones de diseño fijadas:
- **Energía = 100% renovable de generadores** (no looteable) → la base **siempre puede
  operar**, pero la riqueza/expansión depende de los Materiales activos.
- **Combustible = producción lenta** → cada salida de exploración es una **decisión** con
  costo real.

## Sinks (en qué se gastan)

- **Reclamar un hexágono** (Materiales) — requiere antes **limpiar** si está oscuro.
- **Construir / mejorar edificios** (Materiales).
- **Operar defensas** (Energía por turno/tiempo).
- **Reparar** tras ataques (Materiales).
- **Explorar** (Combustible).

## Edificios (sobre hexágonos reclamados)

| Edificio | Hace |
|---|---|
| **Base / Ayuntamiento** | Centro; su nivel limita todo lo demás |
| **Generador** | Produce Energía (hasta un tope) |
| **Almacén** | Sube el tope de almacenamiento |
| **Torreta** | Defensa (consume Energía); sus kills generan drops de Materiales |
| **Muro** | Defensa pasiva |

## Territorio oscuro y expansión

- Los hexágonos sin reclamar **decaen a oscuro** y generan amenaza/zombies.
- Para reclamar un hexágono oscuro hay que **limpiarlo primero** (combate/costo) →
  conecta **combate ↔ economía ↔ expansión** en un solo sistema.
- Limpiar/reclamar da un **loot inicial** (burst finito).
- Una vez looteado y "domado" (sin zombies), el hexágono rinde poco → hay que buscar
  ingreso en otro lado (más zombies, más territorio, exploración).

## Palancas de pacing (que lo hacen juego, no idle)

1. **Loot finito** por territorio → empuja a la expansión/exploración continua.
2. **Tope de almacenamiento** (Almacén lo sube) → te obliga a gastar y a volver; la
   producción/goteo offline llena **hasta el tope** (casual-friendly).
3. **Ingreso ligado a actividad** (matar zombies, explorar) → premia jugar, no esperar.

## Casual-friendly (de la investigación)

- Goteo de defensa **offline hasta el tope** (no perdés por no estar).
- Escudos / "guard" para la base (ver [10-investigación](10-investigacion-hallazgos.md)).
- **Nada de poder pago** — todo el poder se gana jugando.

## Pendientes de balance (a definir con números)

- Tasas exactas: loot por hexágono, drop por zombie, producción de generadores/combustible.
- Curva de costo de reclamar/mejorar.
- Velocidad de decaimiento a oscuro y de respawn de zombies (la "perilla de dificultad").
- Cuánto rinde un hexágono "domado" (¿cero, o un mínimo?).
- Topes de almacenamiento por nivel de Almacén.
- Balance amenaza/granja del territorio oscuro (cuánto oscuro es "óptimo" farmear).
