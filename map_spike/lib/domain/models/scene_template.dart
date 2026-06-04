/// Modelo de **template de escena de combate** (ADR 0007 Rev 2/3, doc 18).
///
/// La escena NO se arma desde geometría real, sino con **templates hechos a
/// mano** que se eligen por `(zona × topología)` y se orientan con datos OSM.
/// Cada template es una lista de **slots** en *street-space normalizado* — así
/// el mismo template sirve para cualquier inclinación/escala del render iso sin
/// reescribir coordenadas.
///
/// Lógica pura y determinista (sin `dart:ui`, sin `Random` global): testeable.
library;

/// Tipo de slot. Define color/forma del placeholder y, más adelante, qué familia
/// de sprites pre-renderizados se coloca ahí.
enum SlotKind {
  street, // calzada principal (queda vertical)
  crossing, // calle transversal / cruce
  sidewalk, // vereda
  buildingRow, // edificio/casa genérico
  cornerLandmark, // POI real destacado (va en la esquina)
  prop, // auto, contenedor, farol
  spawnPlayer, // dónde aparece el jugador (billboard)
  spawnEnemy, // dónde aparecen los zombies (billboard)
}

extension SlotKindInfo on SlotKind {
  String get label => switch (this) {
        SlotKind.street => 'calle',
        SlotKind.crossing => 'cruce',
        SlotKind.sidewalk => 'vereda',
        SlotKind.buildingRow => 'edificio',
        SlotKind.cornerLandmark => 'POI',
        SlotKind.prop => 'prop',
        SlotKind.spawnPlayer => 'jugador',
        SlotKind.spawnEnemy => 'enemigo',
      };

  /// Slots planos (sin altura) que se dibujan sobre el piso.
  bool get isFlat => switch (this) {
        SlotKind.street ||
        SlotKind.crossing ||
        SlotKind.sidewalk ||
        SlotKind.spawnPlayer ||
        SlotKind.spawnEnemy =>
          true,
        SlotKind.buildingRow || SlotKind.cornerLandmark || SlotKind.prop =>
          false,
      };
}

/// Zona del template (espejo de `ZoneCharacter`, para seleccionar template).
enum TemplateZone { residential, denseUrban, roadCorridor }

/// Topología detectada por conteo de cruces (doc 18).
enum Topology { midBlock, corner, intersection, deadEnd }

/// Un slot en **street-space normalizado**:
/// - [u]: a lo ancho de la calle, −1 (izquierda) … +1 (derecha); 0 = eje.
/// - [v]: a lo largo de la calle, 0 (cerca/abajo) … 1 (lejos/arriba).
/// - [w]: ancho del slot (en `u`), [l]: largo del slot (en `v`), en fracción.
/// - [levels]: pisos → altura de extrusión (0 = plano).
/// - [label]: texto del placeholder (en assets reales, será el sprite/POI).
class TemplateSlot {
  const TemplateSlot({
    required this.kind,
    required this.u,
    required this.v,
    this.w = 0.2,
    this.l = 0.12,
    this.levels = 0,
    this.label,
  });

  final SlotKind kind;
  final double u;
  final double v;
  final double w;
  final double l;
  final double levels;
  final String? label;
}

/// Un template completo: identidad + para qué `(zona, topología)` aplica + slots.
class SceneTemplate {
  const SceneTemplate({
    required this.id,
    required this.zone,
    required this.topology,
    required this.slots,
  });

  final String id;
  final TemplateZone zone;
  final Topology topology;
  final List<TemplateSlot> slots;

  int countOf(SlotKind kind) => slots.where((s) => s.kind == kind).length;

  /// La calzada principal (primer slot `street`), o null si no hay.
  TemplateSlot? get streetSlot {
    for (final s in slots) {
      if (s.kind == SlotKind.street) return s;
    }
    return null;
  }

  /// Rango de `v` por el que el jugador puede caminar: el **largo real de la
  /// calle** (`v ± l/2`) con un pequeño margen para no meterse en los cruces. Así
  /// una calle más larga = una cuadra más grande, sin tocar el motor (combat_game
  /// deriva sus límites de acá). Fallback al rango histórico si no hay calle.
  ({double minV, double maxV}) get playBoundsV {
    final s = streetSlot;
    if (s == null) return (minV: -0.35, maxV: 1.35);
    return (minV: s.v - s.l / 2 + 0.1, maxV: s.v + s.l / 2 - 0.1);
  }
}

