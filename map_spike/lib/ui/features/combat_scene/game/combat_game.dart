import 'dart:math' as math;

import 'package:flame/components.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';

import '../../../../domain/models/scene_template.dart';
import '../views/widgets/iso_template_painter.dart';

/// Overlays (Flutter) que muestra [CombatPlayScreen] sobre el `GameWidget`.
const String kGameOverOverlay = 'gameOver';
const String kVictoryOverlay = 'victory';

/// Tipo de colectable que dropea un zombie al morir.
enum PickupKind { ammo, health }

/// Escena de combate **jugable en Flame** (ADR 0001/0006): el jugador se mueve por
/// la calle **estilo dungeon** con joystick, la **cámara lo sigue**, los **zombies
/// spawnean y caminan hacia él**, y el jugador **auto-dispara** al más cercano en
/// rango con un **arma con cargador** (se **recarga sola** al vaciarse). Los zombies
/// que lo alcanzan lo **muerden** (daño con cooldown) y, al morir, **dropean**
/// munición/vida que el jugador junta caminando encima (+ recursos). El escenario se
/// **gana** matando [targetKills] zombies (cupo fijo) y se **pierde** si la vida llega
/// a 0. El escenario reusa [IsoTemplatePainter].
///
/// Placeholder: zombies, jugador y colectables son billboards de color; los sprites
/// pre-renderizados vienen después (ADR 0007 Rev 3).
class CombatGame extends FlameGame {
  CombatGame({
    required this.template,
    this.zoom = 4.10,
    this.skew = 0.35,
    this.pitch = 0.49,
    this.panX = 0.01,
  });

  final SceneTemplate template;
  final double zoom;
  final double skew;
  final double pitch;
  final double panX;

  // Jugador (street-space) + cámara.
  double playerU = 0.0;
  double playerV = 0.0;
  double cameraV = 0.0;

  // Vida del jugador.
  static const int maxHp = 100;
  int hp = maxHp;

  // Estado de partida.
  bool _dead = false;
  bool _won = false;
  bool get isDead => _dead;
  bool get won => _won;

  /// Flash rojo (feedback de daño): 1 al recibir mordida, decae a 0.
  double hurtFlash = 0;

  /// FPS suavizado (dev). Apagar [showFps] para sacarlo del HUD.
  static const bool showFps = true;
  double fps = 0;

  // Arma / munición (un arma por ahora; stats listos para volverse `Weapon`).
  static const int magazineSize = 12;
  static const double reloadTime = 1.4;
  static const int _shotDamage = 1;
  int ammo = magazineSize;
  bool reloading = false;
  double reloadT = 0;
  double get reloadFrac => reloading ? (reloadT / reloadTime).clamp(0.0, 1.0) : 0;

  // Objetivo del escenario: matar [targetKills] (cupo fijo).
  static const int targetKills = 20;
  int kills = 0;
  int _spawnedTotal = 0;

  // Economía / colectables (drops de zombies).
  int resources = 0;
  static const int _resourcesPerKill = 5;
  final List<Pickup> pickups = [];
  static const double _pickupRange = 0.11;
  static const double _pickupTtl = 9.0;
  static const double _dropAmmoChance = 0.40;
  static const double _dropHealthChance = 0.15; // después de ammo
  static const int _ammoRefill = 6;
  static const int _healthRefill = 25;

  // Entidades en vuelo.
  final List<Zombie> zombies = [];
  final List<Shot> shots = [];

  /// Rects de colisión de los autos (street-space), derivados de los slots `prop`
  /// del template. El jugador y los zombies no los atraviesan (cobertura táctica).
  final List<({double umin, double umax, double vmin, double vmax})> _cars = [];
  static const double _bodyR = 0.045; // "radio" del cuerpo para colisión

  /// Tiempo de partida (segundos) — alimenta la rampa de dificultad.
  double elapsed = 0;

  final math.Random _rng = math.Random();
  double _spawnT = 0;
  double _fireT = 0;

  // Límites del jugador en la calle. _vMin/_vMax se derivan del largo de la calle
  // del template (cuadra más larga = más recorrido) en [onLoad].
  static const double _uLimit = 0.26;
  late final double _vMin;
  late final double _vMax;
  late final double _startV; // dónde arranca el jugador (inicio de la cuadra)
  static const double _uSpeed = 0.35;
  static const double _vSpeed = 0.45;

  // Spawn (rampa): de [_spawnSlow] a [_spawnFast] en [_rampSeconds] segundos.
  static const double _spawnSlow = 1.1;
  static const double _spawnFast = 0.45;
  static const double _rampSeconds = 90.0;
  static const int _maxZombies = 16;

