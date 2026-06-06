import 'package:latlong2/latlong.dart';

/// Tipo de asentamiento del jugador en el mapa.
///
/// - [camp] **Campamento temporal:** barato, colocable casi en cualquier lado,
///   movible. Es el primer refugio (se hace con poco farmeo).
/// - [base] **Base permanente:** cara, anclada a un hexágono (doc 15), solo se
///   funda **estando físicamente ahí** (regla de presencia/GPS) y con
///   confirmación fuerte; mover una base después es muy costoso.
enum OutpostKind { camp, base }

extension OutpostKindInfo on OutpostKind {
  String get label => switch (this) {
        OutpostKind.camp => 'Campamento',
        OutpostKind.base => 'Base',
      };

  /// Glyph del icono en el mapa (placeholder hasta tener sprites).
  String get emoji => switch (this) {
        OutpostKind.camp => '⛺',
        OutpostKind.base => '🛡️',
      };
}

/// Un asentamiento del jugador (campamento o base) ubicado en el mapa.
///
/// Modelo de dominio puro. La [base] se ancla además a un hexágono ([hexId],
/// doc 15: 1 base por celda); el [camp] no se ancla (es un punto movible).
class Outpost {
  const Outpost({
    required this.kind,
    required this.position,
    this.hexId,
  });

  final OutpostKind kind;
  final LatLng position;

  /// Hexágono al que se ancla la base (null para el campamento).
  final int? hexId;
}
