# Roadmap

> Documento vivo. Marcamos el estado de cada etapa a medida que avanzamos.
> Leyenda de estado: ⬜ pendiente · 🟡 en curso · ✅ hecho

## Etapas

| # | Etapa | Entregable | Estado |
|---|-------|-----------|--------|
| 0 | **Visión & GDD** | Visión + diseño de juego documentados | 🟡 |
| 1 | **Arquitectura & decisiones** | Doc de arquitectura + ADRs | 🟡 |
| 2 | **Modelado de datos & economía** | Modelo de entidades + spec de economía | 🟡 |
| 3 | **Mockups / UX** | Wireframes del Modo Base | ⬜ |
| 4 | **Spike técnico: EL MAPA** ⭐ | Tiles reales + GPS funcionando en Flame | ⬜ |
| 5 | **Prototipo jugable (Modo Base)** | Reclamar → infestar → defensa auto + economía mínima | ⬜ |
| 6 | **Multijugador (vecinos)** | Territorio compartido en backend | ⬜ |
| 7 | **Modo Exploración** | GPS en vivo + combate activo | ⬜ |
| 8 | **Arte, pulido & soft launch** | Build para tienda | ⬜ |

## Detalle de cada etapa

### Etapa 0 — Visión & GDD 🟡
Definir el qué y el porqué antes del cómo. Pitch, pilares, público, bucle de juego.
**Salida:** `01-vision.md`, `02-game-design.md`.

### Etapa 1 — Arquitectura & decisiones 🟡
Stack técnico y las decisiones grandes registradas como ADRs.
**Salida:** `03-architecture.md`, `decisions/*`.

### Etapa 2 — Modelado de datos & economía 🟡
Entidades del juego (hexágono, base, edificio, recurso, unidad) y cómo se relacionan.
Spec de la economía: recursos + ciclos de producción/consumo.
- ✅ **Economía** diseñada y documentada: `05-economia.md` (modelo limitado/activo anti-idle:
  loot finito + ingreso por actividad; 3 recursos; territorio oscuro = amenaza + granja).
- ⬜ **Modelo de datos** (entidades) pendiente: `04-data-model.md`.
**Salida:** `04-data-model.md`, `05-economia.md`.

### Etapa 3 — Mockups / UX ⬜
Wireframes de las pantallas del Modo Base (mapa, construir, mejorar, defensa, vecinos).
**Salida:** `06-ux-mockups.md` + imágenes.

### Etapa 4 — Spike técnico: EL MAPA ⭐ ⬜
**El riesgo #1.** Validar en código que podemos:
- Cargar tiles de mapa real (z/x/y, Web Mercator) dentro de Flame.
- Centrar el mapa en la posición GPS real del jugador.
- Zoom/pan fluidos con la cámara de Flame.
- Dibujar la grilla de hexágonos (H3) alineada al mapa.

Si esto funciona y rinde bien, el resto del juego es "género conocido".
**Salida:** proyecto Flutter mínimo + nota técnica con resultados.

> Paso previo (en curso): **Spike 01** — smoke test desechable con `flutter_map`
> (no Flame) para validar la integración de MapTiler. Ver `spike-01-maptiler-flutter.md`.

### Etapa 5 — Prototipo jugable (Modo Base) ⬜
Sobre el mapa del spike: reclamar un hexágono, construir un edificio, ver una oleada
salir de un hexágono oscuro, defensa automática de torretas, economía mínima.
Sin multijugador (vecino "falso" estático).
**Salida:** prototipo jugable + nota de "¿es divertido?".

### Etapa 6 — Multijugador (vecinos) ⬜
Estado del mundo compartido en backend (quién posee cada hexágono + qué construyó).
Bordes compartidos con vecinos reales.
**Salida:** integración backend + ADR de backend confirmado.

### Etapa 7 — Modo Exploración ⬜
GPS en vivo, avatar que se mueve, combate activo, gate de combustible.
**Salida:** modo exploración jugable.

### Etapa 8 — Arte, pulido & soft launch ⬜
Pipeline de arte, balance, build de tienda, soft launch regional.
