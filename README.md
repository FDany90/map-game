# MAP (título provisional)

Juego móvil de **construcción, defensa y guerra territorial social** sobre un mapa real.
Tu barrio es el campo de batalla: plantás tu base en tu ubicación real, te expandís
hexágono por hexágono, y los monstruos nacen del territorio abandonado. Cooperás (y
competís) con tus vecinos reales por el territorio.

- **Plataforma:** App nativa móvil (Android + iOS) con **Flutter** (+ **flutter_map**; Flame diferido al combate).
- **Estado actual:** prototipo jugable en `map_spike/` (mapa + hexágonos + economía mínima). Diseño en Etapa 2.
- **Modo de juego:** "jugar desde casa" como núcleo + "exploración" como capa opcional.

> 👉 **¿Retomando el proyecto? Empezá por [docs/HANDOFF.md](docs/HANDOFF.md)** — estado,
> cómo correr el prototipo, decisiones resueltas y próximos pasos.

## Documentación

Toda la documentación vive en [`docs/`](docs/) y son **documentos vivos**: se actualizan
a medida que el proyecto avanza y se versionan en Git.

| Doc | Contenido |
|-----|-----------|
| [🟢 HANDOFF](docs/HANDOFF.md) | **Empezá acá para retomar:** estado, cómo correr, pendientes |
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

## Entorno (instalado en la máquina de desarrollo)

- [x] Git 2.54
- [x] Flutter SDK 3.44 (incluye Dart)
- [x] Android Studio + emulador **Pixel_7 (API 37)**
- [x] Cuenta MapTiler + API key (en `map_spike/lib/secrets.dart`, **no** versionado)
- [ ] Xcode (iOS) — solo en Mac, pendiente

Para correr el prototipo y los detalles operativos, ver [docs/HANDOFF.md](docs/HANDOFF.md).
