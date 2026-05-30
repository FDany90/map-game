# ADR 0004 — Tiles raster estilizados para el prototipo

- **Estado:** Aceptado (alcance: prototipo)
- **Etapa:** 3–4
- **Relación:** precisa un detalle del [ADR 0002](0002-mapa-dentro-del-motor.md)

## Contexto

ADR 0002 decidió renderizar el mapa dentro del motor (Flame). Falta definir **qué tipo de
tiles** consumimos: raster (imágenes ya dibujadas) o vectoriales (geometría que dibujamos
nosotros). Y qué nivel de fidelidad de edificios apuntar (ver `07-map-art-direction.md`).

## Opciones

1. **Raster estilizados.** Se diseña un estilo apocalíptico en el editor del proveedor y
   este sirve imágenes ya pintadas. En Flame se "pegan" como sprites de fondo. Fácil de
   renderizar y rinde bien. Los edificios reales quedan pintados dentro de la imagen (no
   interactivos) = Nivel A de fidelidad.
2. **Vectoriales.** El proveedor sirve geometría (calles, edificios) y la dibujamos
   nosotros en Flame. Control total del look y edificios como objetos del juego (Nivel B/C),
   pero hay que implementar un renderer de vector tiles (formato MVT) → mucho más trabajo.

## Decisión

Para el **prototipo**: **tiles raster estilizados** (Nivel A de fidelidad).

- Estilo oscuro/post-apocalíptico diseñado en MapTiler Customize.
- En Flame se dibujan como capa de fondo; encima van hexágonos, construcción, unidades, efectos.
- Calles, nombres y manzanas reales se ven; los edificios reales quedan pintados (no interactivos).

## Consecuencias

- **+** Camino más rápido a "mi barrio real reconocible, con estilo de juego".
- **+** Render trivial en Flame (blit de imágenes) y buen rendimiento.
- **+** Permite avanzar en el loop de juego sin construir un renderer de vectores.
- **−** Los edificios reales no son interactivos (aceptable: el juego se construye sobre la
  grilla de hexágonos con sprites propios).
- **Futuro:** subir a tiles vectoriales (Nivel B) será un cambio mayor de render → se
  registrará en un ADR nuevo cuando se decida.
