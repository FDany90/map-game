import 'package:flutter/material.dart';

import '../../../../../domain/models/scene_template.dart';

/// Render **isométrico 2.5D (vista ¾, calle vertical)** de un [SceneTemplate]
/// con **cajas placeholder** (ADR 0007 Rev 3, doc 18 fase 4).
///
/// Proyección: street-space `(u,v)` + altura `z` → pantalla.
/// - `u` (a lo ancho) → horizontal. Con [skew]=0 la calle (u=0) queda
///   **perfectamente vertical**; subir [skew] inclina la escena para revelar
///   caras laterales (más "iso", a costa de una leve inclinación de la calle —
///   el trade-off documentado en el ADR 0007 Rev 3).
/// - `v` (a lo largo) → profundidad hacia arriba (lejos = arriba). [pitch]
///   controla cuánto se comprime: bajo = cámara más de costado = **más fachada**.
/// - `z` (pisos) → altura en pantalla.
///
/// Es solo preview: cuando haya sprites pre-renderizados, cada caja se reemplaza
/// por su PNG (mismo `(u,v)`); el juego sigue en Flame 2D.
class IsoTemplatePainter extends CustomPainter {
  IsoTemplatePainter({
    required this.template,
    this.skew = 0.35, // ángulo ¾ elegido (2026-06-01) — ver preview screen
    this.pitch = 0.49,
    this.zoom = 4.10,
    this.panX = 0.01,
    this.cameraV,
    this.player,
    this.enemies,
    this.shots,
  });

  final SceneTemplate template;

  /// Si es no-null, la escena se proyecta **relativa a la cámara** (modo juego):
  /// el punto `v = cameraV` queda anclado a ~⅔ de la pantalla y la calle scrollea.
  /// Si es null, modo preview estático (la calle entra completa).
  final double? cameraV;

  /// Posición del jugador en street-space `(u,v)`; se dibuja como billboard.
  final ({double u, double v})? player;

  /// Zombies a dibujar (billboards verdes), en street-space.
  final List<({double u, double v})>? enemies;

  /// Disparos activos (línea jugador→objetivo), en street-space.
  final List<({double u, double v, double tu, double tv})>? shots;

  /// Desplazamiento horizontal de cámara, en fracción del ancho (−izq … +der).
  final double panX;

  /// Inclinación lateral (iso-ness): 0 = calle vertical exacta; ~0.2 = bien iso.
  final double skew;

  /// Compresión de la profundidad (cámara): 0.4 = muy de costado (fachadas
  /// grandes), 0.8 = más cenital.
  final double pitch;

  /// Acercamiento de cámara: 1 = vista completa; ~2 = la calle ocupa casi todo
  /// el ancho y los edificios quedan como borde a los costados (ADR 0007 Rev 1).
  final double zoom;

  static const double _levelPx = 6.5; // altura en pantalla por piso (× zoom)

