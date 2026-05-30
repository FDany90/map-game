# Spike 01 — Integración MapTiler + Flutter (desechable)

> Estado: en curso · Etapa 4 (versión mínima, smoke test)
> ⚠️ **Código desechable / de aprendizaje.** Usa el paquete `flutter_map`, **no** la
> arquitectura final de mapa-en-Flame (ver [ADR 0002](decisions/0002-mapa-dentro-del-motor.md)).
> Objetivo: validar API key de MapTiler + tiles renderizando + tap para crear un objeto.

## Objetivo del spike

Responder, con algo corriendo en el emulador:
1. ¿Mi API key de MapTiler funciona y se ven los tiles?
2. ¿Se ve fluido el zoom/pan?
3. ¿Puedo tocar la pantalla y crear un objeto (marcador) sobre el mapa?

No valida el tile-loader en Flame (eso es la Etapa 4 formal).

## Requisitos a instalar (Windows)

### 1. Flutter SDK
- Descargar de https://docs.flutter.dev/get-started/install/windows (el ZIP de Flutter).
- Extraer en una ruta sin espacios, p. ej. `C:\src\flutter`.
- Agregar `C:\src\flutter\bin` al **PATH** del usuario.
- Abrir una terminal nueva y verificar: `flutter --version`.

### 2. Android Studio (trae el SDK de Android + emulador)
- Descargar de https://developer.android.com/studio e instalar.
- En el primer arranque, dejar que instale el Android SDK.
- Crear un emulador: **Device Manager → Create Device** (p. ej. Pixel, con una imagen de
  sistema reciente). Arrancarlo.

### 3. Git (para versionar)
- Descargar de https://git-scm.com/download/win e instalar.

### 4. Verificar todo
```
flutter doctor
flutter doctor --android-licenses   # aceptar las licencias
```
`flutter doctor` debe mostrar OK en Flutter y Android toolchain. (Lo de iOS/Xcode en
Windows queda en rojo y está bien — no compilamos para iPhone acá.)

## Crear el proyecto

```
cd c:\Users\DanielAlbertoFernand\MAP
flutter create map_spike
cd map_spike
```

## Dependencias

Editar `map_spike/pubspec.yaml`, en `dependencies:` agregar:

```yaml
dependencies:
  flutter:
    sdk: flutter
  flutter_map: ^7.0.2
  latlong2: ^0.9.1
```

Luego:
```
flutter pub get
```

## API key de MapTiler

1. Crear cuenta gratis en https://www.maptiler.com/
2. Ir a **Account → API keys** y copiar la key.
3. Pegarla en el código (constante `maptilerKey`).

> Para el spike la dejamos hardcodeada. En el proyecto real va fuera del repo (ya está en
> `.gitignore`).

## Código

Reemplazar **todo** el contenido de `map_spike/lib/main.dart` por:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

void main() => runApp(const MapSpikeApp());

class MapSpikeApp extends StatelessWidget {
  const MapSpikeApp({super.key});
  @override
  Widget build(BuildContext context) {
    return const MaterialApp(title: 'MAP Spike', home: MapScreen());
  }
}

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});
  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  // 1) Pegá tu API key de MapTiler:
  static const String maptilerKey = 'TU_API_KEY';
  // 2) Estilo del mapa (probá 'streets-v2', 'basic-v2'; hay estilos oscuros en el dashboard):
  static const String style = 'streets-v2';

  final List<LatLng> _objetos = [];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('MAP spike — ${_objetos.length} objetos')),
      body: FlutterMap(
        options: MapOptions(
          initialCenter: const LatLng(-34.6037, -58.3816), // cambialo a tu zona
          initialZoom: 16,
          onTap: (tapPosition, latLng) {
            setState(() => _objetos.add(latLng));
          },
        ),
        children: [
          TileLayer(
            urlTemplate:
                'https://api.maptiler.com/maps/$style/{z}/{x}/{y}.png?key=$maptilerKey',
            userAgentPackageName: 'com.example.map_spike',
          ),
          MarkerLayer(
            markers: [
              for (final p in _objetos)
                Marker(
                  point: p,
                  width: 40,
                  height: 40,
                  child: const Icon(Icons.local_fire_department,
                      color: Colors.red, size: 40),
                ),
            ],
          ),
          const RichAttributionWidget(
            attributions: [
              TextSourceAttribution('© MapTiler © OpenStreetMap contributors'),
            ],
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => setState(() => _objetos.clear()),
        child: const Icon(Icons.clear),
      ),
    );
  }
}
```

## Correr

Con el emulador andando:
```
flutter run
```

## Qué deberías ver

- El mapa de MapTiler centrado en la coordenada puesta, con zoom/pan fluido.
- Al **tocar**: aparece un ícono (🔥) en ese punto; el contador del título sube.
- El botón flotante limpia los objetos.

## Notas

- **GPS:** en el emulador es simulado; por eso centramos con una coordenada fija. La
  posición real (paquete `geolocator`) es un paso posterior.
- **Permiso de Internet:** en modo debug (`flutter run`) funciona por defecto. Para builds
  de release hay que declarar el permiso INTERNET en el `AndroidManifest`.
- **Atribución:** MapTiler/OSM exigen atribución; ya está incluida con `RichAttributionWidget`.

## Resultado ✅ (2026-05-29)

- [x] Tiles de MapTiler se ven en el emulador (estilo `streets-v2`, zona Obelisco/BA)
- [x] Zoom/pan fluido
- [x] Tap crea objeto (marcadores 🔥 sobre el mapa, contador funcionando)
- Observaciones:
  - Entorno validado de punta a punta: Flutter + emulador Android + `flutter_map` + MapTiler.
  - Primer build de Gradle ~321s; los siguientes son mucho más rápidos.
  - **Pendiente / no validado en este spike:** renderizar tiles dentro de Flame con cámara
    propia (la arquitectura real del ADR 0002) — eso es la Etapa 4 formal.
