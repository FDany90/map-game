import 'package:flutter/foundation.dart';
import 'package:latlong2/latlong.dart';

import '../../../../config/app_config.dart';
import '../../../../data/repositories/osm_scene_repository.dart';
import '../../../../data/services/nominatim_service.dart';
import '../../../../domain/models/osm_feature.dart';
import '../../../../domain/models/osm_scene.dart';
import '../../../../domain/models/zone_profile.dart';

/// VM del Inspector OSM (Fase 1 del generador de escenas, ADR 0007): el usuario
/// **toca un punto en el mapa** y se consulta + representa la escena cruda de OSM
/// en tiempo real (calles + edificios + áreas con sus tags). Es el ensayo del
/// principio del ADR 0007: "tocás tu esquina → la escena es tu esquina".
///
/// El **radio** por defecto es 150 m: suficiente para concluir la categoría de
/// zona y, de la **misma** escena, representar la calle del punto tocado. Una
/// sola consulta a OSM (clasificar + dibujar salen de los mismos datos).
class OsmInspectorViewModel extends ChangeNotifier {
  OsmInspectorViewModel({
    required OsmSceneRepository repository,
    required NominatimService nominatim,
    LatLng? initialCenter,
    this.radiusMeters = 150,
  })  : _repo = repository,
        _nominatim = nominatim, // ignore: prefer_initializing_formals
        _center = initialCenter ?? AppConfig.initialCenter {
    _load();
  }

  final OsmSceneRepository _repo;
  final NominatimService _nominatim;

  /// Radios disponibles. 150 m (default) ya alcanza para clasificar; 100/200 m
  /// para ajustar contexto. Con el mismo radio se clasifica Y se dibuja.
  static const List<double> radiusOptions = [100, 150, 200];

  LatLng _center;
  double radiusMeters;

  bool _loading = true;
  String? _error;
  OsmScene? _scene;
  PlaceAddress? _address;
  int _loadSeq = 0; // descarta respuestas de geocoding viejas (taps rápidos)

  bool get loading => _loading;
  String? get error => _error;
  OsmScene? get scene => _scene;
  LatLng get center => _center;

  /// Dirección (calle + altura) del punto, para ubicarlo y cotejar en Google
  /// Maps. Llega un instante después de la escena (reverse geocoding aparte).
  PlaceAddress? get address => _address;

  /// Carácter urbano inferido del punto (denso/casas/parque/ruta/rural). Se
  /// calcula sobre la **misma** escena consultada (OSM casi nunca trae edificios,
  /// el tipo de barrio se lee de las calles del entorno; ver doc 17).
  ZoneProfile? get zone =>
      _scene == null ? null : ZoneProfile.fromScene(_scene!);

  Future<void> _load() async {
    final seq = ++_loadSeq;
    _loading = true;
    _error = null;
    _address = null;
    notifyListeners();
    try {
      // Una sola consulta a OSM (cacheada en disco): de acá salen tanto la
      // clasificación de zona como el overlay/stats que se dibujan.
      _scene = await _repo.getSceneAround(_center, radiusMeters: radiusMeters);
    } catch (e) {
      _error = '$e';
      _scene = null;
    } finally {
      _loading = false;
      notifyListeners();
    }
    // Dirección del punto: servicio aparte (Nominatim), bajo demanda, no bloquea
    // la escena y si falla no es crítico. Solo aplica si sigue siendo el tap actual.
    if (seq == _loadSeq && _error == null) {
      final addr = await _nominatim.reverse(_center);
      if (seq == _loadSeq) {
        _address = addr;
        notifyListeners();
      }
    }
  }

  Future<void> reload() => _load();

  /// Punto tocado en el mapa → consultar y representar ese punto.
  Future<void> setCenter(LatLng center) async {
    _center = center;
    await _load();
  }

  /// Cambia el radio (m) y recarga.
  Future<void> setRadius(double meters) async {
    if (meters == radiusMeters) return;
    radiusMeters = meters;
    await _load();
  }

  // --- estadísticas derivadas (presentación) ---

  /// Cuenta de valores de un tag, de mayor a menor (ej. `highway` → footway×85…).
  List<MapEntry<String, int>> tally(List<OsmFeature> fs, String key) {
    final m = <String, int>{};
    for (final f in fs) {
      final v = f.tags[key];
      if (v != null) m[v] = (m[v] ?? 0) + 1;
    }
    final entries = m.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return entries;
  }

  /// % de features que tienen el tag [key] (cobertura de OSM en la zona).
  int coveragePct(List<OsmFeature> fs, String key) {
    if (fs.isEmpty) return 0;
    final n = fs.where((f) => f.tags.containsKey(key)).length;
    return (100 * n / fs.length).round();
  }

  /// El feature con más tags (el "más rico"), para mostrar su JSON crudo.
  OsmFeature? richest(List<OsmFeature> fs) {
    if (fs.isEmpty) return null;
    return fs.reduce((a, b) => b.tags.length > a.tags.length ? b : a);
  }
}
