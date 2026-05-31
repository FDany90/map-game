# Referencia: datos OSM / Overpass para generar escenas

> Estado: referencia técnica · 2026-05-30
> Documento vivo. Cómo funciona OSM/Overpass y qué atributos usar para construir escenas
> isométricas proceduralmente (ver ADR 0007).
> Implementación base: map_spike/lib/data/services/overpass_service.dart

## Modelo de datos de OSM
Tres tipos de objeto:
- node — un punto (lat, lon). Puede tener tags (ej. un semáforo, un árbol).
- way — lista ordenada de nodes. Abierto = línea (una calle); cerrado = polígono (un edificio).
- relation — agrupación de objetos (avenida partida en varios ways, multipolígonos).

Cada objeto lleva tags = pares clave=valor. Los tags son los parámetros y atributos con los que generamos la escena.

## Overpass: cómo se consulta
- Endpoint: https://overpass-api.de/api/interpreter (+ mirror overpass.kumi.systems).
- Lenguaje OQL. Ejemplo (lo que usa el spike):
    [out:json][timeout:25];
    way["highway"](around:300,LAT,LON);
    out geom;
- "out geom;" es clave: devuelve la geometría completa (todos los puntos lat/lon del way) además de los tags. Sin geom, sólo vienen IDs de nodes.
- Requiere User-Agent propio o devuelve HTTP 406 (política OSM).
- Fair-use: no llamar por frame -> una consulta por área, cacheada (lo hace StreetsRepository). Ver 11-zombies-calles-cost.md.

## Atributos de CALLES (highway) — para dirección y tipo
- highway= : jerarquía/tipo: motorway > primary (avenida) > secondary > tertiary > residential (calle barrio) > pedestrian/footway/path (peatonal). Define ancho base y estilo.
- lanes= : nº de carriles (ambiguo a veces; existen lanes:forward/lanes:backward).
- width= : ancho en metros, si está mapeado.
- oneway=yes : mano única -> flechas/sentido.
- surface= : asfalto/adoquín/tierra -> textura del piso.
- sidewalk= : vereda y a qué lado (both/left/right/no) -> dibujar veredas.
- name= : nombre de la calle -> cartel.
- maxspeed=, lit= : extra (iluminación de noche, velocidad).

Dirección/bearing: NO es un tag -> se CALCULA del primer y último punto de la geometría (ángulo con atan2). Es la base de la opción (b) "preservar norte real" del ADR 0007.

## Atributos de EDIFICIOS (building) — para extrusión y tipo
Query: way["building"](around:R,LAT,LON); out geom;  (mismo patrón que calles).
- building= : tipo (yes, house, apartments, commercial, retail, industrial, hospital, church...) -> sprite/forma.
- building:levels= : nº de pisos -> altura de extrusión (regla OSM: ~3 m por piso si no hay height).
- height= : altura exacta en metros (si está).
- roof:shape= : flat, gabled, hipped, dome, mansard... -> sprite de techo.
- roof:material= / building:material= : material -> color/textura.
- amenity= : uso (school, bank, hospital, restaurant...) -> decoración/cartel.
- (geometría): el footprint (planta) es el polígono -> base que se extruye.

Datos faltantes: OSM es incompleto y desparejo. Tener siempre defaults sensatos (sin building:levels -> 2 pisos; sin ancho -> según tipo). La escena nunca debe romperse por un tag ausente.

## Costo y conectividad (importante)
- Overpass NO tiene API key y es GRATIS: infraestructura de la comunidad OSM, sin registro ni tarjeta. Única condición: FAIR-USE (User-Agent, no martillar, no usarlo como backend de producción de alto volumen). No hay factura, pero TAMPOCO hay SLA/garantía (puede estar lento o caído).
- ¿Internet en cada escena? Solo la PRIMERA vez de cada punto. Flujo:
  1. Punto nuevo (nunca visitado) -> 1 consulta online -> se guarda.
  2. Punto ya cacheado -> se lee de disco -> OFFLINE, instantáneo, sin tocar Overpass.
  Como el juego es territorial sobre el barrio del jugador, las escenas son de un área acotada y repetida (su base, sus calles) -> se baja la zona una vez y se juega casi todo offline. Churn de puntos nuevos bajo.
- Arquitectura de caché en DOS niveles:
  1. Caché local (disco) -> ya hecho (StreetsRepository). "No volver a pedir lo mismo".
  2. Backend propio (Etapa 6) ⭐ -> TU servidor pre-procesa las zonas (con Overpass o un extracto Geofabrik) UNA vez, las guarda y se las sirve a los jugadores. Así NINGÚN jugador llama a Overpass directo. Overpass queda solo en el pipeline de preparación, NO en el runtime del jugador.
- Regla: Overpass = herramienta de desarrollo/preparación, no dependencia en vivo del jugador final. En el prototipo se llama directo (ok para el spike); en producción se mueve detrás del backend.

## "Backend propio" NO significa replicar toda la BD de OSM
Malentendido común. Overpass NO es "una BD para descargar": es un SERVICIO de consultas. Lo que existe para bajar es el dato crudo de OSM (el "planet"). Tamaños reales:
- Planet completo (.osm.pbf): ~80 GB comprimido (>1 TB sin comprimir). NADIE baja esto para un juego.
- Extracto de país (Geofabrik, ej. Argentina): cientos de MB a pocos GB. Solo si hace falta.
- Extracto de región/ciudad: pocos MB a decenas de MB.
- Una escena (un hexágono) vía Overpass: KB.

Estrategias de backend, de liviana a pesada:
1. Caché incremental bajo demanda ⭐ (la simple): el backend NO precarga nada. Punto nuevo -> consulta Overpass esa vez -> guarda KB en tu BD -> siguiente jugador lo recibe de tu caché. Tu BD crece SOLO con las zonas realmente jugadas (chiquísimo en un juego de barrio). Mismo patrón de caché que ya hicimos, del lado del servidor.
2. Extracto regional (si querés pre-cargar): bajás de Geofabrik SOLO tu ciudad/región (pocos MB-GB), la procesás una vez y la servís; sin depender de Overpass en runtime.
3. Instancia propia de Overpass (solo a gran escala): tu propio server Overpass alimentado por un extracto. Opción pesada; innecesaria para empezar.

Respuesta corta: NO se replica nada masivo y NO se baja la BD entera. Camino natural = (1) caché incremental bajo demanda (KB por zona). Solo al crecer mucho se pasa a (2) o (3). Los 80 GB del planet nunca entran en juego para un título de barrio.

## Otros servicios (complementarios, no reemplazo)
- Overpass (en uso): dato crudo con TODOS los tags + geometría de un área puntual -> ideal para generar escenas.
- Protomaps / PMTiles: OSM empaquetado en UN archivo de vector tiles, sin API key, bundleable/self-host. A futuro: producción, offline a escala, Modo Mapa macro. Dato más generalizado (menos tags finos).
- OpenFreeMap / vector tiles OSM.org: sólo tiles de fondo, no aporta a la generación procedural.
- Extracto Geofabrik (.osm.pbf): región entera para procesar offline; pre-procesar y servir desde backend (Etapa 6).

Conclusión: la riqueza está en los tags de OSM; Overpass es quien los entrega completos -> herramienta correcta para escenas Nivel 2/3. Protomaps/Geofabrik para escala/offline en producción.

## Fuentes
- Key:highway, Key:lanes, Sidewalks (OSM Wiki)
- Key:building, Key:building:levels, Key:roof:shape, 3D Development/Tagging (OSM Wiki)
- Protomaps (protomaps.com/about), Overpass API (OSM Wiki)
