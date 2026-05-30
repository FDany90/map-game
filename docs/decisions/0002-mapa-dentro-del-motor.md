# ADR 0002 — El mapa se renderiza dentro del motor

- **Estado:** ❌ Reemplazado por [ADR 0006](0006-mapa-flutter-map-flame-combate.md)
- **Etapa:** 1

> **Reemplazado:** tras el spike (Etapa 4) descubrimos que `flutter_map` NO es una platform
> view nativa (es Dart puro), así que la premisa de este ADR ya no aplica. El mapa se
> renderiza con **flutter_map** y Flame queda diferido al combate. Ver
> [ADR 0006](0006-mapa-flutter-map-flame-combate.md). Se conserva como referencia histórica.

## Contexto

El juego necesita combinar un **mapa real** con un **juego de sprites** (hexágonos,
edificios, monstruos) sobre el mismo espacio, con zoom y pan. El mapa es el núcleo del
juego (la posición real y el territorio). Hay que decidir cómo se renderiza.

## Opciones consideradas

1. **SDK de mapa nativo (MapLibre/Mapbox) + juego dibujado encima.**
   El SDK maneja el mapa (tiles, zoom). El juego se superpone.
   - Problema: el mapa nativo es una *platform view*; sincronizar el canvas de Flame encima
     (que el sprite quede pegado al hexágono al hacer zoom/pan) es complejo. Dos sistemas
     de coordenadas peleándose.

2. **Dibujar TODO dentro de Flame, incluido el mapa.** — elegida.
   Cargar los tiles del mapa como una capa más del motor.

## Decisión

Renderizar los **tiles del mapa como una capa dentro de Flame**. Mapa, hexágonos,
edificios y sprites comparten **una sola cámara y un solo sistema de coordenadas**.

- Tiles servidos por un proveedor (MapTiler/Mapbox), esquema `z/x/y`, proyección Web Mercator.
- Grilla de hexágonos con **H3**, alineada al mapa.
- Para el prototipo: arrancar con **un solo nivel de zoom fijo**; la pirámide completa después.

## Consecuencias

- **+** Zoom/pan parejos para todo; el combate animado sobre el mapa "simplemente funciona".
- **+** Modelo mental idéntico a Unity (todo en un canvas + cámara).
- **+** Sin sincronización entre dos motores de render.
- **−** Hay que implementar un **tile loader** propio (cálculo de tiles visibles, caché, Web Mercator).
- **−** Riesgo técnico #1 del proyecto → se valida en un *spike* aislado (Etapa 4) antes de seguir.
