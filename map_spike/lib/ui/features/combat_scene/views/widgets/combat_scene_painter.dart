import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../../domain/models/combat_scene_layout.dart';

/// Render **top-down con profundidad falsa** de la escena de combate (ADR 0007,
/// revisión 2026-05-31): la calle principal queda **vertical**, los edificios se
/// extruyen un poco (paredes + sombra) para dar sensación 2.5D sin isométrico.
///
/// Previsualización estática del [CombatSceneLayout]; cuando se agreguen
/// personajes en movimiento, el render migra a Flame (mismo layout de entrada).
class CombatScenePainter extends CustomPainter {
  CombatScenePainter({required this.layout});

  final CombatSceneLayout layout;

  static const double _pxPerLevel = 5.0; // altura en pantalla por piso
  static const Offset _shadowPerLevel = Offset(1.2, 1.6); // dirección de luz

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = const Color(0xFF20242B));

    final r = layout.radiusMeters;
    final scale = size.height * 0.85 / (2 * r); // calle vertical ~85% del alto
    final cx = size.width / 2, cy = size.height / 2;

    // metros locales (origen=centro, +y arriba) → pantalla (y invertida).
    Offset toScreen(ScenePoint p) => Offset(cx + p.x * scale, cy - p.y * scale);

    _drawStreets(canvas, scale, toScreen);
    _drawBuildings(canvas, toScreen);
    _drawCompass(canvas, size);
  }

  void _drawStreets(Canvas canvas, double scale, Offset Function(ScenePoint) ts) {
    final streets = [...layout.streets]
      ..sort((a, b) => (a.isMain ? 1 : 0).compareTo(b.isMain ? 1 : 0));
    for (final s in streets) {
      if (s.points.length < 2) continue;
      final path = Path()..moveTo(ts(s.points.first).dx, ts(s.points.first).dy);
      for (final p in s.points.skip(1)) {
        final o = ts(p);
        path.lineTo(o.dx, o.dy);
      }
      final wPx = math.max(s.width * scale, 2.0);
      canvas.drawPath(
        path,
        Paint()
          ..color = s.isMain ? const Color(0xFF3A3F47) : const Color(0xFF33373E)
          ..style = PaintingStyle.stroke
          ..strokeWidth = wPx
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round,
      );
      if (s.isMain && s.width >= 6) {
        canvas.drawPath(
          path,
          Paint()
            ..color = Colors.amber.withValues(alpha: 0.5)
            ..style = PaintingStyle.stroke
            ..strokeWidth = math.max(wPx * 0.04, 1)
            ..strokeCap = StrokeCap.round,
        );
      }
    }
  }

  void _drawBuildings(Canvas canvas, Offset Function(ScenePoint) ts) {
    // De atrás (menor y de pantalla) hacia adelante, para superponer bien.
    final items = [
      for (final b in layout.buildings)
        (b: b, scr: [for (final p in b.footprint) ts(p)]),
    ]..sort((a, b) {
        final ay = a.scr.map((o) => o.dy).reduce(math.max);
        final by = b.scr.map((o) => o.dy).reduce(math.max);
        return ay.compareTo(by);
      });

    for (final it in items) {
      final base = it.scr;
      if (base.length < 3) continue;
      final h = it.b.levels * _pxPerLevel;
      final roof = [for (final o in base) o.translate(-h * 0.3, -h)];

      // 1) Sombra (footprint desplazado según altura).
      final shadowOff = _shadowPerLevel * it.b.levels;
      canvas.drawPath(
        Path()..addPolygon([for (final o in base) o + shadowOff], true),
        Paint()..color = Colors.black.withValues(alpha: 0.25),
      );

      // 2) Paredes: une cada arista de base con la de techo.
      final wallPaint = Paint()
        ..color = it.b.inferred
            ? const Color(0xFF5A4632)
            : const Color(0xFF6B5440);
      for (var i = 0; i < base.length; i++) {
        final j = (i + 1) % base.length;
        canvas.drawPath(
          Path()..addPolygon([base[i], base[j], roof[j], roof[i]], true),
          wallPaint,
        );
      }

      // 3) Techo.
      canvas.drawPath(
        Path()..addPolygon(roof, true),
        Paint()
          ..color = it.b.inferred
              ? const Color(0xFF8A6F4E)
              : const Color(0xFFA5895F),
      );
      canvas.drawPath(
        Path()..addPolygon(roof, true),
        Paint()
          ..color = Colors.black.withValues(alpha: 0.25)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1,
      );
    }
  }

  /// Brújula: muestra hacia dónde quedó el **norte real** tras rotar la escena.
  void _drawCompass(Canvas canvas, Size size) {
    final center = Offset(size.width - 34, 34);
    canvas.drawCircle(
        center, 20, Paint()..color = Colors.black.withValues(alpha: 0.5));
    // El norte local (0,1) rotado por `rot` queda en (-sin, cos); en pantalla la
    // Y se invierte → dir = (-sin, -cos).
    final a = layout.realNorthAngleRad;
    final dir = Offset(-math.sin(a), -math.cos(a));
    final tip = center + dir * 15;
    canvas.drawLine(
      center - dir * 12,
      tip,
      Paint()
        ..color = Colors.redAccent
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round,
    );
    final tp = TextPainter(
      text: const TextSpan(
          text: 'N',
          style: TextStyle(
              color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, tip - Offset(tp.width / 2, tp.height / 2) + dir * 6);
  }

  @override
  bool shouldRepaint(covariant CombatScenePainter old) => old.layout != layout;
}
