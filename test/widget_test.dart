import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:flutter_app_demo/app.dart';
import 'package:flutter_app_demo/core/config/supabase_config.dart';

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await Supabase.initialize(
      url: SupabaseConfig.url,
      anonKey: SupabaseConfig.anonKey,
    );
  });

  testWidgets('Shows login screen when signed out', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const LoveMoneyApp());
    await tester.pumpAndSettle();

    expect(find.text('FamilyMoney'), findsOneWidget);
    expect(find.text('Đăng nhập'), findsAtLeastNWidgets(1));
  });
}
