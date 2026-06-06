import 'package:latlong2/latlong.dart';

import 'outpost.dart';

/// Snapshot serializable del estado del jugador (el "save"). Modelo de dominio
/// puro: sabe pasar a/desde JSON pero no toca disco (eso es del `SaveStore`).
///
/// Incluye `version` para **migraciones**: si un save viejo no es compatible,
/// [fromJson] devuelve `null` y la app arranca como save nuevo (doc 22).
class PlayerSave {
  const PlayerSave({
    required this.version,
    required this.supplies,
    required this.claimedHexIds,
    required this.playerPosition,
    required this.lastSeenEpochMs,
    this.camp,
    this.base,
  });

  /// Versión del formato del save. Subir al cambiar el shape (y migrar/resetear).
  static const int currentVersion = 1;

  final int version;
  final double supplies;
  final List<int> claimedHexIds;
  final LatLng playerPosition;

  /// Epoch (ms) de la última vez que se guardó (= "última vez visto"). Base del
  /// catch-up offline acotado (doc 22).
  final int lastSeenEpochMs;

  final Outpost? camp;
  final Outpost? base;

  Map<String, dynamic> toJson() => {
        'version': version,
        'supplies': supplies,
        'claimedHexIds': claimedHexIds,
        'playerPosition': _latLngToJson(playerPosition),
        'lastSeen': lastSeenEpochMs,
        'camp': camp == null ? null : _outpostToJson(camp!),
        'base': base == null ? null : _outpostToJson(base!),
      };

  /// Parsea un save desde JSON. **Tolerante:** ante cualquier error o versión
  /// incompatible devuelve `null` (la app arranca de cero, no crashea).
  static PlayerSave? fromJson(Map<String, dynamic> j) {
    try {
      final v = j['version'];
      if (v is! int || v != currentVersion) return null; // futuro: migrar
      return PlayerSave(
        version: v,
        supplies: (j['supplies'] as num).toDouble(),
        claimedHexIds: (j['claimedHexIds'] as List)
            .map((e) => (e as num).toInt())
            .toList(),
        playerPosition: _latLngFromJson(j['playerPosition'] as Map),
        lastSeenEpochMs: (j['lastSeen'] as num).toInt(),
        camp: _outpostFromJson(j['camp']),
        base: _outpostFromJson(j['base']),
      );
    } catch (_) {
      return null;
    }
  }
}

Map<String, dynamic> _latLngToJson(LatLng p) =>
    {'lat': p.latitude, 'lng': p.longitude};

LatLng _latLngFromJson(Map j) =>
    LatLng((j['lat'] as num).toDouble(), (j['lng'] as num).toDouble());

Map<String, dynamic> _outpostToJson(Outpost o) => {
      'kind': o.kind.name,
      'lat': o.position.latitude,
      'lng': o.position.longitude,
      'hexId': o.hexId,
    };

Outpost? _outpostFromJson(Object? raw) {
  if (raw is! Map) return null;
  return Outpost(
    kind: OutpostKind.values.byName(raw['kind'] as String),
    position:
        LatLng((raw['lat'] as num).toDouble(), (raw['lng'] as num).toDouble()),
    hexId: (raw['hexId'] as num?)?.toInt(),
  );
}
