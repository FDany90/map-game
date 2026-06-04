import 'dart:math' as math;

import 'package:flame/components.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';

import '../../../../domain/models/scene_template.dart';
import '../views/widgets/iso_template_painter.dart';

/// Nombre del overlay (Flutter) que se muestra al morir. Lo registra
/// [CombatPlayScreen] en el `GameWidget`.
const String kGameOverOverlay = 'gameOver';

/// Escena de combate **jugable en Flame** (ADR 0001/0006): el jugador se mueve por
/// la calle **estilo dungeon** con joystick, la **cámara lo sigue**, los **zombies
/// spawnean y caminan hacia él**, y el jugador **auto-dispara** al más cercano en
/// rango. Los zombies que lo alcanzan lo **muerden** (daño con cooldown); al llegar
/// la vida a 0 hay **Game Over**. La dificultad **sube con el tiempo** (rampa de
/// spawn). El escenario reusa [IsoTemplatePainter].
///
/// Placeholder: zombies y jugador son billboards de color; los sprites
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
  bool _dead = false;
  bool get isDead => _dead;

  /// Flash rojo (feedback de daño): 1 al recibir mordida, decae a 0.
  double hurtFlash = 0;

  // Combate.
  final List<Zombie> zombies = [];
  final List<Shot> shots = [];
  int kills = 0;

  /// Tiempo de partida (segundos) — alimenta la rampa de dificultad.
  double elapsed = 0;

  final math.Random _rng = math.Random();
  double _spawnT = 0;
  double _fireT = 0;

  // Límites del jugador en la calle.
  static const double _uLimit = 0.26;
  static const double _vMin = -0.35;
  static const double _vMax = 1.35;
  static const double _uSpeed = 0.35;
  static const double _vSpeed = 0.45;

  // Spawn (rampa): de [_spawnSlow] a [_spawnFast] en [_rampSeconds] segundos.
  static const double _spawnSlow = 1.1;
  static const double _spawnFast = 0.45;
  static const double _rampSeconds = 90.0;
  static const int _maxZombies = 16;

  // Zombies + disparo.
  static const double _zombieSpeed = 0.13;
  static const int _zombieHp = 2; // 2 tiros
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
    add(_SceneRenderer()); // escenario + entidades (detrás)
    joystick = JoystickComponent(
      knob: CircleComponent(
        radius: 22,
        paint: Paint()..color = Colors.white.withValues(alpha: 0.85),
      ),
      background: CircleComponent(
        radius: 52,
        paint: Paint()..color = Colors.white.withValues(alpha: 0.22),
      ),
      margin: const EdgeInsets.only(left: 32, bottom: 40),
    );
    add(joystick); // HUD encima
  }

  /// Reinicia la partida (lo llama el botón "Reintentar" del overlay).
  void restart() {
    hp = maxHp;
    _dead = false;
    hurtFlash = 0;
    zombies.clear();
    shots.clear();
    kills = 0;
    elapsed = 0;
    _spawnT = 0;
    _fireT = 0;
    playerU = 0;
    playerV = 0;
    cameraV = 0;
    overlays.remove(kGameOverOverlay);
    resumeEngine();
  }

  @override
  void update(double dt) {
    super.update(dt);
    if (_dead) return;

    elapsed += dt;
    if (hurtFlash > 0) hurtFlash = math.max(0, hurtFlash - dt * 2.5);

    // 1) Movimiento del jugador.
    final d = joystick.relativeDelta;
    if (!d.isZero()) {
      playerU = (playerU + d.x * _uSpeed * dt).clamp(-_uLimit, _uLimit);
      playerV = (playerV - d.y * _vSpeed * dt).clamp(_vMin, _vMax);
    }
    cameraV += (playerV - cameraV) * math.min(1.0, dt * 6.0);

    // 2) Spawn de zombies (rampa: cada vez más seguido) adelante del jugador.
    final ramp = (elapsed / _rampSeconds).clamp(0.0, 1.0);
    final spawnInterval = _spawnSlow + (_spawnFast - _spawnSlow) * ramp;
    _spawnT += dt;
    if (_spawnT >= spawnInterval && zombies.length < _maxZombies) {
      _spawnT = 0;
      final off = 0.7 + _rng.nextDouble() * 0.4;
      final ahead = playerV + off;
      final v = (ahead <= _vMax ? ahead : playerV - off).clamp(_vMin, _vMax);
      final u = (_rng.nextDouble() * 2 - 1) * _uLimit;
      zombies.add(Zombie(u, v));
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

    // 4) Auto-disparo al zombie más cercano en rango.
    _fireT += dt;
    if (_fireT >= _fireInterval) {
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
        target.hp -= 1;
      }
    }

    // 5) Bajas + expiración de disparos.
    final dead = zombies.where((z) => z.hp <= 0).length;
    if (dead > 0) {
      kills += dead;
      zombies.removeWhere((z) => z.hp <= 0);
    }
    for (final s in shots) {
      s.ttl -= dt;
    }
    shots.removeWhere((s) => s.ttl <= 0);
  }

  void _die() {
    _dead = true;
    hurtFlash = 1.0;
    overlays.add(kGameOverOverlay);
    pauseEngine();
  }
}

/// Zombie en street-space (gameplay, no escena determinista).
class Zombie {
  Zombie(this.u, this.v);
  double u;
  double v;
  int hp = CombatGame._zombieHp;
  double biteT = 0; // cooldown de mordida
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

/// Dibuja el escenario + entidades en espacio de pantalla, reusando el painter.
class _SceneRenderer extends Component with HasGameReference<CombatGame> {
  static final TextPaint _hud = TextPaint(
    style: const TextStyle(
        color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
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
      enemies: [for (final z in g.zombies) (u: z.u, v: z.v)],
      shots: [for (final s in g.shots) (u: s.u, v: s.v, tu: s.tu, tv: s.tv)],
    ).paint(canvas, Size(g.size.x, g.size.y));

    // Flash rojo de daño (vignette plano sobre todo).
    if (g.hurtFlash > 0) {
      canvas.drawRect(
        Offset.zero & Size(g.size.x, g.size.y),
        Paint()..color = Colors.red.withValues(alpha: 0.28 * g.hurtFlash),
      );
    }

    _drawHpBar(canvas, g);
    _hud.render(canvas, 'Kills: ${g.kills}', Vector2(g.size.x / 2 - 36, 64));
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
      final color = Color.lerp(
          const Color(0xFFE5484D), const Color(0xFF46C66B), frac)!;
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
}
