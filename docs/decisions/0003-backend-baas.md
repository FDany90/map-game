# ADR 0003 — Backend como servicio (BaaS)

- **Estado:** Propuesto (a confirmar en Etapa 6)
- **Etapa:** 1 (propuesta) / 6 (confirmación)

## Contexto

El juego es social: el estado del territorio (quién posee cada hexágono, qué construyó,
economía) tiene que compartirse entre jugadores vecinos. El desarrollo es en solitario.
El combate del Modo Base se resuelve en diferido, así que **no** hace falta un servidor de
tiempo real corriendo simulación.

## Opciones consideradas

1. **Servidor propio (Node.js).** El usuario sabe Node, pero mantener auth, base de datos,
   escalado y devops en solitario es mucho costo. Descartado para empezar.
2. **Firebase.** Auth + Firestore (tiempo real) + Cloud Functions. Maduro, generoso para empezar.
3. **Supabase.** Auth + Postgres + Realtime + Edge Functions. SQL (bueno para consultas
   geográficas/relacionales del territorio), open source.

## Decisión (provisional)

Usar un **BaaS** en lugar de servidor propio: **Supabase o Firebase** (decisión final en
Etapa 6, cuando se diseñe el modelo de datos).

- Inclinación inicial hacia **Supabase** por SQL/Postgres (consultas relacionales sobre
  hexágonos y vecinos) y posible uso de extensiones geoespaciales — pero a validar.

## Consecuencias

- **+** Un dev en solitario evita escribir y operar un servidor.
- **+** Auth, base de datos y funciones listas para usar.
- **−** Menos control que un backend propio; posible lock-in.
- **−** Hay que diseñar el modelo de datos pensando en los límites del plan gratuito.
- **Pendiente:** confirmar proveedor al cerrar el modelo de datos (Etapa 2/6).
