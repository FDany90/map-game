// Smoke test mínimo del spike.
import 'package:flutter_test/flutter_test.dart';

import 'package:map_spike/main.dart';

void main() {
  testWidgets('La app del spike se construye', (WidgetTester tester) async {
    await tester.pumpWidget(const MapSpikeApp());
    // El título del AppBar arranca con 0 objetos.
    expect(find.textContaining('0 objetos'), findsOneWidget);
  });
}
