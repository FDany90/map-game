# ADR 0001 — Stack: Flutter + Flame

- **Estado:** Aceptado
- **Etapa:** 1

## Contexto

Juego móvil 2D basado en mapa, de gestión/estrategia con combate que se resuelve casi
solo. Desarrollado por una sola persona, con experiencia previa en JavaScript, Unity,
Node.js y algo de Java. Requisito explícito: que **se sienta una App nativa** (rendimiento,
ícono en la tienda), no una web app.

## Opciones consideradas

1. **Web app / PWA** — descartada: los jugadores de móvil casi no juegan web apps, peor
   rendimiento en animaciones/mapa, peor retención. Útil solo para prototipado desechable.
2. **Unity** — descartada: pensado para 3D/física/reflejos. La integración de mapas reales
   es engorrosa (su SDK de Mapbox está semi-abandonado) y es pesado para un prototipo en
   solitario. El juego es "una base de datos con un mapa lindo y combate automático".
3. **React Native** — válida (el usuario sabe JS), pero peor rendimiento para animaciones
   de juego y soporte de mapas menos sólido que Flutter.
4. **Flutter + Flame** — elegida.

## Decisión

Usar **Flutter** para la app (una base de código → Android e iOS nativos) y **Flame**
(motor 2D sobre Flutter) para la vista de juego, sprites, cámara y game loop.

- Flutter: menús, HUD, tiendas, login.
- Flame: vista de juego (mapa, hexágonos, sprites, combate).
- Conviven en la misma app vía `GameWidget`.

## Consecuencias

- **+** App nativa real, 60fps, ícono en tienda, una sola base de código.
- **+** Flame es conceptualmente parecido a Unity (Component ≈ GameObject, `update(dt)` ≈ Update()).
- **−** Hay que aprender **Dart** (fácil viniendo de JS/Java).
- **−** El render del mapa real no viene "de fábrica": hay que resolverlo (ver ADR 0002).
