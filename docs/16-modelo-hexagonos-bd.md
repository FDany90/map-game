# Modelo de datos de hexágonos: generación lazy (bajo demanda)

> Estado: análisis / decisión preliminar · 2026-05-31
> Documento vivo. Cómo y dónde se guarda el estado de los hexágonos del territorio.
> Relacionado: [03-architecture.md](03-architecture.md) (grilla H3) ·
> [05-economia.md](05-economia.md) · [15-placement-bases-vecinos.md](15-placement-bases-vecinos.md) ·
> Etapa 2 (modelo de datos) y Etapa 6 (backend).

## La pregunta
¿Tenemos una BD con TODOS los hexágonos del planeta, o se van guardando a medida que se crean
bases / se conquista territorio? ¿Un hexágono inexistente en la BD = "sin explorar" hasta que un
jugador interactúa y recién ahí se guarda (zombies, recursos, etc.)?

## Respuesta: generación LAZY (bajo demanda). NO se pre-puebla el planeta.

### Por qué no pre-poblar
El planeta tiene ~510 millones de km². A escala de cuadra, eso son del orden de **miles de
millones de hexágonos** (con H3, varios miles de millones según la resolución). Guardar una fila
por cada uno sería una BD gigantesca y **~99.99% vacía** (casi ninguno se jugará nunca).
Inviable — el mismo error que bajar el planet completo de OSM (~86 GB) para las calles.

### El modelo correcto
**Regla de oro: si un hexágono NO está en la BD, no es que "no existe" — está SIN EXPLORAR.**
La **ausencia ES el estado por defecto** (niebla de guerra). No hace falta una fila para
representar "vacío/desconocido".

```
Hexágono no está en la BD  ->  "sin explorar" (niebla). Default implícito, 0 bytes.
Jugador interactúa         ->  se MATERIALIZA: se crea la fila y se "siembra" su contenido
                              (zombies, recursos, territorio oscuro...). Queda persistido.
A partir de ahí            ->  estado real (explorado / conquistado / oscuro / vecino / en combate).
```

Es el **mismo patrón** que calles/edificios (doc 14): no se guardan todas las del mundo; se
materializa/cachea **solo la zona que se juega**. Acá: se guardan **solo los hexágonos tocados**.

## Qué se guarda y cuándo
- **NO se guarda:** los miles de millones de hexágonos vacíos. Dado un lat/lng, qué hexágono es
  se **calcula** (índice H3 = función matemática), no se consulta una BD.
- **SÍ se guarda (al materializar):**
  - `hexId` — índice **H3** (clave única global, determinística por ubicación).
  - estado — sin explorar → explorado → conquistado / oscuro / en combate.
  - dueño / clan, si aplica.
  - contenido sembrado — zombies, recursos, edificios del combate, etc.
  - timestamps (descubierto, última actividad).
- **Cuándo se crea la fila:** primera interacción real (explorar, reclamar, atacar, poner base).

## Detalle clave: "sembrar" debe ser DETERMINISTA — y por GRADIENTE, no random
Al descubrir un hexágono por primera vez, ¿qué tiene? El contenido se siembra con una **semilla
derivada del `hexId`** (seed determinístico), **no random puro**. Beneficios:
- El mismo hexágono "tiene lo mismo" sin importar **quién lo descubre primero** (justo y reproducible).
- Se puede calcular un **preview** de un hexágono sin haberlo guardado aún.

⚠️ **La dificultad NO puede ser aleatoria** (rompería el balance: si te toca un hexágono lleno de
zombies/bosses al empezar, no podés jugar). Debe ser un **GRADIENTE determinista** según la posición:

```
dificultad(hex) = f(
    distancia a la zona de inicio del jugador,    // cerca del spawn = fácil
    densidad urbana del OSM (edificios/calles),   // urbano/poblado = fácil; descampado = difícil
    distancia a spawns/civilización de jugadores  // domesticado = fácil; salvaje = difícil
) + variación menor determinista por hexId        // textura, NO azar que rompa el balance
```

- **Sale gratis del OSM** (doc 14): densidad de `building=*` y tipo de calles = "qué tan civilizada"
  es la zona. El mapa real **ya provee el gradiente**.
- **Temáticamente perfecto** para apocalipsis zombie: lo seguro es donde hay gente/refugio; lo
  peligroso es el descampado solitario. Risk/reward: más lejos = más difícil pero mejor botín.
- Sigue siendo **determinista** (mismo hex = misma dificultad para todos) pero la fórmula
  **garantiza balance** en vez de depender de la suerte.

## Onboarding: nacer es SEGURO (no aleatorio)
- El jugador **nace sin base, solo con su personaje humano**, en un hexágono **garantizado de baja
  dificultad** (zona de inicio / safe zone). NO se nace en un punto random que pueda ser imposible.
- Se **empieza explorando**, no conquistando ni peleando hordas.
- Los **hexágonos vecinos al spawn** son fáciles → margen para aprender y crecer antes de toparse
  con algo difícil. La dificultad **sube suave** a medida que el jugador se aleja (gradiente de arriba).

## Dónde vive
- **Prototipo (hoy):** en memoria (`TerritoryRepository`), un `Set` de hexágonos reclamados.
- **Producción (Etapa 6, BaaS Supabase/Firebase):** tabla `hexagons` indexada por `hexId`, sparse
  (solo materializados). El `TerritoryRepository` pasa a ser la fachada de esa tabla **sin tocar
  UI ni ViewModel** (la arquitectura por capas ya deja ese seam listo).
- **Caché local:** el cliente cachea los hexágonos de su zona (igual que tiles y calles) →
  responde rápido y reduce lecturas al backend.

## Consecuencias
- BD **sparse**: crece solo con lo jugado. Un barrio activo = miles de filas, no miles de millones.
- Escala natural: zonas sin jugadores = 0 costo de almacenamiento.
- `hexId` H3 como clave global evita choques entre jugadores (mismo lugar → mismo id).
- Encaja con anti-solapamiento de bases (doc 15): el hex es la unidad de ocupación.

## Preguntas abiertas (para Etapa 2 / 6)
- Resolución H3 a usar (tamaño del hexágono) → fija densidad de bases y nº de hexágonos por barrio.
- ¿El contenido sembrado es 100% determinista, o se "re-siembra" con el tiempo (los zombies
  reaparecen)? Conecta con la economía anti-idle (doc 05).
- Política de expiración/decay de hexágonos inactivos (¿vuelven a "sin explorar"?).
- Reconciliación de escrituras concurrentes (dos jugadores tocan el mismo hex a la vez).
- **Calibrar la curva del gradiente:** qué radio de "zona segura" alrededor del spawn, cuán rápido
  sube la dificultad con la distancia, y cómo pesar "distancia al spawn" vs "densidad urbana OSM"
  vs "cercanía a otros jugadores". Conecta con la densidad de jugadores por barrio (HANDOFF #5).
- ¿La zona de inicio es un punto fijo elegido por el sistema, o el jugador elige entre varias safe
  zones cercanas a su ubicación real?
