import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:latlong2/latlong.dart';

import '../../../../config/app_config.dart';
import '../../../../data/repositories/streets_repository.dart';
import '../../../../domain/models/streets_source.dart';
import '../../../../domain/models/zombie.dart';

/// Un disparo de la torreta (efecto visual efímero): línea base → zombie.
class Shot {
  Shot({required this.from, required this.to, required this.ttl});
  final LatLng from;
  final LatLng to;
  int ttl; // vidas (ticks) restantes
}

/// Spike L0 "carriles de calle": spawnea zombies en los extremos de las calles
/// cercanas y los camina por la polyline hacia la base; una torreta con rango
/// los mata al acercarse. VISUAL/aproximado, sin pathfinding
/// (ver `docs/11-zombies-calles-cost.md`).
class ZombieSpikeViewModel extends ChangeNotifier {
  ZombieSpikeViewModel({
    required StreetsRepository streetsRepository,
    this.base = AppConfig.initialCenter,
  }) : _streetsRepo = streetsRepository { // ignore: prefer_initializing_formals
    _init();
  }

  final StreetsRepository _streetsRepo;

  /// Posición de la base/torreta (centro).
  final LatLng base;

  // --- parámetros del spike (tuneables) ---
  static const double spawnRadiusMeters = 300;
  static const double turretRangeMeters = 130;
  static const double zombieSpeedMps = 12; // velocidad de juego (no realista)
  static const int maxActive = 14;
  static const int rewardPerKill = 5;
  static const Duration _spawnEvery = Duration(milliseconds: 1500);
  static const Duration _tick = Duration(milliseconds: 50);
  static const double _tickSeconds = 0.05;

  static const Distance _distance = Distance();

  final Random _rng = Random();
  final List<Zombie> _zombies = [];
  final List<Shot> _shots = [];
  List<List<LatLng>> _streets = const [];

  bool _loading = true;
  StreetsSource _source = StreetsSource.fallback;
  int _kills = 0;
  int _breaches = 0;
  int _nextId = 0;

  Timer? _spawnTimer;
  Timer? _tickTimer;

  // --- getters para la View ---
  bool get loading => _loading;
  StreetsSource get source => _source;
  List<List<LatLng>> get streets => _streets;
  List<Zombie> get zombies => List.unmodifiable(_zombies);
  List<Shot> get shots => List.unmodifiable(_shots);
  int get kills => _kills;
  int get breaches => _breaches;
  int get activeCount => _zombies.length;
  int get supplies => _kills * rewardPerKill;
  double get turretRange => turretRangeMeters;

  Future<void> _init() async {
    final result = await _streetsRepo.getStreetsAround(
      base,
      radiusMeters: spawnRadiusMeters,
    );
    _streets = result.streets;
    _source = result.source;
    _loading = false;
    notifyListeners();

    _spawnTimer = Timer.periodic(_spawnEvery, (_) => _spawn());
    _tickTimer = Timer.periodic(_tick, (_) => _step());
  }

  void _spawn() {
    if (_zombies.length >= maxActive || _streets.isEmpty) return;
    final street = _streets[_rng.nextInt(_streets.length)];
    if (street.length < 2) return;
    _zombies.add(Zombie(id: _nextId++, path: _orientedTowardBase(street)));
  }

  /// Ordena la calle de modo que el primer punto sea el más lejano a la base
  /// (spawn afuera) y el último el más cercano (camina hacia adentro).
  List<LatLng> _orientedTowardBase(List<LatLng> pts) {
    final farFirst = _distance(pts.first, base) >= _distance(pts.last, base);
    return farFirst ? List.of(pts) : pts.reversed.toList();
  }

  void _step() {
    const step = zombieSpeedMps * _tickSeconds; // metros por tick
    final survivors = <Zombie>[];
    for (final z in _zombies) {
      _advance(z, step);
      if (_distance(z.position, base) <= turretRangeMeters) {
        _shots.add(Shot(from: base, to: z.position, ttl: 4)); // disparo + muerte
        _kills++;
      } else if (z.reachedEnd) {
        _breaches++; // llegó al final sin entrar en rango: despawn
      } else {
        survivors.add(z);
      }
    }
    _zombies
      ..clear()
      ..addAll(survivors);
    _shots.removeWhere((s) => --s.ttl <= 0);
    notifyListeners();
  }

  /// Avanza [meters] al zombie a lo largo de su polyline y recalcula su posición.
  void _advance(Zombie z, double meters) {
    var remaining = meters;
    while (remaining > 0 && !z.reachedEnd) {
      final a = z.path[z.segment];
      final b = z.path[z.segment + 1];
      final segLen = _distance(a, b);
      if (segLen == 0) {
        z.segment += 1;
        z.tInSegment = 0;
        continue;
      }
      final covered = z.tInSegment * segLen;
      final toEnd = segLen - covered;
      if (remaining < toEnd) {
        z.tInSegment = (covered + remaining) / segLen;
        remaining = 0;
      } else {
        remaining -= toEnd;
        z.segment += 1;
        z.tInSegment = 0;
      }
    }
    if (z.reachedEnd) {
      z.position = z.path.last;
    } else {
      final a = z.path[z.segment];
      final b = z.path[z.segment + 1];
      z.position = LatLng(
        a.latitude + (b.latitude - a.latitude) * z.tInSegment,
        a.longitude + (b.longitude - a.longitude) * z.tInSegment,
      );
    }
  }

  @override
  void dispose() {
    _spawnTimer?.cancel();
    _tickTimer?.cancel();
    super.dispose();
  }
}