  @override
  void paint(Canvas canvas, Size size) {
    // Recortar a los límites del canvas: con la calle larga + zoom alto, la
    // proyección genera y negativos que si no, se dibujan por encima del
    // dropdown de arriba.
    canvas.clipRect(Offset.zero & size);

    // Fondo con un degradé sutil (cielo/calle al fondo).
    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF1A1E25), Color(0xFF262B33)],
        ).createShader(Offset.zero & size),
    );

    final z = zoom.clamp(1.0, 6.0);
    final cx = size.width / 2 + panX * size.width;
    final halfX = size.width * 0.42 * z;
    // Profundidad: escala suave con el zoom para que jugador y enemigo sigan en
    // cuadro aunque la calle se ensanche.
    final depthPx =
        size.height * 0.60 * pitch.clamp(0.2, 1.5) / 0.62 * (1 + (z - 1) * 0.25);
    final levelPx = _levelPx * z;
    final skewPx = skew * size.width * 0.9;

    // Modo cámara (juego): el ancla está a ~⅔ y se proyecta relativo a cameraV.
    // Modo preview (estático): ancla abajo (0.86) y v absoluto.
    final vRef = cameraV ?? 0.0;
    final baseY = size.height * (cameraV != null ? 0.66 : 0.86);

    Offset project(double u, double v, double zz) {
      final dv = v - vRef;
      return Offset(
        cx + u * halfX + dv * skewPx,
        baseY - dv * depthPx - zz * levelPx,
      );
    }

    // 1) Superficies planas (piso): vereda → calle → cruce.
    for (final kind in [SlotKind.sidewalk, SlotKind.street, SlotKind.crossing]) {
      for (final s in template.slots.where((s) => s.kind == kind)) {
        _drawFlat(canvas, s, project);
      }
    }
    _drawStreetCenterLine(canvas, project);

    // 2) Marcadores de spawn (sobre el piso, bajo los edificios).
    for (final s in template.slots
        .where((s) => s.kind == SlotKind.spawnPlayer || s.kind == SlotKind.spawnEnemy)) {
      _drawSpawn(canvas, s, project);
    }

    // 3) Cajas con altura, de lejos (v alto) hacia cerca (v bajo): painter's algo.
    final boxes = template.slots.where((s) => !s.kind.isFlat).toList()
      ..sort((a, b) => b.v.compareTo(a.v));
    for (final s in boxes) {
      _drawBox(canvas, s, project);
    }

    // 4) Zombies (billboards verdes), de lejos hacia cerca.
    if (enemies != null) {
      final sorted = [...enemies!]..sort((a, b) => b.v.compareTo(a.v));
      for (final e in sorted) {
        _drawEnemy(canvas, project(e.u, e.v, 0), levelPx);
      }
    }

    // 5) Jugador (billboard placeholder).
    if (player != null) {
      _drawPlayer(canvas, project(player!.u, player!.v, 0), levelPx);
    }

    // 6) Disparos (línea jugador→objetivo), al frente.
    if (shots != null) {
      final shotPaint = Paint()
        ..color = Colors.yellowAccent
        ..strokeWidth = 2.5
        ..strokeCap = StrokeCap.round;
      for (final s in shots!) {
        canvas.drawLine(
            project(s.u, s.v, 1.4), project(s.tu, s.tv, 0.9), shotPaint);
      }
    }
  }

  /// Billboard placeholder de un zombie (verde, algo más bajo que el jugador).
  void _drawEnemy(Canvas canvas, Offset ground, double levelPx) {
    final h = 2.8 * levelPx;
    canvas.drawOval(
      Rect.fromCenter(center: ground, width: h * 0.55, height: h * 0.2),
      Paint()..color = Colors.black.withValues(alpha: 0.3),
    );
    final body = RRect.fromRectAndRadius(
      Rect.fromLTRB(ground.dx - h * 0.15, ground.dy - h, ground.dx + h * 0.15, ground.dy),
      Radius.circular(h * 0.15),
    );
    canvas.drawRRect(body, Paint()..color = const Color(0xFF5FA845));
    canvas.drawCircle(
      Offset(ground.dx, ground.dy - h - h * 0.1),
      h * 0.17,
      Paint()..color = const Color(0xFF8FD46E),
    );
  }

  /// Billboard placeholder del jugador: sombra elíptica + cuerpo cápsula + cabeza
  /// (ADR 0007: sprite de frente anclado al piso). [levelPx] da la escala.
  void _drawPlayer(Canvas canvas, Offset ground, double levelPx) {
    final h = 3.2 * levelPx;
    canvas.drawOval(
      Rect.fromCenter(center: ground, width: h * 0.55, height: h * 0.2),
      Paint()..color = Colors.black.withValues(alpha: 0.32),
    );
    final body = RRect.fromRectAndRadius(
      Rect.fromLTRB(ground.dx - h * 0.16, ground.dy - h, ground.dx + h * 0.16, ground.dy),
      Radius.circular(h * 0.16),
    );
    canvas.drawRRect(body, Paint()..color = const Color(0xFF18C0D6));
    canvas.drawCircle(
      Offset(ground.dx, ground.dy - h - h * 0.12),
      h * 0.18,
      Paint()..color = const Color(0xFF8DEBF6),
    );
  }

  // --- superficies planas ---

  List<Offset> _flatCorners(TemplateSlot s, Offset Function(double, double, double) p) {
    final hu = s.w / 2, hv = s.l / 2;
    return [
      p(s.u - hu, s.v - hv, 0),
      p(s.u + hu, s.v - hv, 0),
      p(s.u + hu, s.v + hv, 0),
      p(s.u - hu, s.v + hv, 0),
    ];
  }

  void _drawFlat(Canvas canvas, TemplateSlot s, Offset Function(double, double, double) p) {
    final color = switch (s.kind) {
      SlotKind.street => const Color(0xFF3A3F47),
      SlotKind.crossing => const Color(0xFF343941),
      SlotKind.sidewalk => const Color(0xFF4A4F58),
      _ => const Color(0xFF2E333B),
    };
    canvas.drawPath(
      Path()..addPolygon(_flatCorners(s, p), true),
      Paint()..color = color,
    );
  }

  void _drawStreetCenterLine(Canvas canvas, Offset Function(double, double, double) p) {
    // Línea de carril punteada por el eje (vende los "2 sentidos"), a lo largo
    // de toda la calle (que ahora es larga: v ≈ −0.4 … 1.4).
    const dashes = 24, vMin = -0.4, vMax = 1.4;
    for (var i = 0; i < dashes; i++) {
      if (i.isOdd) continue;
      final v0 = vMin + (vMax - vMin) * (i / dashes);
      final v1 = vMin + (vMax - vMin) * ((i + 0.6) / dashes);
      canvas.drawLine(
        p(0, v0, 0),
        p(0, v1, 0),
        Paint()
          ..color = Colors.amber.withValues(alpha: 0.55)
          ..strokeWidth = 2
          ..strokeCap = StrokeCap.round,
      );
    }
  }

  void _drawSpawn(Canvas canvas, TemplateSlot s, Offset Function(double, double, double) p) {
    final c = p(s.u, s.v, 0);
    final isPlayer = s.kind == SlotKind.spawnPlayer;
    final color = isPlayer ? Colors.cyanAccent : Colors.redAccent;
    canvas.drawCircle(c, 9, Paint()..color = color.withValues(alpha: 0.25));
    canvas.drawCircle(
      c,
      9,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
    _label(canvas, c.translate(0, -18), s.kind.label, color);
  }

  // --- cajas extruidas (placeholders de edificios / props / landmarks) ---

  void _drawBox(Canvas canvas, TemplateSlot s, Offset Function(double, double, double) p) {
    final hu = s.w / 2, hv = s.l / 2;
    final z = s.levels;
    // 0 = frente-izq, 1 = frente-der, 2 = fondo-der, 3 = fondo-izq.
    final base = [
      p(s.u - hu, s.v - hv, 0),
      p(s.u + hu, s.v - hv, 0),
      p(s.u + hu, s.v + hv, 0),
      p(s.u - hu, s.v + hv, 0),
    ];
    final top = [
      p(s.u - hu, s.v - hv, z),
      p(s.u + hu, s.v - hv, z),
      p(s.u + hu, s.v + hv, z),
      p(s.u - hu, s.v + hv, z),
    ];

    final palette = _palette(s.kind);

    // Sombra: footprint desplazado (dirección de luz fija).
    final shadowOff = Offset(z * 1.6, z * 1.1);
    canvas.drawPath(
      Path()..addPolygon([for (final o in base) o + shadowOff], true),
      Paint()..color = Colors.black.withValues(alpha: 0.22),
    );

    // Paredes traseras/laterales primero, fachada (frente) al final.
    void wall(int i, int j, Color col) {
      canvas.drawPath(
        Path()..addPolygon([base[i], base[j], top[j], top[i]], true),
        Paint()..color = col,
      );
    }

    wall(3, 0, palette.side); // lateral izquierda
    wall(1, 2, palette.side); // lateral derecha
    wall(2, 3, palette.sideDark); // fondo
    wall(0, 1, palette.facade); // fachada (frente, mira a cámara)

    // Techo.
    canvas.drawPath(Path()..addPolygon(top, true), Paint()..color = palette.roof);
    canvas.drawPath(
      Path()..addPolygon(top, true),
      Paint()
        ..color = Colors.black.withValues(alpha: 0.25)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );

    // Etiqueta sobre la fachada.
    final mid = Offset.lerp(base[0], top[1], 0.5)!;
    final text = s.label ?? '${s.levels.round()}p';
    _label(canvas, mid, text, Colors.white.withValues(alpha: 0.9));
  }

  _BoxPalette _palette(SlotKind kind) => switch (kind) {
        SlotKind.cornerLandmark => const _BoxPalette(
            facade: Color(0xFFC76B3A),
            side: Color(0xFFA9582E),
            sideDark: Color(0xFF8C4824),
            roof: Color(0xFFE08A4F),
          ),
        SlotKind.prop => const _BoxPalette(
            facade: Color(0xFF4F6A86),
            side: Color(0xFF42596F),
            sideDark: Color(0xFF374A5C),
            roof: Color(0xFF6585A3),
          ),
        _ => const _BoxPalette(
            facade: Color(0xFF7E6448),
            side: Color(0xFF6B5440),
            sideDark: Color(0xFF564433),
            roof: Color(0xFFA5895F),
          ),
      };

  void _label(Canvas canvas, Offset center, String text, Color color) {
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w600),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, center - Offset(tp.width / 2, tp.height / 2));
  }

  @override
  bool shouldRepaint(covariant IsoTemplatePainter old) =>
      old.template != template ||
      old.skew != skew ||
      old.pitch != pitch ||
      old.zoom != zoom ||
      old.panX != panX ||
      old.cameraV != cameraV ||
      old.player != player;
}

class _BoxPalette {
  const _BoxPalette({
    required this.facade,
    required this.side,
    required this.sideDark,
    required this.roof,
  });
  final Color facade;
  final Color side;
  final Color sideDark;
  final Color roof;
}
