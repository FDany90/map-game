# Investigación profunda — Hallazgos

> Estado: v1.0 · investigación con fuentes verificadas (deep-research, 2026-05-29)
> Método: 5 ángulos de búsqueda → 22 fuentes → 90 claims extraídos → 25 verificados con
> votación adversarial (3 votos por claim) → 19 confirmados, 6 refutados.
> Complementa [09-referencias.md](09-referencias.md).

---

## 🎯 Titular: el nicho de MAP está VACÍO

**No existe hoy ningún juego de guerra territorial zombie SOCIAL sobre el mapa real del
propio jugador, jugable de forma asíncrona desde casa.**

- El **único** juego que recrea el barrio real del jugador con datos de **OpenStreetMap** es
  **Infection Free Zone** (RTS/city-builder zombie, Early Access 2024) — pero es
  **estrictamente single-player**: la amenaza "territorial" son NPCs raiders, no PvP ni
  alianzas. El propio dev declaró que "fue diseñado como single-player y va a seguir así".
- Los grandes 4X sociales (State of Survival, Rise of Kingdoms, Lords Mobile, Clash of
  Clans) usan **mapas ficticios**, no el mundo real.
- **Conclusión:** la capa **social** sobre el **mapa real** es terreno no ocupado → es el
  diferencial central de MAP.

