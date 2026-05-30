# MAP — guía para Claude Code

Juego móvil de **construcción / defensa / guerra territorial sobre el mapa real** del barrio
(Flutter, touch, mobile-first). Desarrollador en solitario (Daniel, trabaja **en español**).

- **Punto de entrada / estado completo:** [`docs/HANDOFF.md`](docs/HANDOFF.md)
- **Decisiones:** `docs/decisions/` (ADRs 0001–0006) · **Docs vivos:** `docs/`
- **Prototipo jugable:** [`map_spike/`](map_spike/)

## Skills del proyecto (se auto-usan según su descripción; a mano: `/<nombre>`)
- **flutter-apply-architecture-best-practices** — estructurar/refactorizar a capas
  (UI-MVVM / Data / Domain). *(Se usó para reorganizar `map_spike/`.)*
- **flutter-fix-layout-issues** — errores de layout (overflow, constraints sin acotar).
- **flutter-caching-data** *(local, a medida)* — persistencia/caché: tiles, imágenes,
  offline-first. *(Se usó para la caché de tiles de MapTiler.)*
- **mobile-game-ui-design** *(local, a medida)* — UI/UX mobile-first del juego: HUD sobre
  mapa vivo, ergonomía táctil (thumb zones, 48dp), feedback de hexágonos, recursos, HUD por
  modo (Base/Exploración), performance de render.

> ⚠️ Los skills locales son **a medida** porque sus equivalentes "oficiales" en **skills.sh**
> resultaron **fabricados / inexistentes** (confirmados falsos: `flutter-caching-data` en
> `flutter/skills`, `davila7/.../mobile-design`). **Regla: verificar todo `SKILL.md` contra el
> raw de GitHub antes de instalar** — no confiar en agregadores.

## Convenciones
- **Doc-driven:** las decisiones grandes van a `docs/` (documentos vivos) y a ADRs; siempre
  actualizar `docs/HANDOFF.md`.
- **Arquitectura de `map_spike/`:** por **capas** (ver `docs/03-architecture.md`). Lógica de
  juego en *repositories/services* (testeable), UI en *ViewModels* + *views* "tontas".
- **Idioma:** español.
- **Verificar antes de commitear:** `flutter analyze` + `flutter test`; correr en emulador para
  cambios de UI. **No commitear ni pushear sin que el usuario lo pida.**
- **Secrets:** la key de MapTiler vive en `map_spike/lib/secrets.dart` (gitignored), fuera del repo.

## Correr / verificar el prototipo
```powershell
# Emulador desacoplado (ver gotcha en HANDOFF: si se lanza desde tarea en bg, se cierra)
& "$env:LOCALAPPDATA\Android\Sdk\emulator\emulator.exe" -avd Pixel_7
cd map_spike; flutter run -d emulator-5554        # r = hot reload · R = hot restart · q = salir
```
Verificación sin emulador: `cd map_spike; flutter analyze; flutter test`.
