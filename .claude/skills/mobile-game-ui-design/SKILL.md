---
name: mobile-game-ui-design
description: UI/UX mobile-first para el juego de mapa MAP en Flutter — HUD sobre un mapa vivo (flutter_map), ergonomía táctil (thumb zones, targets de 48dp, una mano), feedback de la grilla de hexágonos, displays de recursos/economía, minimapa, HUD contextual para Modo Base vs Exploración, y performance de render en Flutter. Usar al diseñar o construir cualquier pantalla, HUD, overlay, botón o interacción con el mapa.
metadata:
  type: local
  last_modified: 2026-05-30
---
# Diseño de UI mobile-first para un juego de mapa (MAP)

Guía para diseñar y construir la UI de **MAP** (juego móvil de territorio sobre mapa real,
Flutter + flutter_map, touch, una mano). Sintetiza buenas prácticas de UI móvil y de UI de
juegos, aterrizadas a un HUD que vive **encima de un mapa interactivo**.

Regla rectora: **el mapa es el juego; la UI lo sirve, no lo tapa.** Si el jugador "ve la
interfaz" en vez de jugar, algo está mal.

## Contenido
- [Principios](#principios)
- [Capas de UI: qué va dónde](#capas-de-ui-qué-va-dónde)
- [Ergonomía táctil (una mano)](#ergonomía-táctil-una-mano)
- [HUD sobre un mapa vivo](#hud-sobre-un-mapa-vivo)
- [Interacción con la grilla de hexágonos](#interacción-con-la-grilla-de-hexágonos)
- [Recursos y economía en pantalla](#recursos-y-economía-en-pantalla)
- [Feedback, notificaciones y "juice"](#feedback-notificaciones-y-juice)
- [HUD contextual: Modo Base vs Exploración](#hud-contextual-modo-base-vs-exploración)
- [Performance de render en Flutter](#performance-de-render-en-flutter)
- [Accesibilidad](#accesibilidad)
- [Anti-patrones (ban duro)](#anti-patrones-ban-duro)
- [Checklist](#checklist)

## Principios
1. **Mobile no es un desktop chico.** El jugador está distraído, a una mano, con mala red y
   poca batería. Diseñá para esa realidad.
2. **El mapa manda.** Todo overlay roba área de mapa; cada elemento debe ganarse su lugar.
3. **Información en segundos.** Recursos, amenazas y estado se leen de un vistazo, sin pensar.
4. **El movimiento comunica, no decora.** Animá para guiar la atención (un hex reclamado, un
   drop), no por adorno. Exceso de motion sobre un mapa que ya se mueve = ruido.
5. **Reach > precision.** En el pulgar lo importante es alcanzar, no apuntar fino.
6. **Probá en el peor dispositivo, festejá en el mejor.** Testeá en gama baja y con el mapa
   cargando tiles, no solo en el emulador a 33%.

## Capas de UI: qué va dónde
Pensá la pantalla como capas sobre el `FlutterMap` (un `Stack`):

```
┌─────────────────────────────┐
│  HUD superior: recursos      │ ← SafeArea, no-interactivo (pasa el toque al mapa)
│                              │
│        [ MAPA VIVO ]         │ ← capa base: tiles + grilla de hexágonos
│                              │
│              ┌──── controles │ ← zona del pulgar: zoom, modo, acciones (48dp)
│  barra de acción / contexto  │ ← aparece según selección (reclamar, construir)
└─────────────────────────────┘
```

- **Capa de mapa** (abajo): tiles + `PolygonLayer` de hexágonos + sprites de juego.
- **HUD informativo** (arriba): solo lectura (recursos, alertas). **No debe capturar toques**
  destinados al mapa → envolvé en `IgnorePointer` salvo los elementos realmente tocables.
- **Controles** (abajo/derecha, zona del pulgar): botones de acción y navegación.
- **Capa contextual**: paneles que aparecen al seleccionar un hex o entidad (bottom sheet).

## Ergonomía táctil (una mano)
- **Target mínimo 48x48 dp** (Material) / 44pt (iOS). Nunca menos, aunque el ícono sea chico:
  agrandá el área tocable, no el glifo.
- **Zona del pulgar:** las acciones frecuentes van **abajo y hacia el lado dominante**. El
  tercio superior es "mírame", no "tócame". En MAP los FAB de zoom/modo ya viven abajo-derecha:
  mantené ahí lo accionable.
- **Nada solo-gesto sin alternativa visible.** Un pinch para zoom está bien *además* de botones
  +/−; reclamar un hex es un tap explícito, no un long-press oculto.
- **Separación entre targets ≥ 8dp** para evitar toques erróneos, sobre todo cerca de bordes.
- **Respetá las áreas del sistema:** `SafeArea` para notch/gestos; no pongas controles donde
  vive la barra de gestos de Android/iOS.

## HUD sobre un mapa vivo
El fondo (el mapa) cambia de color y textura todo el tiempo → la legibilidad es el problema #1.
- **Garantizá contraste contra cualquier tile.** Usá un fondo semitransparente oscuro detrás
  del texto (en MAP: `Colors.black.withValues(alpha: 0.72)`), o un borde/halo en el texto.
  No confíes en texto blanco "pelado" sobre el mapa.
- **Jerarquía clara:** label chico + valor grande/bold (el patrón del `EconomyHud` actual).
  Lo importante (suministros, amenaza) más grande; lo secundario (zoom) más chico.
- **Densidad baja.** 3-4 stats máximo en la barra superior. Si necesitás más, agrupá o mové a
  un panel desplegable.
- **HUD pasa-toques:** envolvé los adornos no interactivos en `IgnorePointer` para que pan/zoom
  del mapa funcionen aunque el dedo caiga sobre el HUD.

```dart
// HUD informativo que NO bloquea el mapa debajo:
IgnorePointer(
  child: SafeArea(child: EconomyHud(/* ...snapshots del ViewModel... */)),
)
```

## Interacción con la grilla de hexágonos
La grilla es el control principal del juego. Estados visuales claros:
- **Estados de un hex:** neutro / reclamable / reclamado / oscuro (amenaza) / en combate /
  seleccionado. Cada uno con color y opacidad distintos (hoy: cyan tenue vs verde reclamado).
  No uses **solo color** para distinguir estados críticos (ver accesibilidad).
- **Feedback inmediato al tap:** al reclamar, animá el relleno (fade/scale corto ~150-250ms) y
  un microsonido/haptic. El jugador debe *sentir* que pasó algo.
- **Tolerancia de toque:** el dedo es gordo; resolvé el hex por **cercanía al centro** (como
  hace `HexGridService.nearestHexTo`), no por hit-test exacto del polígono. Ignorá toques fuera
  de radio (no-op silencioso, sin snackbar de error).
- **Selección → contexto:** tocar un hex propio abre un bottom sheet con acciones (construir,
  mejorar), no un menú que tape medio mapa.

## Recursos y economía en pantalla
- **Siempre visibles** los 3 recursos (Materiales / Energía / Combustible) — son el corazón de
  la decisión. Ícono + número; el ícono ayuda a leer de reojo.
- **Mostrá el delta, no solo el total:** "+30/min" comunica más que un número que sube. Cambios
  importantes (te quedás sin energía) → resaltá con color/animación puntual.
- **Anticipá los costos:** al ir a reclamar/construir, mostrá el costo y si alcanza *antes* de
  confirmar (deshabilitá la acción si no alcanza, con motivo claro).
- **Cero "idle infinito" visual:** como la economía es activa/finita, evitá medidores que
  sugieran producción eterna; mostrá agotamiento (loot que baja) para empujar a la actividad.

## Feedback, notificaciones y "juice"
- **Cola de notificaciones, no spam.** Eventos asíncronos (te atacaron, terminó una mejora) van
  a una cola con prioridad; mostrá de a uno, no 5 toasts encimados.
- **Diégesis cuando se pueda:** preferí mostrar el evento *en el mapa* (un pulso en el hex
  atacado) antes que un cartel modal que corta el juego.
- **Haptics y sonido con moderación:** refuerzan acciones (reclamar, error), no cada frame.
- **Microanimaciones cortas (≤300ms)** y con `Curve` (easeOut). Sobre un mapa que ya se mueve,
  menos es más.

## HUD contextual: Modo Base vs Exploración
MAP tiene dos modos (jugar desde casa vs GPS en vivo). La UI **no es la misma**:
- **Modo Base (núcleo, asíncrono):** foco en gestión — recursos, grilla, colas de construcción,
  combate diferido. HUD más denso/informativo está OK.
- **Modo Exploración (GPS, activo):** foco en el momento — minimiza chrome, agranda lo
  accionable, muestra **combustible** y posición. Menos texto, más glanceable (vas caminando).
- **Mostrá solo lo del modo actual.** No arrastres controles de Base a Exploración. Transición
  clara entre modos (no un toggle escondido).

## Performance de render en Flutter
Un mapa con tiles + decenas de polígonos + HUD animado puede tirar el FPS. Claves:
- **`const` en todo widget estático** (lo pide hasta el linter): el HUD, íconos, textos fijos.
- **Acotá los rebuilds.** Usá `ListenableBuilder`/`Selector` alrededor de **lo que cambia**, no
  de toda la pantalla. En MAP el `ListenableBuilder` envuelve el contenido del mapa; si el HUD
  late 4x/seg, que **solo** el HUD se reconstruya, no la `PolygonLayer` entera.
- **`RepaintBoundary`** alrededor de capas que se repintan a otro ritmo (HUD animado vs mapa).
- **No regeneres la grilla por frame.** Generala una vez (ya se hace en el ViewModel) y exponé
  snapshots; evitá `List.unmodifiable(...)` en el `build` si la lista es grande (cacheá la vista).
- **Tiles:** caché activada (ver skill de caching) para no recargar ni quemar requests al panear.
- **Medí, no adivines:** DevTools → Performance/Frame chart antes de optimizar.

## Accesibilidad
- **No solo color.** Estados críticos del hex (amenaza, en combate) además de color: ícono,
  patrón o borde. ~8% de los hombres tiene daltonismo.
- **Texto escalable y legible:** respetá el text scale del sistema; mínimo ~11sp para labels,
  valores más grandes. Probá con fuente grande del sistema.
- **Contraste suficiente** (apuntá a WCAG AA) del texto del HUD contra el peor tile.
- **Targets generosos** (ya cubierto): ayuda a motricidad fina y a "pulgar sudado".
- **`Semantics`** en controles para lectores de pantalla cuando el proyecto madure.

## Anti-patrones (ban duro)
- ❌ Targets táctiles < 48dp.
- ❌ Acción importante **solo por gesto** sin control visible.
- ❌ Texto del HUD sin fondo/borde, ilegible sobre tiles claros.
- ❌ HUD que **captura toques** destinados al pan/zoom del mapa.
- ❌ Distinguir estados críticos **solo por color**.
- ❌ Modal/cartel que tapa el mapa para algo que podría mostrarse en el mapa.
- ❌ Spam de toasts encimados; animaciones largas/permanentes sobre un mapa en movimiento.
- ❌ Reconstruir toda la pantalla (o la grilla) en cada tick de economía.
- ❌ Arrastrar el chrome de Modo Base a Modo Exploración.

## Checklist
- [ ] Todo control accionable ≥ 48dp y en la zona del pulgar (abajo/lado dominante).
- [ ] HUD informativo en `IgnorePointer` + `SafeArea`; el mapa recibe pan/zoom debajo.
- [ ] Texto del HUD legible sobre el peor tile (fondo/borde, contraste AA).
- [ ] Estados del hex distinguibles sin depender solo del color; feedback al tap (anim+haptic).
- [ ] 3 recursos siempre visibles con delta; costos mostrados antes de confirmar.
- [ ] Notificaciones en cola (no spam); eventos diegéticos en el mapa cuando se pueda.
- [ ] HUD del modo correcto (Base vs Exploración), sin controles cruzados.
- [ ] Rebuilds acotados (`ListenableBuilder`/`Selector`), `const` widgets, caché de tiles ON.
- [ ] Probado en gama baja / con el mapa cargando, no solo en emulador.
