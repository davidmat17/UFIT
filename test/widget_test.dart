import 'package:flutter_test/flutter_test.dart';
import 'package:ufit/main.dart';

void main() {
  testWidgets('La pantalla de inicio lista los requerimientos', (WidgetTester tester) async {
    await tester.pumpWidget(const UfitApp());
    await tester.pumpAndSettle();

    expect(find.text('UFIT'), findsOneWidget);
    expect(find.text('RF1'), findsOneWidget);
    expect(find.text('Cuenta y perfil'), findsOneWidget);
  });

  testWidgets('Se puede abrir la pantalla de un requerimiento', (WidgetTester tester) async {
    await tester.pumpWidget(const UfitApp());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Registro e inicio de sesion de usuarios'));
    await tester.pumpAndSettle();

    expect(find.text('Pendiente por implementar'), findsOneWidget);
  });
}