/// Biblioteca inicial de templates (placeholder). Pocos y bien tuneados; los
/// edificios se generan con variedad **determinista** (no `Random`) para que la
/// misma escena se vea siempre igual.
abstract final class SceneTemplates {
  /// Todos los templates disponibles (para el selector del preview). El primero es
  /// el **default de combate** (lo carga la preview → play).
  static final List<SceneTemplate> all = [
    residentialBlock(),
    residentialMidBlock(),
    residentialCorner(),
    denseUrbanIntersection(),
  ];

  /// `residential · block`: **cuadra entera** (calle más larga, `l 2.2`) con una
  /// **esquina al fondo** (cruce transversal + landmark) hacia la que el jugador
  /// avanza. Es el escenario de combate por defecto.
  static SceneTemplate residentialBlock() => SceneTemplate(
        id: 'residential.block',
        zone: TemplateZone.residential,
        topology: Topology.corner,
        slots: [
          // Corredor largo (cuadra): calzada + veredas, l 2.2 (vs 1.9 del midBlock).
          const TemplateSlot(kind: SlotKind.street, u: 0, v: 0.5, w: 0.40, l: 2.2),
          const TemplateSlot(kind: SlotKind.sidewalk, u: -0.24, v: 0.5, w: 0.08, l: 2.2),
          const TemplateSlot(kind: SlotKind.sidewalk, u: 0.24, v: 0.5, w: 0.08, l: 2.2),
          // Esquina al fondo: transversal cruzando de lado a lado.
          const TemplateSlot(kind: SlotKind.crossing, u: 0, v: 1.3, w: 2.0, l: 0.2),
          // Edificios lineando ambos lados a lo largo de la cuadra; el lado derecho
          // se corta antes de la esquina para dejarla despejada.
          ..._buildingRow(side: -1, count: 10, baseLevels: 2, seed: 13, vStart: -0.25, vEnd: 1.15),
          ..._buildingRow(side: 1, count: 8, baseLevels: 2, seed: 31, vStart: -0.25, vEnd: 0.95),
          // Landmark (POI con nombre) en la esquina del fondo.
          const TemplateSlot(
              kind: SlotKind.cornerLandmark,
              u: 0.46,
              v: 1.15,
              w: 0.26,
              l: 0.18,
              levels: 3,
              label: 'Coto'),
          // Autos sobre la calzada (en Bloque B-2 pasan a colliders).
          const TemplateSlot(
              kind: SlotKind.prop, u: -0.10, v: 0.18, w: 0.06, l: 0.12, levels: 0.6, label: 'auto'),
          const TemplateSlot(
              kind: SlotKind.prop, u: 0.10, v: 0.72, w: 0.06, l: 0.12, levels: 0.6, label: 'auto'),
          // Spawns: jugador al inicio de la cuadra, enemigos desde la esquina.
          const TemplateSlot(kind: SlotKind.spawnPlayer, u: 0, v: -0.2, w: 0.16, l: 0.08),
          const TemplateSlot(kind: SlotKind.spawnEnemy, u: 0, v: 1.2, w: 0.24, l: 0.08),
        ],
      );

  /// `residential · midBlock`: casas bajas a ambos lados, calle 2 sentidos.
  static SceneTemplate residentialMidBlock() => SceneTemplate(
        id: 'residential.midBlock',
        zone: TemplateZone.residential,
        topology: Topology.midBlock,
        slots: [
          ..._corridorBase(),
          ..._buildingRow(side: -1, count: 8, baseLevels: 2, seed: 11),
          ..._buildingRow(side: 1, count: 8, baseLevels: 2, seed: 29),
          // Autos SOBRE la calzada (en los carriles, |u|<0.20), largos a lo largo.
          const TemplateSlot(
              kind: SlotKind.prop, u: -0.10, v: 0.32, w: 0.06, l: 0.12, levels: 0.6, label: 'auto'),
          const TemplateSlot(
              kind: SlotKind.prop, u: 0.10, v: 0.74, w: 0.06, l: 0.12, levels: 0.6, label: 'auto'),
          const TemplateSlot(kind: SlotKind.spawnPlayer, u: 0, v: 0.1, w: 0.16, l: 0.08),
          const TemplateSlot(kind: SlotKind.spawnEnemy, u: 0, v: 0.92, w: 0.22, l: 0.08),
        ],
      );

