import 'package:flutter_test/flutter_test.dart';
import 'package:wave_app/main.dart';

void main() {
  testWidgets('Wave app launches', (WidgetTester tester) async {
    await tester.pumpWidget(const WaveApp());
    expect(find.text('wave.'), findsWidgets);
  });
}