  // Zombies + disparo.
  static const int zombieHp = 2; // tiros para matar
  static const double _zombieSpeed = 0.13;
  static const double _contactRange = 0.085; // distancia de mordida
  static const double _biteInterval = 0.7; // cooldown de mordida por zombie
  static const int _biteDamage = 9;
  static const double _fireInterval = 0.40;
  static const double _fireRange = 0.75;
  static const double _shotTtl = 0.12;

  late final JoystickComponent joystick;

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    // Límites jugables = largo de la calle del template; arranca al inicio.
    final b = template.playBoundsV;
    _vMin = b.minV;
    _vMax = b.maxV;
    _startV = (_vMin + 0.15).clamp(_vMin, _vMax);
    playerV = _startV;
    cameraV = _startV;
    // Colliders de autos (slots prop) desde el template.
    for (final s in template.slots.where((s) => s.kind == SlotKind.prop)) {
      _cars.add((
        umin: s.u - s.w / 2,
        umax: s.u + s.w / 2,
        vmin: s.v - s.l / 2,
        vmax: s.v + s.l / 2,
      ));
    }
    add(_SceneRenderer()); // escenario + entidades (detrás)
    // Joystick centrado en el eje horizontal, ~25% desde abajo (no pegado al
    // borde inferior) para alcanzarlo con el pulgar sin estirar.
    final bottomDist = (size.y * 0.25).clamp(40.0, size.y * 0.5);
    joystick = JoystickComponent(
      knob: CircleComponent(
        radius: 22,
        paint: Paint()..color = Colors.white.withValues(alpha: 0.85),
      ),
      background: CircleComponent(
        radius: 52,
        paint: Paint()..color = Colors.white.withValues(alpha: 0.22),
      ),
      position: Vector2(size.x / 2, size.y - bottomDist),
      anchor: Anchor.center,
    );
    add(joystick); // HUD encima
  }

  /// Reinicia la partida (lo llaman los botones "Reintentar" de los overlays).
  void restart() {
    hp = maxHp;
    _dead = false;
    _won = false;
    hurtFlash = 0;
    ammo = magazineSize;
    reloading = false;
    reloadT = 0;
    zombies.clear();
    shots.clear();
    pickups.clear();
    kills = 0;
    _spawnedTotal = 0;
    resources = 0;
    elapsed = 0;
    _spawnT = 0;
    _fireT = 0;
    playerU = 0;
    playerV = _startV;
    cameraV = _startV;
    overlays.remove(kGameOverOverlay);
    overlays.remove(kVictoryOverlay);
    resumeEngine();
  }

  @override
  void update(double dt) {
    super.update(dt);
    if (dt > 0) fps = fps == 0 ? 1 / dt : fps * 0.9 + (1 / dt) * 0.1;
    if (_dead || _won) return;

    elapsed += dt;
    if (hurtFlash > 0) hurtFlash = math.max(0, hurtFlash - dt * 2.5);

    // 1) Movimiento del jugador.
    final d = joystick.relativeDelta;
    if (!d.isZero()) {
      playerU = (playerU + d.x * _uSpeed * dt).clamp(-_uLimit, _uLimit);
      playerV = (playerV - d.y * _vSpeed * dt).clamp(_vMin, _vMax);
      final pr = _pushOutOfCars(playerU, playerV);
      playerU = pr.u.clamp(-_uLimit, _uLimit);
      playerV = pr.v.clamp(_vMin, _vMax);
    }
    cameraV += (playerV - cameraV) * math.min(1.0, dt * 6.0);

    // 2) Spawn de zombies (rampa) hasta cubrir el cupo del escenario.
    final ramp = (elapsed / _rampSeconds).clamp(0.0, 1.0);
    final spawnInterval = _spawnSlow + (_spawnFast - _spawnSlow) * ramp;
    _spawnT += dt;
    if (_spawnT >= spawnInterval &&
        zombies.length < _maxZombies &&
        _spawnedTotal < targetKills) {
      _spawnT = 0;
      final off = 0.7 + _rng.nextDouble() * 0.4;
      final ahead = playerV + off;
      final v = (ahead <= _vMax ? ahead : playerV - off).clamp(_vMin, _vMax);
      final u = (_rng.nextDouble() * 2 - 1) * _uLimit;
      zombies.add(Zombie(u, v));
      _spawnedTotal++;
    }

    // 3) Zombies caminan hacia el jugador; al alcanzarlo, muerden (con cooldown).
    for (final z in zombies) {
      final du = playerU - z.u, dv = playerV - z.v;
      final dist = math.sqrt(du * du + dv * dv);
      if (dist > _contactRange) {
        z.biteT = 0; // se reinicia el cooldown al perder contacto
        if (dist > 1e-4) {
          z.u += du / dist * _zombieSpeed * dt;
          z.v += dv / dist * _zombieSpeed * dt;
          final zr = _pushOutOfCars(z.u, z.v);
          z.u = zr.u;
          z.v = zr.v;
        }
      } else {
        z.biteT += dt;
        if (z.biteT >= _biteInterval) {
          z.biteT = 0;
          hp = math.max(0, hp - _biteDamage);
          hurtFlash = 1.0;
          if (hp == 0) {
            _die();
            return;
          }
        }
      }
    }

    // 4) Arma: recarga automática al vaciarse, y disparo al más cercano en rango.
    if (reloading) {
      reloadT += dt;
      if (reloadT >= reloadTime) {
        reloading = false;
        reloadT = 0;
        ammo = magazineSize;
      }
    } else {
      _fireT += dt;
      if (_fireT >= _fireInterval && ammo > 0) {
        _fireT = 0;
        Zombie? target;
        var best = _fireRange;
        for (final z in zombies) {
          final du = z.u - playerU, dv = z.v - playerV;
          final dist = math.sqrt(du * du + dv * dv);
          if (dist < best) {
            best = dist;
            target = z;
          }
        }
        if (target != null) {
          shots.add(Shot(playerU, playerV, target.u, target.v));
          target.hp -= _shotDamage;
          ammo--;
          if (ammo == 0) reloading = true; // arranca la recarga
        }
      }
    }

    // 5) Bajas: cuentan, dan recursos y dropean colectables.
    for (final z in zombies) {
      if (z.hp <= 0) {
        kills++;
        resources += _resourcesPerKill;
        _rollDrop(z.u, z.v);
      }
    }
    zombies.removeWhere((z) => z.hp <= 0);

    // 6) Colectables: se juntan al pasar por encima; expiran con el tiempo.
    for (final p in pickups) {
      final du = p.u - playerU, dv = p.v - playerV;
      if (du * du + dv * dv < _pickupRange * _pickupRange) {
        p.collected = true;
        switch (p.kind) {
          case PickupKind.ammo:
            ammo = math.min(magazineSize, ammo + _ammoRefill);
            if (ammo > 0 && reloading) {
              reloading = false;
              reloadT = 0;
            }
          case PickupKind.health:
            hp = math.min(maxHp, hp + _healthRefill);
        }
      } else {
        p.ttl -= dt;
      }
    }
    pickups.removeWhere((p) => p.collected || p.ttl <= 0);

    // 7) Expiración de disparos.
    for (final s in shots) {
      s.ttl -= dt;
    }
    shots.removeWhere((s) => s.ttl <= 0);

    // 8) ¿Escenario completado?
    if (kills >= targetKills) _win();
  }

  /// Empuja una posición `(u, v)` fuera de los autos (colisión círculo-AABB con
  /// radio [_bodyR]). Si el centro quedó dentro, sale por el eje de menor
  /// penetración. Sirve para jugador y zombies.
  ({double u, double v}) _pushOutOfCars(double u, double v) {
    const r = _bodyR;
    for (final c in _cars) {
      final cx = u.clamp(c.umin, c.umax);
      final cy = v.clamp(c.vmin, c.vmax);
      final dx = u - cx, dy = v - cy;
      final d2 = dx * dx + dy * dy;
      if (d2 >= r * r) continue;
      if (d2 > 1e-9) {
        final d = math.sqrt(d2);
        final push = r - d;
        u += dx / d * push;
        v += dy / d * push;
      } else {
        // Centro dentro del rect: empujar por el lado más cercano.
        final toL = u - c.umin, toR = c.umax - u;
        final toB = v - c.vmin, toT = c.vmax - v;
        if (math.min(toL, toR) < math.min(toB, toT)) {
          u = toL < toR ? c.umin - r : c.umax + r;
        } else {
          v = toB < toT ? c.vmin - r : c.vmax + r;
        }
      }
    }
    return (u: u, v: v);
  }

  /// Tira el drop de un zombie muerto en `(u, v)`.
  void _rollDrop(double u, double v) {
    final r = _rng.nextDouble();
    if (r < _dropAmmoChance) {
      pickups.add(Pickup(u, v, PickupKind.ammo));
    } else if (r < _dropAmmoChance + _dropHealthChance) {
      pickups.add(Pickup(u, v, PickupKind.health));
    }
  }

  void _die() {
    _dead = true;
    hurtFlash = 1.0;
    overlays.add(kGameOverOverlay);
    pauseEngine();
  }

  void _win() {
    _won = true;
    overlays.add(kVictoryOverlay);
    pauseEngine();
  }
}

