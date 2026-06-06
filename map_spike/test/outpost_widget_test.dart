import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:map_spike/domain/models/outpost.dart';
import 'package:map_spike/ui/features/map/views/widgets/outpost_widgets.dart';

/// Reproduce la caja fija que flutter_map le da al marker (72×72) y verifica que
/// [OutpostMarker] **no desborde** (un overflow tira excepción y falla el test).
/// Regresión del bug visto en emulador 2026-06-05 (RenderFlex overflowed 10px).
void main() {
  Future<void> pumpInMarkerBox(WidgetTester tester, OutpostKind kind) {
    return tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 72,
              height: 72,
              child: OutpostMarker(kind: kind),
            ),
          ),
        ),
      ),
    );
  }

  testWidgets('OutpostMarker campamento entra en 72×72 sin overflow',
      (tester) async {
    await pumpInMarkerBox(tester, OutpostKind.camp);
    expect(tester.takeException(), isNull);
    expect(find.text('⛺'), findsOneWidget);
    expect(find.text('Campamento'), findsOneWidget);
  });

  testWidgets('OutpostMarker base entra en 72×72 sin overflow', (tester) async {
    await pumpInMarkerBox(tester, OutpostKind.base);
    expect(tester.takeException(), isNull);
    expect(find.text('🛡️'), findsOneWidget);
    expect(find.text('Base'), findsOneWidget);
  });
}
