# Diseño de juego (GDD)

> Estado: borrador v0.1 · Etapa 0
> Documento vivo. Los números (ritmos, costos, balance) son provisionales y se ajustan más adelante.

## 1. Bucle de juego principal

1. **Reclamar** — Reclamás hexágonos del mapa real alrededor de tu casa. Quedan "iluminados" / seguros.
2. **Construir** — En los hexágonos que tenés: generadores de recursos, muros, torretas, ayuntamiento.
3. **Decaimiento → Infestación** — Todo hexágono que nadie controla se vuelve "oscuro" y cría monstruos. Más oscuridad cerca = oleadas más grandes.
4. **Defender** — Las oleadas salen de los hexágonos oscuros y avanzan hacia tu base. Las torretas pelean solas.
5. **Cooperar** — Hexágonos en borde compartido con un vecino valen más (recursos extra, defensa combinada).
6. **Competir** — Dos jugadores no pueden tener el mismo hexágono → tensión en la frontera de expansión.

Todo gira alrededor de un único recurso unificador: **el territorio**.

## 2. Los dos modos de juego

### 🏠 Modo Base (núcleo — jugar desde casa)

- Vista cenital. La base está anclada a la **ubicación real** del jugador (GPS una sola vez, al fundar).
- El jugador hace: construir, mejorar, administrar economía, optimizar layout de defensa,
  decidir qué hexágonos limpiar/reclamar, coordinar con vecinos.
- **Combate automático y resuelto en diferido (offline):**
  - Las torretas pelean solas; no hay que apuntar ni tocar.
  - Al abrir la app, el juego **calcula qué pasó mientras el jugador no estaba**: cuántas
    oleadas llegaron, si las defensas aguantaron, cuántos recursos se generaron.
  - **Implicación técnica clave:** no hace falta un servidor en tiempo real corriendo
    combate → mucho más simple y barato para un dev en solitario.
- La decisión del jugador no es "apuntar y disparar", es **preparar y administrar**.

### 🚗 Modo Exploración (desbloqueable — opcional)

- Se desbloquea construyendo un **Garaje/Taller** y fabricando un **vehículo** (o equipo de a pie).
- Usa **GPS en vivo**: el avatar del jugador se mueve físicamente con él por el mapa real.
- **¿Para qué salir?** (debe valer la pena, sin ser obligatorio):
  - Recursos raros que solo aparecen lejos o en territorio oscuro profundo.
  - **Limpiar focos de infección lejanos** que, si crecen, mandan oleadas más grandes a casa.
  - Reclamar territorio nuevo fuera del alcance desde casa.
  - Visitar/ayudar bases de vecinos en persona (refuerzo social).
  - Eventos: un jefe u horda aparece en un punto real del mapa.
- **Combate activo** (se toca para disparar / usar habilidades), porque fuera de casa no
  hay torretas → *feel* claramente distinto al Modo Base.
- **Gate económico = combustible.** El vehículo consume combustible; limita el "explorar
  infinito" y crea decisiones (¿gasto esta salida o guardo?).
- **Riesgo/recompensa:** lejos de casa el jugador es vulnerable; si lo superan, pierde
  parte de lo recolectado.

### Regla rectora entre modos

> **Exploración multiplica, no reemplaza.** El jugador de sillón nunca queda excluido ni
> en desventaja injusta. Explorar da velocidad y acceso a cosas exclusivas, pero nunca es
> *obligatorio* para competir en lo básico.

## 3. Sistema de territorio (hexágonos)

- El mapa real se divide en una grilla de hexágonos (lib **H3**).
- Estados de un hexágono: **propio · de vecino/aliado · de rival · neutral · oscuro (infestado)**.
- El territorio oscuro avanza con el tiempo si nadie lo contiene (ritmo = perilla de dificultad, a definir).
- Borde compartido entre aliados → bonus de recursos y defensa.

## 4. Economía (semilla — a desarrollar en Etapa 2)

- Recursos básicos (provisional): **material de construcción, energía, combustible, y una moneda blanda**.
- Ciclos: generadores producen mientras el hexágono esté seguro; el combate y la exploración consumen.
- Objetivo: que administrar la economía tenga decisiones interesantes (¿defensa vs expansión vs exploración?).
- **Pendiente:** definir lista final de recursos, tasas de producción/consumo, sinks y faucets.

## 5. Cooperación con vecinos

- **Fase 1:** vecinos cercanos (por proximidad geográfica real).
- **Fase 2:** invitar amigos.
- Mecánica central: bordes compartidos más fuertes + limpiar la zona oscura intermedia en conjunto.

## 6. El "problema del mapa vacío"

- El juego debe ser divertido **en solitario** (PvE: infestación + defensa) y *mejor* con vecinos.
- Estrategias de mitigación (a explorar): bots/IA de relleno, eventos PvE globales, soft launch
  concentrado en una zona geográfica para crear densidad de jugadores.

## 7. Alcance del primer prototipo (Etapa 5)

Lo mínimo para probar si el núcleo es divertido:
- Mapa real centrado en el GPS del jugador.
- Reclamar un hexágono · construir un edificio · una torreta.
- Un hexágono oscuro que genera una oleada.
- Defensa automática resuelta.
- Economía mínima (1–2 recursos).
- Sin multijugador (un "vecino" estático de prueba).

## Pendientes de diseño (backlog)

- Ritmo exacto de la infestación (dificultad).
- Lista final de recursos y balance de economía.
- Árbol de edificios y mejoras.
- Diseño de monstruos y tipos de oleada.
- Anti-trampa (spoofing de GPS) y seguridad física — relevante recién en Modo Exploración.
- **Diseñar el Modo Exploración con el costo de tiles en mente** (es el driver de costo):
  caché de calles recorridas, límite de zoom en movimiento, pre-empaquetar la ciudad como
  PMTiles. Ver [análisis de costos](08-cost-analysis-tiles.md).
