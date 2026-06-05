# Análisis de costos de tiles (MapTiler)

> Estado: v0.3 (decisión de presupuesto + bandas de zoom 2026-05-31; medición real 2026-05-30)
> · relacionado con [ADR 0005](decisions/0005-proveedor-tiles-maptiler.md)
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
2. **Tiles de 512px nativo** (`tileSize: 512` + `zoomOffset: -1`) — **adoptado 2026-06-04** (ver
   abajo): ~⅓ de los requests para la misma vista.
3. **Pocos niveles de zoom** — el prototipo usa un solo zoom (ver ADR 0002).
4. **Limitar el zoom máximo en movimiento** (Exploración) — menos detalle al moverse.
5. **Limitar el radio de pan** — no cargar medio país.

### Tiles 512px nativo (DECIDIDO + validado 2026-06-04)

**MapTiler ya entrega los tiles en 512px** (el SKU facturado es literalmente *"Rendered maps
(512px)"*). El prototipo los declaraba como `tileSize: 256`, así que flutter_map **achicaba**
cada imagen a la mitad (→ etiquetas chicas, la queja del usuario) **y pedía ~4× más tiles** para
tapar la misma pantalla — pagando precio de 512 sin el beneficio.

Se pasó a **`tileSize: 512` + `zoomOffset: -1`** (`AppConfig.tileSize` / `AppConfig.tileZoomOffset`,
aplicado a los 3 `TileLayer`). El `-1` no es a ojo: para que la grilla de 512 llene el mundo que
flutter_map calcula en base 256, la cuenta da `2^offset = ½`. **Esto resuelve el bug del intento
del 2026-05-31** (que sin offset abría a escala país).

**Validado en emulador (2026-06-04):** encuadre de barrio correcto a zoom 17 (pide tiles **z16**,
un nivel más grueso → ¼ de tiles por terreno), **etiquetas a tamaño default** (se arregló solo al
no downscalear), y el monitor in-app confirma los requests z16. Es la **palanca #2** tras la caché.

## Diseño para un presupuesto objetivo — bandas de zoom (decisión 2026-05-31)

**Objetivo fijado por el usuario:** **≤ 100–200 requests por jugador por mes** (al menos en un
principio). Es alcanzable —y hasta holgado— si el juego **no usa zoom libre 3→20**, sino **bandas
de zoom discretas por modo**, cada una con **área acotada**.

> **Insight central (medido):** el costo NO depende del zoom, depende de **cuántas combinaciones
> distintas de (zona × zoom) se visitan**. Llenar la pantalla son ~6-12 tiles *en cualquier zoom*.
> El zoom libre + pan infinito = miles de combos = miles de requests. Pocos zooms fijos + área
> acotada = pocos combos = bajo costo. (Medición real: ~30 km desde la capital, zoom libre →
> **~200 requests**. Con bandas fijas, una fracción.)

### Bandas de zoom (LOD) y su costo

| Modo | Zoom | Tile cubre (~34°S) | Para qué | Tiles típicos |
|---|---|---|---|---|
| **Base local** | z18 (cap) | ~125 m | tu cuadra/barrio | ~30-60, **1 vez** → cacheado |
| **Mapa-ciudad** (exploración NO-GPS) | z11-12 | ~8 km | iconos: clanes, boss, dungeons, POIs | tu metro entero ≈ **15-30**, cacheado |
| **País / región** | z4-7 | ~150-2.500 km | ranking, clanes dominantes | ~5-10 |

- **Sin z13-17 de roam libre** (el rango caro del medio): se **salta entre LODs discretos**, no
  hay zoom continuo. Esto es lo que mantiene el presupuesto.
- **Los iconos (clanes/boss/dungeons/POIs) salen del backend, NO de MapTiler → $0.** Solo paga el
  fondo de mapa, que a z11-12 es baratísimo.
- **Área acotada por banda** (clave): z18-20 clavado al barrio; z11-12 acotado a la ciudad (bbox/
  radio), NO pan libre por el país; z4-7 para macro (tiles enormes → poquísimos).
- **Exploración = mapa de ciudad con iconos, NO GPS físico** (al inicio). El Modo Exploración GPS
  (Etapa 7) se diseña aparte y con más cuidado de costo (es el que más genera).

### Medición en la app
Se agregó un **monitor de requests in-app** (`TileRequestMonitor` + chip "🛰️ MapTiler: N"): cuenta
solo los que pegan a la red (misses = facturables), por prueba, con desglose por zoom en consola.
Permite verificar el presupuesto empíricamente en cada cambio de diseño.

## Historial de requests por sesión (log de medición)

Log para **comparar nuestra medición contra el dashboard de MapTiler** (Analytics) y validar que el
monitor coincide. **Cómo medir el total de una sesión:** el chip in-app se **resetea en cada
`flutter run`**, así que para una sesión con varios reinicios se cuentan las líneas `[tiles] MISS`
en los logs de consola (o, para un número limpio, hacer la prueba en **un solo run sin reiniciar** y
leer el chip). El dashboard **no es en tiempo real** → chequear al día siguiente.

| Fecha | Sesión (qué se hizo) | Requests medidos (app) | En Analytics MapTiler | Notas |
|---|---|---|---|---|
| 2026-06-04 | Testeo combate (Bloques A/B) + mapa Slice A; **muchos reinicios** + zoom-out a z13/z10 para ver markers | **145** | _(pendiente: chequear 2026-06-05)_ | 28 del 1er run (caché limpia, vista inicial z16) + 117 del último (zoom-out a niveles nuevos). Todos tiles **512px**. |

> Al cerrar cada sesión de testeo intenso, agregar una fila acá y completar la columna de Analytics
> al día siguiente. Si **medido ≈ Analytics**, el monitor es confiable para presupuestar sin abrir el
> dashboard.

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
