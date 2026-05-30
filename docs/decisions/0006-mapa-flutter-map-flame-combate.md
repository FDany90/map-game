# ADR 0006 — Mapa con flutter_map + capas; Flame diferido y acotado al combate

- **Estado:** Aceptado
- **Reemplaza:** [ADR 0002](0002-mapa-dentro-del-motor.md)
- **Etapa:** revisado en Etapa 4 (tras el spike)

## Contexto

El spike (flutter_map + MapTiler) mostró que el mapa real, el zoom, los nombres de calles
y una **grilla de hexágonos propia** funcionan muy bien con `flutter_map`, **sin escribir un
tile loader**. Además se aclaró un punto que invalida la premisa del ADR 0002:
**`flutter_map` NO es una platform view nativa** — es Dart puro sobre el canvas de Flutter.
El problema de sincronización que el ADR 0002 quería evitar (SDK nativo + juego encima)
**no aplica** a `flutter_map`.

El juego es de **gestión / recolección / política / social**, con combate **automático y
simple** (torretas disparando, zombies caminando y recibiendo disparos). No es un juego de
combate de reflejos.

## Decisión

1. **Mapa y capas del mundo:** renderizar con **`flutter_map`** (tiles raster de MapTiler) +
   **capas propias** (hexágonos/territorio, edificios, marcadores). **No** escribir tile
   loader. **No** renderizar el mapa en Flame.
2. **Estilo del mapa:** vía **MapTiler Customize** (look apocalíptico, fuentes, capas).
3. **Animación de combate:** **decisión diferida** a la etapa de combate. **Flame** queda
   como **candidato fuerte**, usado como **overlay acotado al combate** (no para el mapa).
   Alternativa para combate liviano: una capa `CustomPaint` dentro de `flutter_map`.

## Por qué Flame NO se descarta

Para muchos sprites animados a la vez (una oleada de zombies + torretas), Flame es la
herramienta correcta, **aunque las animaciones sean simples**. Pero esa necesidad recién
aparece en la etapa de combate, y puede **convivir con `flutter_map` como capa superior**.
El test del "monstruo animado" (Etapa 4) ayudará a decidir si `flutter_map` solo alcanza
para el combate temprano o si conviene el overlay de Flame.

## Consecuencias

- **+** No escribimos tile loader; `flutter_map` da tiles, nombres, zoom y (con paquete) caché.
- **+** `flutter_map` no es platform view → integrar capas (y luego un overlay de Flame) es viable.
- **+** Flame queda acotado al combate y diferido → menos riesgo y trabajo ahora.
- **−** Si se usa overlay de Flame, hay que **sincronizar su cámara con la del mapa** (trabajo
  acotado).
- **−** El estilo del mapa base depende de MapTiler Customize (raster); control total del
  render sería con tiles vectoriales, fuera de alcance por ahora.
- El **costo no cambia** con esta decisión (los tiles vienen de MapTiler igual).

## Relación con otros ADRs

- [ADR 0001](0001-stack-flutter-flame.md): Flame pasa a estar **acotado al combate y
  diferido**, no es el motor del mapa.
- [ADR 0002](0002-mapa-dentro-del-motor.md): **reemplazado** por este.
- [ADR 0004](0004-tiles-raster-estilizados.md) y [0005](0005-proveedor-tiles-maptiler.md):
  siguen vigentes (tiles raster estilizados de MapTiler).
