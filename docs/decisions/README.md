# Registro de decisiones de arquitectura (ADRs)

Cada decisión técnica importante se registra como un ADR (Architecture Decision Record):
contexto, decisión y consecuencias. No se borran; si una decisión cambia, se crea un ADR
nuevo que reemplaza al anterior (y se marca el viejo como *Reemplazado*).

| # | Decisión | Estado |
|---|----------|--------|
| [0001](0001-stack-flutter-flame.md) | Stack: Flutter + Flame | Aceptado |
| [0002](0002-mapa-dentro-del-motor.md) | El mapa se renderiza dentro del motor | ❌ Reemplazado por 0006 |
| [0003](0003-backend-baas.md) | Backend como servicio (BaaS) | Propuesto |
| [0004](0004-tiles-raster-estilizados.md) | Tiles raster estilizados para el prototipo | Aceptado |
| [0005](0005-proveedor-tiles-maptiler.md) | Proveedor de tiles: MapTiler | Aceptado |
| [0006](0006-mapa-flutter-map-flame-combate.md) | Mapa con flutter_map; Flame diferido al combate | Aceptado |
