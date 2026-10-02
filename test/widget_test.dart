import 'package:favour/main.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('Favour app shows its search home after loading local data',
      (tester) async {
    SharedPreferences.setMockInitialValues({});

    await tester.pumpWidget(const FavourApp());
    await tester.pumpAndSettle();

    expect(find.text('Favour'), findsOneWidget);
    expect(find.text('Your personal grocery price assistant'), findsOneWidget);
  });
}
