# Arquitectura técnica

> Estado: borrador v0.1 · Etapa 1
> Documento vivo. Las decisiones grandes se registran como ADRs en `decisions/`.

## Stack elegido

| Capa | Tecnología | ADR |
|------|-----------|-----|
| App (Android + iOS) | **Flutter** | [0001](decisions/0001-stack-flutter-flame.md) |
| Motor de juego 2D | **Flame** (sobre Flutter) | [0001](decisions/0001-stack-flutter-flame.md) |
| Render del mapa | **Tiles dentro del motor** (no SDK de mapa nativo) | [0002](decisions/0002-mapa-dentro-del-motor.md) |
| Tipo de tiles (prototipo) | **Raster estilizados** (Nivel A de fidelidad) | [0004](decisions/0004-tiles-raster-estilizados.md) |
| Grilla de hexágonos | **H3** (paquete `h3_flutter`) | — |
| Proveedor de tiles | **MapTiler** (raster, plan gratuito) | [0005](decisions/0005-proveedor-tiles-maptiler.md) |
| Backend / multijugador | **BaaS: Supabase o Firebase** (a confirmar) | [0003](decisions/0003-backend-baas.md) |

## Diagrama de capas (render)

```
Flutter (app, menús, HUD, tiendas, login)
  └─ GameWidget (Flame)
       Cámara (zoom / pan compartidos)
       ├─ Capa Mapa      → TileComponent (carga tiles z/x/y, Web Mercator)
       ├─ Capa Hexágonos → grilla H3 (territorio: claro / oscuro / vecino / rival)
       ├─ Capa Edificios → torretas, muros, generadores
       ├─ Capa Unidades  → monstruos y defensas (SpriteAnimationComponent)
       └─ Capa Efectos   → disparos, explosiones
Backend (BaaS): quién posee cada hexágono + qué hay construido + economía
```

## Decisión central: el mapa se dibuja DENTRO del motor

En vez de usar un SDK de mapa nativo (MapLibre/Mapbox) y dibujar el juego encima
(dos sistemas de coordenadas que hay que sincronizar), **renderizamos los tiles del mapa
como una capa más dentro de Flame**. Así el mapa, los hexágonos, los edificios y los
sprites comparten **una sola cámara y un solo sistema de coordenadas**.

- Ventaja: zoom/pan parejos para todo; el combate animado sobre el mapa "simplemente funciona".
- Modelo mental idéntico al de Unity (todo en un canvas + cámara).
- Costo: implementar un **tile loader** propio. Ver ADR 0002.

### Tile loader (cómo funciona un "slippy map")

- El mundo se parte en una pirámide de tiles por nivel de zoom (`z`). Cada nivel es una
  grilla de tiles 256×256 identificados por `z/x/y` (quadtree: al acercar, cada tile se divide en 4).
- Conversión lat/lon → píxeles con la **proyección Web Mercator** (fórmula estándar).
- Dada la posición y el zoom de la cámara → calcular qué tiles `z/x/y` hacen falta,
  pedirlos al proveedor, cachearlos y dibujarlos.
- **Simplificación para el prototipo:** arrancar con **un único nivel de zoom fijo** y
  tiles de una sola escala. La pirámide completa se agrega cuando el loop ya sea divertido.

> Aclaración de terminología:
> - **"Capas de tiles" del mapa** (estilo Google) = la *pirámide de zoom* (z0, z1, z2…). Es
>   un solo mapa a distintas escalas, no varios mapas apilados.
> - **"Capas/layers" del juego** = lo que apilamos en Flame (mapa, hexágonos, edificios,
>   unidades, efectos, HUD), manejado por prioridad de render.

## Combate en diferido (Modo Base)

El combate de torretas se resuelve de forma **asíncrona**: al volver a la app se calcula
el resultado del tiempo ausente. No requiere servidor de tiempo real → backend simple
(estado + funciones), más barato y más fácil de mantener para un dev en solitario.

## Pendientes de arquitectura

- Confirmar BaaS (Supabase vs Firebase) — ADR 0003.
- Definir el modelo de datos (Etapa 2): hexágono, base, edificio, recurso, unidad.
- Estrategia de caché de tiles (memoria + disco) y límites del plan gratuito del proveedor.
- Modelo de sincronización del estado del territorio entre jugadores.