  /// `residential · corner`: calle + transversal entrando por la derecha y un
  /// **landmark** (POI real) en la esquina.
  static SceneTemplate residentialCorner() => SceneTemplate(
        id: 'residential.corner',
        zone: TemplateZone.residential,
        topology: Topology.corner,
        slots: [
          ..._corridorBase(),
          // Transversal entrando desde la derecha a media escena.
          const TemplateSlot(
              kind: SlotKind.crossing, u: 0.6, v: 0.6, w: 0.9, l: 0.16),
          // Landmark en la esquina (POI real con nombre).
          const TemplateSlot(
              kind: SlotKind.cornerLandmark,
              u: 0.46,
              v: 0.74,
              w: 0.26,
              l: 0.16,
              levels: 3,
              label: 'Coto'),
          ..._buildingRow(side: -1, count: 5, baseLevels: 2, seed: 7),
          // Lado derecho: solo edificios antes del cruce (deja la esquina libre).
          ..._buildingRow(side: 1, count: 2, baseLevels: 2, seed: 41, vStart: 0.06, vEnd: 0.42),
          const TemplateSlot(kind: SlotKind.spawnPlayer, u: 0, v: 0.1, w: 0.16, l: 0.08),
          const TemplateSlot(kind: SlotKind.spawnEnemy, u: 0.2, v: 0.9, w: 0.22, l: 0.08),
        ],
      );

  /// `denseUrban · intersection`: edificios altos, cruz (4 esquinas).
  static SceneTemplate denseUrbanIntersection() => SceneTemplate(
        id: 'denseUrban.intersection',
        zone: TemplateZone.denseUrban,
        topology: Topology.intersection,
        slots: [
          ..._corridorBase(),
          // Transversal cruzando de lado a lado.
          const TemplateSlot(
              kind: SlotKind.crossing, u: 0, v: 0.5, w: 2.0, l: 0.18),
          // 4 torres en las esquinas.
          const TemplateSlot(
              kind: SlotKind.buildingRow, u: -0.55, v: 0.28, w: 0.34, l: 0.2, levels: 8),
          const TemplateSlot(
              kind: SlotKind.buildingRow, u: 0.55, v: 0.28, w: 0.34, l: 0.2, levels: 9),
          const TemplateSlot(
              kind: SlotKind.cornerLandmark, u: -0.55, v: 0.72, w: 0.34, l: 0.2, levels: 7, label: 'Farmacity'),
          const TemplateSlot(
              kind: SlotKind.buildingRow, u: 0.55, v: 0.72, w: 0.34, l: 0.2, levels: 10),
          const TemplateSlot(kind: SlotKind.spawnPlayer, u: 0, v: 0.1, w: 0.16, l: 0.08),
          const TemplateSlot(kind: SlotKind.spawnEnemy, u: 0, v: 0.9, w: 0.24, l: 0.08),
        ],
      );

  /// Calzada vertical (ancha, de autos) + veredas angostas pegadas a los lados.
  /// Calle: |u|<0.20 · vereda: 0.20–0.28 · edificios arrancan en ~0.29.
  static List<TemplateSlot> _corridorBase() => const [
        TemplateSlot(kind: SlotKind.street, u: 0, v: 0.5, w: 0.40, l: 1.9),
        TemplateSlot(kind: SlotKind.sidewalk, u: -0.24, v: 0.5, w: 0.08, l: 1.9),
        TemplateSlot(kind: SlotKind.sidewalk, u: 0.24, v: 0.5, w: 0.08, l: 1.9),
      ];

  /// Fila de edificios a un [side] (−1 izq, +1 der) repartidos a lo largo de la
  /// calle entre [vStart] y [vEnd], con altura variada **determinista** por
  /// índice (`seed`). Deja huecos ocasionales (baldíos).
  static List<TemplateSlot> _buildingRow({
    required int side,
    required int count,
    required double baseLevels,
    required int seed,
    double vStart = -0.05,
    double vEnd = 1.05,
  }) {
    final out = <TemplateSlot>[];
    final u = side * 0.42; // pegados al borde de la vereda (que termina en ~0.28)
    for (var i = 0; i < count; i++) {
      // Pseudo-aleatorio determinista (hash del índice + seed): variedad estable.
      final h = ((i * 2654435761) ^ (seed * 40503)) & 0x7fffffff;
      final r1 = (h % 1000) / 1000.0;
      final r2 = ((h ~/ 1000) % 1000) / 1000.0;
      if (r1 < 0.12) continue; // baldío ocasional
      final v = vStart + (vEnd - vStart) * (count == 1 ? 0.5 : i / (count - 1));
      final levels = (baseLevels * (0.7 + r2 * 0.9)).clamp(1.0, 60.0);
      out.add(TemplateSlot(
        kind: SlotKind.buildingRow,
        u: u, // fila alineada (sin jitter): misma distancia a la calle
        v: v,
        w: 0.26,
        l: (vEnd - vStart) / count * 0.8,
        levels: levels,
      ));
    }
    return out;
  }
}