/// Zombie en street-space (gameplay, no escena determinista).
class Zombie {
  Zombie(this.u, this.v);
  double u;
  double v;
  int hp = CombatGame.zombieHp;
  double biteT = 0; // cooldown de mordida
  double get hpFrac => (hp / CombatGame.zombieHp).clamp(0.0, 1.0);
}

/// Disparo efímero jugador→objetivo.
class Shot {
  Shot(this.u, this.v, this.tu, this.tv);
  final double u;
  final double v;
  final double tu;
  final double tv;
  double ttl = CombatGame._shotTtl;
}

/// Colectable dropeado por un zombie, en street-space.
class Pickup {
  Pickup(this.u, this.v, this.kind);
  final double u;
  final double v;
  final PickupKind kind;
  double ttl = CombatGame._pickupTtl;
  bool collected = false;
}

/// Dibuja el escenario + entidades en espacio de pantalla, reusando el painter.
class _SceneRenderer extends Component with HasGameReference<CombatGame> {
  static final TextPaint _hud = TextPaint(
    style: const TextStyle(
        color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
  );
  static final TextPaint _hudSmall = TextPaint(
    style: TextStyle(
        color: Colors.white.withValues(alpha: 0.85),
        fontSize: 13,
        fontWeight: FontWeight.w600),
  );

  @override
  void render(Canvas canvas) {
    final g = game;
    IsoTemplatePainter(
      template: g.template,
      zoom: g.zoom,
      skew: g.skew,
      pitch: g.pitch,
      panX: g.panX,
      cameraV: g.cameraV,
      player: (u: g.playerU, v: g.playerV),
      enemies: [for (final z in g.zombies) (u: z.u, v: z.v, hpFrac: z.hpFrac)],
      shots: [for (final s in g.shots) (u: s.u, v: s.v, tu: s.tu, tv: s.tv)],
      pickups: [
        for (final p in g.pickups) (u: p.u, v: p.v, kind: p.kind.index)
      ],
      labelSlots: false, // sin etiquetas "2p" en combate (limpieza + perf)
    ).paint(canvas, Size(g.size.x, g.size.y));

    // Flash rojo de daño (vignette plano sobre todo).
    if (g.hurtFlash > 0) {
      canvas.drawRect(
        Offset.zero & Size(g.size.x, g.size.y),
        Paint()..color = Colors.red.withValues(alpha: 0.28 * g.hurtFlash),
      );
    }

    _drawHpBar(canvas, g);
    // Objetivo + recursos, centrado bajo la barra de vida.
    _hud.render(canvas, 'Zombies ${g.kills}/${CombatGame.targetKills}',
        Vector2(g.size.x / 2 - 56, 58));
    _hudSmall.render(
        canvas, 'Recursos: ${g.resources}', Vector2(g.size.x / 2 - 44, 80));
    _drawAmmo(canvas, g);
    if (CombatGame.showFps) {
      _hudSmall.render(canvas, 'FPS ${g.fps.toStringAsFixed(0)}',
          Vector2(16, g.size.y - 40));
    }
  }

  /// Barra de vida arriba-centro.
  void _drawHpBar(Canvas canvas, CombatGame g) {
    const w = 180.0, h = 14.0;
    final x = g.size.x / 2 - w / 2, y = 36.0;
    final frac = (g.hp / CombatGame.maxHp).clamp(0.0, 1.0);
    final bg = RRect.fromRectAndRadius(
        Rect.fromLTWH(x, y, w, h), const Radius.circular(7));
    canvas.drawRRect(bg, Paint()..color = Colors.black.withValues(alpha: 0.45));
    if (frac > 0) {
      final fill = RRect.fromRectAndRadius(
          Rect.fromLTWH(x, y, w * frac, h), const Radius.circular(7));
      final color =
          Color.lerp(const Color(0xFFE5484D), const Color(0xFF46C66B), frac)!;
      canvas.drawRRect(fill, Paint()..color = color);
    }
    canvas.drawRRect(
      bg,
      Paint()
        ..color = Colors.white.withValues(alpha: 0.6)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );
  }

  /// Munición + estado de recarga, abajo a la derecha (lejos del joystick).
  void _drawAmmo(Canvas canvas, CombatGame g) {
    final x = g.size.x - 150, y = g.size.y - 64;
    if (g.reloading) {
      _hudSmall.render(canvas, 'Recargando…', Vector2(x, y - 18));
      const w = 120.0, h = 8.0;
      final bg = RRect.fromRectAndRadius(
          Rect.fromLTWH(x, y, w, h), const Radius.circular(4));
      canvas.drawRRect(
          bg, Paint()..color = Colors.black.withValues(alpha: 0.45));
      final fill = RRect.fromRectAndRadius(
          Rect.fromLTWH(x, y, w * g.reloadFrac, h), const Radius.circular(4));
      canvas.drawRRect(fill, Paint()..color = Colors.orangeAccent);
    } else {
      final low = g.ammo <= 3;
      final paint = TextPaint(
        style: TextStyle(
          color: low ? Colors.orangeAccent : Colors.white,
          fontSize: 18,
          fontWeight: FontWeight.bold,
        ),
      );
      paint.render(
          canvas, '🔫 ${g.ammo}/${CombatGame.magazineSize}', Vector2(x, y - 6));
    }
  }
}
