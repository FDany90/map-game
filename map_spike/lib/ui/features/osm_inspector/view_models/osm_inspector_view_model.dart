import 'package:flutter/foundation.dart';
import 'package:latlong2/latlong.dart';

import '../../../../config/app_config.dart';
import '../../../../data/repositories/osm_scene_repository.dart';
import '../../../../domain/models/osm_feature.dart';
import '../../../../domain/models/osm_scene.dart';
import '../../../../domain/models/zone_profile.dart';

/// VM del Inspector OSM (Fase 1 del generador de escenas, ADR 0007): el usuario
/// **toca un punto en el mapa** y se consulta + representa la escena cruda de OSM
/// en tiempo real (calles + edificios + áreas con sus tags). Es el ensayo del
/// principio del ADR 0007: "tocás tu esquina → la escena es tu esquina".
///
/// El **radio** es chico por defecto (50 m = "solo mi calle principal"); se puede
/// abrir a 100/150 m para ver las cuadras de alrededor.
class OsmInspectorViewModel extends ChangeNotifier {
  OsmInspectorViewModel({
    required OsmSceneRepository repository,
    LatLng? initialCenter,
    this.radiusMeters = 50,
  })  : _repo = repository,
        _center = initialCenter ?? AppConfig.initialCenter {
    _load();
  }

  final OsmSceneRepository _repo;

  /// Radios disponibles para la **escena** (lo que se dibuja/juega):
  /// 50 = "solo mi calle"; 100/150 = ver más alrededor.
  static const List<double> radiusOptions = [50, 100, 150];

  /// Radio de **contexto** para CLASIFICAR la zona (no para dibujar). Más grande
  /// que la escena a propósito: clasificar bien necesita ver el barrio alrededor
  /// (una avenida sola a 50 m es ambigua; a 200 m se ve si hay trama o sólo
  /// pasto). La escena de combate sigue siendo chica (<100 m). Ver doc 17.
  static const double classificationRadius = 200;

  LatLng _center;
  double radiusMeters;

  bool _loading = true;
  String? _error;
  OsmScene? _scene; // escena fina (radio de chips): overlay + stats
  OsmScene? _context; // contexto 200 m: sólo para clasificar la zona

  bool get loading => _loading;
  String? get error => _error;
  OsmScene? get scene => _scene;
  LatLng get center => _center;

  /// Carácter urbano inferido del punto (denso/casas/parque/ruta/rural). Se
  /// calcula sobre el **contexto de 200 m** (no sobre la escena fina) porque OSM
  /// casi nunca trae edificios y el tipo de barrio se lee del entorno (doc 17).
  ZoneProfile? get zone =>
      _context == null ? null : ZoneProfile.fromScene(_context!);

  Future<void> _load() async {
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      // Dos consultas (ambas cacheadas en disco): la escena fina que se dibuja
      // y el contexto amplio que sólo sirve para clasificar la zona.
      final results = await Future.wait([
        _repo.getSceneAround(_center, radiusMeters: radiusMeters),
        _repo.getSceneAround(_center, radiusMeters: classificationRadius),
      ]);
      _scene = results[0];
      _context = results[1];
    } catch (e) {
      _error = '$e';
      _scene = null;
      _context = null;
    } finally {
      _loading = false;
      notifyListeners();
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
