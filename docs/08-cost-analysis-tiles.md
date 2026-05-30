# Análisis de costos de tiles (MapTiler)

> Estado: v0.2 (corregido con medición real 2026-05-30) · relacionado con
> [ADR 0005](decisions/0005-proveedor-tiles-maptiler.md)
> Documento vivo. Los montos en dólares cambian — verificar en MapTiler. Acá importa el
> **modelo** y los órdenes de magnitud.

## Resumen ejecutivo

- **Para NUESTRA arquitectura (tiles raster propios con flutter_map), MapTiler factura por
  REQUESTS:** cada tile que se carga (y no está cacheado) = **1 request** del servicio
  "Rendered maps". Límite del plan **Free: 100.000 requests/mes**.
- Las **"sesiones"** (5.000/mes en Free) son de **otro servicio** — el **SDK JS de mapas**
  de MapTiler, que **NO usamos**. Para nosotros la métrica que importa son los **requests**.
- **Medición real (2026-05-30):** 9.392 requests · 1 sesión, casi todo "Rendered maps
  (512px)" → ~9% del cupo mensual gratis, gastado en **testeo de desarrollo SIN caché**
  (muchos relanzamientos + pan/zoom). Con caché, un jugador real usa muchísimo menos.
- **El plan Free es solo uso personal / no comercial** (+ logo MapTiler) → un lanzamiento
  comercial necesita mínimo **Flex ($25/mes)** = 500.000 requests/mes.
- **La caché es la palanca #1:** un tile cacheado en el dispositivo **no pega a MapTiler →
  0 requests**. Jugador anclado a su casa con caché = pocos requests. El **Modo Exploración**
  (calles nuevas) es el que más requests genera.
- **Salida de escape a costo plano:** self-host / PMTiles, sin requests por uso.

## Base del cálculo

Cada tile es una imagen de 256×256 px en proyección Web Mercator. Cada **nivel de zoom
tiene su propio set de tiles** (no se comparten entre zooms). Subir un zoom ≈ 4× más tiles.

### Tamaño aproximado del tile por zoom

| Zoom | Tamaño aprox. del tile | Uso típico |
|------|------------------------|------------|
| z14 | ~2,4 km | vista de ciudad |
| z15 | ~1,2 km | vista de zona |
| z16 | ~600 m | barrio |
| z17 | ~300 m | varias cuadras |
| z18 | ~150 m | detalle de cuadra |

*(Aproximado al ecuador; en latitudes medias los tiles son algo más chicos → algunos más.)*

## Tabla 1 — Tiles para cubrir un área, por zoom

| Zoom | 1×1 km | 2×2 km | 5×5 km |
|------|--------|--------|--------|
| z16 | 4 | 16 | ~81 |
| z17 | 16 | 49 | ~289 |
| z18 | 49 | ~196 | ~1.156 |

## Tabla 2 — Requests por jugador según comportamiento

| Perfil | Qué hace | Tiles (1er mes) | Steady state |
|--------|----------|-----------------|--------------|
| Base puro | Solo su zona, 1 zoom | ~20–50 | ~0 (cacheado) |
| Base + vecinos | Su zona + bordes, 2–3 zooms | ~250 | ~0 |
| Curioso | Zonas cercanas (~5 km), 2 zooms | ~600 | bajo |
| **Explorador** 🔥 | Se mueve por la ciudad, alto zoom, áreas nuevas | ~1.000–3.000+ | **~1.000–3.000+/mes (recurrente)** |

Clave: los tres primeros perfiles pagan **una sola vez** (caché). El explorador genera
costo **recurrente**.

## Precios reales de MapTiler (verificado 2026-05-29)

| Plan | Precio | Sesiones incluidas | Requests incluidos | Uso |
|------|--------|--------------------|--------------------|-----|
| **Free** | $0 | 5.000/mes (sin extra) | 100.000/mes (sin extra) | Solo personal / **no comercial**; logo MapTiler |
| **Flex** | $25/mes | 25.000/mes (+$2 c/1.000) | 500.000/mes (+$0,10 c/1.000) | **Comercial**; 10 GB hosting |
| **Unlimited** | $295/mes | 300.000/mes (+$1,5 c/1.000) | 5.000.000/mes (+$0,08 c/1.000) | SLA 99,9%; 100 GB hosting |
| **Custom** | contrato | a medida | a medida | Alto tráfico |

> Para los tiles raster que usamos, la unidad que cuenta son los **requests** (servicio
> "Rendered maps"): Free = 100.000/mes (sin extra → al llegar, se corta). Las "sesiones" son
> de otro servicio (el SDK JS) que **no** usamos.

## Tabla 3 — Requests por escala (modelo con caché)

Cada tile **no cacheado** = 1 request. Con buena caché, un jugador anclado a su casa pega a
MapTiler sobre todo la **primera vez** y cuando expira la caché o explora zonas nuevas.

| Escenario | Requests/mes aprox. | Plan necesario |
|-----------|---------------------|----------------|
| Desarrollo SIN caché (testeo intenso) | ~5.000–10.000 | ✅ Free (medido: 9.392) |
| 1.000 jugadores Modo Base, CON caché (~100 nuevos × ~250) | ~25.000–40.000 | ✅ Free |
| 1.000 jugadores, 30% exploradores (sin tope de zoom) | cientos de miles | Flex / Unlimited |
| Gran escala / exploración masiva | millones | Self-host / PMTiles (costo plano) |

> Sin caché, los requests se disparan (cada pan/zoom recarga tiles). **Por eso la caché no es
> opcional** — y conviene agregarla incluso en desarrollo para no quemar el cupo.

## Perillas para controlar el costo

1. **Caché agresiva** (más días en disco) — la principal. Aplica también a exploración:
   revisitar las mismas calles = gratis.
2. **Pocos niveles de zoom** — el prototipo usa un solo zoom (ver ADR 0002).
3. **Limitar el zoom máximo en movimiento** (Exploración) — menos detalle al moverse.
4. **Limitar el radio de pan** — no cargar medio país.

## Salidas de escape (costo plano, no por jugador)

Por esto se eligió MapTiler (ver ADR 0005):

- **Self-hosting con MapTiler:** bajás los datos y los servís vos → pagás un servidor, no requests.
- **PMTiles / Protomaps:** generás los tiles desde datos OSM gratis y los servís como un
  archivo en almacenamiento barato (S3/R2). Costo prácticamente plano.
- **Pre-empaquetar la ciudad del lanzamiento** como PMTiles → explorar dentro de esa ciudad
  no genera requests por uso.

## Recomendación

- **Prototipo / desarrollo:** plan **Free** (100k requests/mes) alcanza — pero **agregá caché
  de tiles ya en el prototipo** para no quemar el cupo testeando (medición: 9.392 en un día).
- **Lanzamiento comercial:** mínimo **Flex ($25/mes)** — el Free no permite uso comercial.
- **Caché agresiva desde el día 1** — es lo que mantiene bajos los **requests** (y el costo).
- **Diseñar el Modo Exploración con el costo en mente** (caché de calles recorridas + límite
  de zoom en movimiento): es el que más requests genera.
- **Definir un umbral** (requests acercándose al límite del plan) para migrar a
  **self-host / PMTiles** (costo plano), *antes* de que sea un problema.
