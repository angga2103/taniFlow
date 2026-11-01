import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:taniflow/core/constants/app_strings.dart';
import 'package:taniflow/main.dart';

void main() {
  testWidgets('TaniFlow app smoke test and title verification', (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: TaniFlowApp(),
      ),
    );
    await tester.pumpAndSettle();

    // Verify presence of app name or tagline
    expect(find.text(AppStrings.appName), findsWidgets);
  });
}