Fuentes: [Steam IFZ](https://store.steampowered.com/app/1465460/Infection_Free_Zone/) ·
[ScreenRant](https://screenrant.com/infection-free-zone-steam-openstreetmap-irl-zombie-game/)

---

## 📊 Panorama competitivo (2024-2025)

- Los location-based games siguen siendo **comercialmente grandes pero hiperconcentrados**:
  Pokémon GO tuvo **>20M jugadores activos semanales** y **>$520M** en compras in-app en 2024.
- El siguiente título de Niantic (Monster Hunter Now) ganó **solo $86M** → un gap ~6x entre
  el #1 y el #2: **hay demanda probada pero pocos ganadores** (oportunidad para un enfoque
  diferenciado).
- En marzo 2025, Niantic **vendió su división de juegos a Scopely por $3.5B** (deal total $3.85B).

Fuentes: [TechCrunch](https://techcrunch.com/2025/03/12/pokemon-go-maker-niantic-is-selling-its-games-division-to-scopely-for-3-5b/)

---

## 🛡️ Mecánicas verificadas para copiar (el "jugar desde casa")

Todas verificadas con votación 3-0.

### 1. Protección al novato impausable, que se rompe con la agresión
- **State of Survival:** 7 días que **corren aunque no entres al juego**; se rompe si subís
  el Keep a nivel 5 **o atacás a un jugador**.
- **Clash of Clans:** escudo inicial de 3 días.
- **Patrón clave:** impausable (protege al ausente) + se rompe si el protegido ataca (evita
  el abuso de "atacar escudado").
- Fuentes: [DECA Games (oficial)](https://support.decagames.com/hc/en-us/articles/4422293195021-New-Players-Beginner-s-Protection) ·
  [Clash Fandom](https://clashofclans.fandom.com/wiki/Shield)

### 2. Escudo automático defensivo escalado al daño recibido
- **Clash of Clans:** tras ser atacado, escudo automático de **12h al 30% de destrucción**,
  y **12/14/16h** según 30%/60%/90% destruido.
- **Efecto:** al jugador dormido **no lo golpean en cadena**.
- Fuente: [Clash Fandom](https://clashofclans.fandom.com/wiki/Shield)

### 3. Escudos de paz comprables por niveles de duración
- **Rise of Kingdoms — Peace Shield:** 8h, 12h (700 gemas), 24h (1.000), 3 días (2.500),
  30 días (45.000), con **100% de protección** (no te pueden atacar ni espiar).
- **Matices:** las tropas marchando **fuera** de la ciudad NO quedan cubiertas; el escudo
  **cae al instante si tomás acción ofensiva**.
- Fuente: [RoK Fandom](https://riseofkingdoms.fandom.com/wiki/Items/Peace_Shield)

### 4. "Village Guard" — online simulado offline
- **Clash of Clans:** mientras el Village Guard está activo, **tu base actúa como si
  estuvieras online aunque cierres la app o te desconectes** → nadie te puede atacar.
- Aplicable directo a la "base hogar" de MAP.
- Fuente: [Clash Fandom](https://clashofclans.fandom.com/wiki/Shield)

### 5. Rally / Coalición para cooperación asíncrona
- **Lords Mobile:** varios jugadores atacan juntos; el Capitán fija una **ventana de unión
  de 5 min, 10 min, 1h u 8h**; los aliados despliegan tropas dentro de esa ventana, se
  agrupan en un Ejército de Coalición y atacan juntos al expirar el temporizador (hasta 30
  participantes).
- **La ventana de 8h permite participación escalonada (asíncrona)** de aliados en distintos
  husos horarios — clave para "jugar desde casa".
- Fuente: [Lords Mobile Fandom](https://lordsmobile.fandom.com/wiki/Rally)

### Síntesis anti-griefing (para un dev en solitario)
La combinación —protección de novato impausable + ruptura por agresión + escudo automático
escalado + escudos de paz + guard offline— crea **protección sistémica automatizada** que
limita el dominio de ballenas/veteranos sobre la "base hogar" del casual **sin requerir
moderación manual**. El patrón de oro: **todo escudo cae si el protegido ataca.**

---

## 💰 Monetización sin pay-to-win

### Qué EVITAR (esto ES pay-to-win, por definición)
Una compra es P2W si da una ventaja **inalcanzable jugando gratis**:
- Personajes o armas **solo comprables**.
- Sistemas **VIP** que dan espacio de inventario, moneda o facilidades.
- Contenido **exclusivo del battle pass de pago**.
→ Regla para MAP: **todo el PODER se obtiene gratis**; el pago es solo cosmética y
conveniencia que **no da poder**.
Fuente: [Game Developer (Josh Bycer)](https://www.gamedeveloper.com/business/classifying-pay-to-win-design-in-today-s-market)

### Qué ADOPTAR
- Los 4X líderes siguen dos caminos: (a) monetizar temprano sobre el "peak excitement", o
  (b) el **"long game"**: ganar confianza y engagement profundo antes de empujar al gasto.
  Para un dev solo que busca **comunidad sana**, el modelo "long game" (gameplay-first,
  menos ofertas, eventos de prestigio) es el más alineado y menos predatorio.
- Fuente: [Duamentes/AppMagic](https://www.duamentes.com/2025/10/13/how-to-break-into-4x-strategy-market/)

### 💡 Diferenciador: monetizar la UBICACIÓN (no el poder)
- **Pokémon GO vende localizaciones reales patrocinadas:** ~**$30/mes** por convertir un
  negocio en PokéStop estándar y ~**$60/mes** por un Gym premium (datos de 2019; existe
  además un modelo enterprise ~$0,50/visitante).
- MAP, al estar sobre el mapa real, puede **replicar esto (B2B local)** como ingreso que
  **no afecta el balance PvP** entre jugadores.
- Fuente: [Juego Studio](https://www.juegostudio.com/blog/pokemon-go-revenue)

---

## ⚠️ Caveats (lo honesto)

1. **Calidad de fuentes:** muchas mecánicas concretas (RoK, Lords Mobile, Clash) vienen de
   wikis Fandom y guías de comunidad (secundarias), corroboradas cruzadamente pero no
   siempre documentación oficial. State of Survival SÍ es documentación oficial (DECA).
2. **Datos sensibles al tiempo:** precios en gemas y los $30/$60 de PokéStops (2019) pueden
   haber cambiado; los revenue son estimaciones de Sensor Tower (no auditadas) y excluyen
   ventas web.
3. **Cobertura parcial:** NO se produjeron claims verificados sobre varios juegos del brief:
   **Ingress** (control de portales), **EVE Online** (sovereignty/nullsec), **Frostpunk**,
   **Travian/Tribal Wars**, **TWD: Survivors**, **Last Shelter**.
4. **Anti-ballena más allá de escudos** (matchmaking por poder, ligas/divisiones) quedó
   poco cubierto con evidencia verificada.

---

## ❌ Claims REFUTADOS (no son ciertos — tratar con cautela)

- **NO** es cierto que la protección de novato de **Travian** sea 5+3 días mutua.
- **NO** es cierto que **>50%** de los juegos F2P usen battle pass (no es el método más popular).
- **NO** está confirmado que el battle pass "no degrade la experiencia" como regla general.
- La definición de P2W como "pagar para acelerar el progreso" fue **refutada** (acelerar no
  es necesariamente P2W; lo es la ventaja **exclusiva** de pago).

---

## ❓ Preguntas abiertas (para profundizar después)

1. ¿Cómo resuelven **Ingress / Pokémon GO** el control y disputa de territorio sobre el
   mapa real (portales/gyms, links, campos) y qué es trasladable a "guerra desde casa" sin
   requerir presencia GPS constante?
2. ¿Qué mecanismos **anti-ballena** concretos (matchmaking por poder, ligas, límites de PvP
   por diferencia de nivel, costes crecientes) usan los 4X, más allá de los escudos?
3. ¿Cómo gestionan **EVE Online** (sovereignty/nullsec), **Travian** y **Tribal Wars** la
   guerra territorial persistente y las alianzas a gran escala? Lecciones de gobernanza.
4. **El problema del mapa vacío:** ¿qué densidad mínima de jugadores por barrio se necesita
   para que la disputa funcione, y cómo evitar barrios "muertos" (un solo jugador)? —
   **ningún competidor verificado lo resuelve hoy.**

---

## ✅ Qué adoptar para MAP (síntesis accionable)

| Decisión | Acción concreta |
|---|---|
| **Protección al novato** | Escudo impausable los primeros días, que se rompe si el novato ataca |
| **Anti-griefing automático** | Escudo defensivo automático escalado al daño + "guard" offline para la base hogar |
| **Cubrir el sueño/ausencia** | Escudos de paz (ganables jugando, no solo pagando), que caen si atacás |
| **Cooperación asíncrona** | Rally/coalición con ventana de unión larga (horas) para aliados de distintos horarios |
| **Monetización** | Modelo "long game"; poder 100% gratis; pago solo cosmético/conveniencia |
| **Ingreso diferenciador** | Ubicaciones reales patrocinadas (B2B local), sin afectar el balance |
| **Moderación** | Apoyarse en el sistema de escudos como moderación automática (clave para dev solo) |
| **El gran riesgo a resolver** | Densidad de jugadores por barrio / barrios muertos — diseñar para que sea divertido en solitario y mejor con vecinos |

---

## Fuentes principales

- DECA Games — Beginner's Protection (oficial): https://support.decagames.com/hc/en-us/articles/4422293195021-New-Players-Beginner-s-Protection
- Clash of Clans — Shield (Fandom): https://clashofclans.fandom.com/wiki/Shield
- Rise of Kingdoms — Peace Shield (Fandom): https://riseofkingdoms.fandom.com/wiki/Items/Peace_Shield
- Lords Mobile — Rally (Fandom): https://lordsmobile.fandom.com/wiki/Rally
- Infection Free Zone (Steam): https://store.steampowered.com/app/1465460/Infection_Free_Zone/
- ScreenRant — IFZ OpenStreetMap: https://screenrant.com/infection-free-zone-steam-openstreetmap-irl-zombie-game/
- TechCrunch — Niantic/Scopely $3.5B: https://techcrunch.com/2025/03/12/pokemon-go-maker-niantic-is-selling-its-games-division-to-scopely-for-3-5b/
- Game Developer — Clasificando P2W: https://www.gamedeveloper.com/business/classifying-pay-to-win-design-in-today-s-market
- Duamentes/AppMagic — Mercado 4X: https://www.duamentes.com/2025/10/13/how-to-break-into-4x-strategy-market/
- Juego Studio — Pokémon GO revenue: https://www.juegostudio.com/blog/pokemon-go-revenue
- EVE University — System security: https://wiki.eveuniversity.org/System_security
- Polaris Game Design — Prosocial multiplayer: https://polarisgamedesign.com/2022/kind-games-designing-for-prosocial-multiplayer/
