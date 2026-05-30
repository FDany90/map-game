# MAP (título provisional)

Juego móvil de **construcción, defensa y guerra territorial social** sobre un mapa real.
Tu barrio es el campo de batalla: plantás tu base en tu ubicación real, te expandís
hexágono por hexágono, y los monstruos nacen del territorio abandonado. Cooperás (y
competís) con tus vecinos reales por el territorio.

- **Plataforma:** App nativa móvil (Android + iOS) con **Flutter + Flame**.
- **Estado actual:** Etapa 0 — Diseño y documentación. Sin código todavía.
- **Modo de juego:** "jugar desde casa" como núcleo + "exploración" como capa opcional.

## Documentación

Toda la documentación vive en [`docs/`](docs/) y son **documentos vivos**: se actualizan
a medida que el proyecto avanza y se versionan en Git.

| Doc | Contenido |
|-----|-----------|
| [00 — Roadmap](docs/00-roadmap.md) | Etapas del proyecto y estado |
| [01 — Visión](docs/01-vision.md) | Pitch, pilares, público objetivo |
| [02 — Diseño de juego (GDD)](docs/02-game-design.md) | Bucle de juego, modos, economía, social |
| [03 — Arquitectura](docs/03-architecture.md) | Stack técnico, mapa-en-motor, datos |
| [05 — Economía](docs/05-economia.md) | Modelo limitado/activo: recursos, loot finito, territorio oscuro |
| [07 — Dirección de arte del mapa](docs/07-map-art-direction.md) | Cómo se ve el mapa real, capas, fidelidad de edificios |
| [08 — Análisis de costos de tiles](docs/08-cost-analysis-tiles.md) | Costo de MapTiler por zoom/uso; Exploración como driver |
| [09 — Referencias e inspiración](docs/09-referencias.md) | Juegos del género: qué tomar y qué evitar |
| [10 — Investigación: hallazgos](docs/10-investigacion-hallazgos.md) | Deep-research con fuentes: mecánicas, mercado, monetización, anti-tóxico |
| [Spike 01 — MapTiler + Flutter](docs/spike-01-maptiler-flutter.md) | Guía del smoke test de integración (desechable) |
| [decisions/](docs/decisions/) | Registro de decisiones de arquitectura (ADRs) |

## Cómo trabajamos

1. Cada etapa del [roadmap](docs/00-roadmap.md) actualiza sus documentos.
2. Los documentos se commitean y suben a Git en cada cambio relevante.
3. Las decisiones técnicas importantes se registran como un ADR en `docs/decisions/`.

## Requisitos para etapas de código (Etapa 4 en adelante)

Todavía **no** instalados — hacen falta cuando empecemos a programar:

- [ ] Git
- [ ] Flutter SDK (incluye Dart)
- [ ] Android Studio (emulador Android) y/o Xcode (iOS, requiere Mac)
- [ ] Cuenta en proveedor de tiles (MapTiler / Mapbox) — plan gratuito para empezar
