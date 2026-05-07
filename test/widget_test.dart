import 'package:audio_traductor/app.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('App se renderiza correctamente', (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: AudioTraductorApp(),
      ),
    );

    // Verificar que los elementos principales existen
    expect(find.text('Audio Traductor'), findsOneWidget);
    expect(find.text('Traductor'), findsOneWidget);
    expect(find.text('Historial'), findsOneWidget);
    expect(find.text('Ajustes'), findsOneWidget);
  });
}
