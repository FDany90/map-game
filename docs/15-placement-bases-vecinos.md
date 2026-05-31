# Placement de bases: vecinos en la misma cuadra (anti-solapamiento)

> Estado: análisis / problema abierto · 2026-05-31
> Documento vivo. Cómo evitar que las bases de jugadores cercanos se solapen en el mapa.
> Relacionado: [ADR 0007](decisions/0007-estrategia-visual-mapa-iconos-escenas-isometricas.md)
> (mapa = iconos) · [13-modos-pantallas-backlog.md](13-modos-pantallas-backlog.md) (Modo Mapa, LOD).

## El problema
Si 5 vecinos de la misma cuadra entran al juego, sus bases caen en ubicaciones GPS casi idénticas
→ los **iconos se solapan/tapan** en el Modo Mapa y no se distinguen. Aunque el icono sea chico,
una cuadra puede juntar muchos jugadores.

Dos sub-problemas:
1. **Lógico:** ¿dos bases pueden ocupar el "mismo lugar" del territorio? (regla de juego)
2. **Visual:** aunque sean lugares distintos, los iconos muy juntos se pisan (legibilidad).

## Enfoque recomendado: el territorio es DISCRETO (la grilla de hexágonos ya lo resuelve)
El proyecto ya usa **hexágonos** como unidad de territorio. La clave: **una base ocupa un
hexágono (o celda), no un punto GPS exacto.**

- Al crear la base, se **snapea** la ubicación del jugador al hexágono que la contiene.
- **Regla de ocupación:** un hexágono = una base (o N slots fijos por hexágono). Si tu hexágono
  está tomado, tu base va al **hexágono libre más cercano** (o a un slot libre dentro de la celda).
- Así **nunca** hay dos bases en el mismo punto: el espacio está cuantizado. El vecino queda
  **al lado** (hexágono contiguo), no encima.

Esto convierte "ubicación continua que se solapa" en "casilleros discretos que se asignan" — mucho
más fácil de razonar y de mostrar.

## Opciones de asignación (de simple a rica)
| Opción | Cómo | Pro / Contra |
|---|---|---|
| **A. 1 base por hexágono** ⭐ | snap al hex; si está ocupado → hex libre más cercano | Simple, claro; el barrio se "reparte" en celdas. La densidad la fija el tamaño del hex. |
| **B. Slots por calle/cuadra** | N posiciones fijas a lo largo de la calle (usa la geometría OSM); asignar el slot libre más cercano | Se siente "sobre la calle real"; control fino de densidad. Más lógica. |
| **C. Sin grilla + repulsión** | guardar punto real, pero al renderlar separar iconos que estén muy juntos (offset visual) | No cambia el modelo de datos; pero es solo cosmético y puede "mentir" la ubicación. |

**Recomendación:** **A** (encaja con la grilla que ya existe), con **B** como evolución si se
quiere granularidad "por dirección de calle". **C** sirve como ayuda visual extra, no como solución.

## Capa visual (independiente de la regla): que los iconos no se tapen
Aunque el lugar sea único, a ciertos zoom los iconos se amontonan. Soluciones estándar (Modo Mapa):
- **Clustering:** a zoom bajo, agrupar iconos cercanos en un solo "racimo" con contador (ej. "5")
  que al acercar se abre. Lo hacen casi todos los mapas con muchos POIs.
- **LOD** (ya en backlog, doc 13): qué se muestra según zoom — lejos = clústers/regiones por clan;
  cerca = bases individuales.
- **Spiderfy / fan-out:** al tocar un clúster muy denso, abrir los iconos en abanico.

## Preguntas de diseño abiertas
- **¿Densidad por barrio?** Conecta con el hueco de investigación "densidad mínima/máxima de
  jugadores por barrio" (HANDOFF #5). El tamaño del hexágono fija cuántas bases entran por zona.
- **¿Qué pasa si el barrio se llena?** ¿Se empuja a hexágonos vecinos, hay lista de espera, o el
  territorio se vuelve disputable (PvP)? — encaja con la guerra territorial del GDD.
- **¿La base "real" importa o es simbólica?** Si se permite elegir/mover dentro de un radio, baja
  la presión de solapamiento sin romper el "es mi barrio".

## Decisión preliminar
Territorio **discreto por hexágono** (opción A) para la regla de ocupación + **clustering/LOD**
para la legibilidad visual. Confirmar al diseñar el Modo Mapa y el modelo de datos (Etapa 2).