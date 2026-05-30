# Análisis de costos de tiles (MapTiler)

> Estado: borrador v0.1 · relacionado con [ADR 0005](decisions/0005-proveedor-tiles-maptiler.md)
> Documento vivo. Los montos en dólares cambian — verificar en MapTiler. Acá importa el
> **modelo** y los órdenes de magnitud.

## Resumen ejecutivo

- MapTiler **factura por "sesiones de API"** (no por tile individual) cuando usás un
  **estilo de mapa**. Confirmado en el dashboard: nuestro uso dio "1 sesión, 0 requests".
  Una sesión agrupa todos los tiles cargados en un rato de uso.
- **El plan Free es solo para uso personal / no comercial** y pone el logo de MapTiler.
  Para un lanzamiento comercial hay que pasar a **Flex ($25/mes)** como mínimo.
- El límite que importa en Free es **5.000 sesiones/mes** (los 100k requests aplican al uso
  de tiles "crudos", no a los estilos).
- **La caché es la palanca #1:** si los tiles están cacheados en el dispositivo, no se pega
  a MapTiler → no se cuenta sesión. Un jugador anclado a su casa con caché genera muy pocas
  sesiones. El **Modo Exploración** (calles nuevas) es el que más sesiones genera.
- **Salida de escape a costo plano:** self-host / PMTiles, sin sesiones ni requests por uso.

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

> Para estilos de mapa, la unidad que cuenta es la **sesión**. "Extra sessions: None" en Free
> significa que al llegar a 5.000 se corta el servicio (no hay sobrecosto, pero deja de servir).

## Tabla 3 — Sesiones por escala (modelo con caché)

Una "sesión" ≈ una ráfaga de uso que **pega a MapTiler** (aprox. cada vez que el jugador abre
la app y carga tiles **no cacheados**). Con buena caché, un jugador anclado a su casa pega a
MapTiler sobre todo la **primera vez** y cuando expira la caché o explora zonas nuevas.

| Escenario | Sesiones/mes aprox. | Plan necesario |
|-----------|---------------------|----------------|
| Prototipo / pocos testers | decenas | ✅ Free |
| ~50–100 jugadores activos (Modo Base, con caché) | hasta ~5.000 | ✅ Free (al límite) |
| Cientos de jugadores (comercial) | 5.000–25.000 | Flex ($25) |
| Miles de jugadores | 25.000–300.000 | Unlimited ($295) o self-host |
| Exploración masiva / gran escala | millones | Self-host / PMTiles (costo plano) |

> Sin caché, las sesiones ≈ aperturas de app (abrir 3×/día ≈ 90 sesiones/mes/jugador) y el
> Free rinde mucho menos. **Por eso la caché del tile loader no es opcional.**

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

- **Prototipo / desarrollo:** plan **Free** alcanza (uso no comercial).
- **Lanzamiento comercial:** mínimo **Flex ($25/mes)** — el Free no permite uso comercial.
- **Construir caché agresiva en el tile loader desde el día 1** — es lo que mantiene bajas
  las sesiones (y por lo tanto el costo).
- **Diseñar el Modo Exploración con el costo en mente** (caché de calles recorridas + límite
  de zoom en movimiento): es el que más sesiones genera.
- **Definir un umbral** (sesiones acercándose al límite del plan) para migrar a
  **self-host / PMTiles** (costo plano), *antes* de que sea un problema.
