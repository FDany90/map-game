# ADR 0005 — Proveedor de tiles: MapTiler

- **Estado:** Aceptado
- **Etapa:** 3–4

## Contexto

Necesitamos un proveedor de tiles de mapa (datos OSM + estilo custom). Como por
[ADR 0002](0002-mapa-dentro-del-motor.md) renderizamos los tiles **nosotros mismos dentro
de Flame** (fuera de cualquier SDK de mapa), el proveedor debe permitir consumir tiles con
nuestro propio renderer y cachearlos. Candidatos: Mapbox y MapTiler.

> Nota: precios y términos cambian; verificar los actuales al registrarse.

## Comparación

| Criterio | Mapbox | MapTiler |
|---|---|---|
| Editor de estilos | Superior (Mapbox Studio) | Bueno (MapTiler Customize) |
| Renderizar tiles en motor propio (sin su SDK) | Restringido por términos | Permitido / pensado para eso |
| Cachear tiles | Restringido | Más permisivo |
| Self-hosting de datos | No | Sí |
| Modelo de precio | Por usuarios activos (MAU) | Por requests de tiles |

## Decisión

Usar **MapTiler**.

Razones (en orden de peso para este proyecto):
1. Encaja con la arquitectura: permite renderizar los tiles en nuestro propio motor, cosa
   que Mapbox restringe.
2. Más amistoso para **cachear** tiles (importante para rendimiento/offline en un juego).
3. **Self-hosting** como red de seguridad ante costos o cambios de términos a futuro.
4. Precio por requests, más simple de razonar para un dev en solitario.

Mapbox sería preferible solo si usáramos su SDK nativo de mapa (no es el caso) o si el
editor de estilos fuera decisivo.

## Costos

Análisis detallado en [`08-cost-analysis-tiles.md`](../08-cost-analysis-tiles.md). En corto:
- Nuestros **tiles raster** se facturan por **REQUESTS** (servicio "Rendered maps"): cada
  tile no cacheado = 1 request. Free = **100.000 requests/mes**; Flex $25 = 500.000;
  Unlimited $295 = 5.000.000. (Las "sesiones" son del SDK JS que no usamos.)
- **Free es solo uso no comercial** (+ logo MapTiler) → comercial necesita mínimo **Flex ($25/mes)**.
- La **caché** es la palanca #1: tiles cacheados no pegan a MapTiler → 0 requests.
- Medición real (2026-05-30): 9.392 requests en un día de testeo **sin caché**.
- Salida de escape a costo plano: **self-host / PMTiles**.

## Consecuencias

- **+** Libertad de render y caché alineada con ADR 0002.
- **+** Salida vía self-hosting si el costo escala.
- **−** Editor de estilos algo menos pulido que Mapbox (aceptable).
- **Acción:** crear cuenta en MapTiler, generar API key (guardarla fuera del repo, ya está
  en `.gitignore`), y diseñar el estilo apocalíptico en MapTiler Customize.
