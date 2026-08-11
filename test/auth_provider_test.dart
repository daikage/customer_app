import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:customer_app/providers/auth_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('AuthNotifier initializes correctly with no stored user', () async {
    SharedPreferences.setMockInitialValues({});
    
    final container = ProviderContainer();
    final notifier = container.read(authProvider.notifier);
    
    await notifier.restore();
    
    final state = container.read(authProvider);
    expect(state.isLoggedIn, isFalse);
    expect(state.user, isNull);
    expect(state.restoring, isFalse);
  });

  test('AuthNotifier initializes correctly with stored user', () async {
    SharedPreferences.setMockInitialValues({
      'auth_user': '{"id": 1, "name": "John Doe", "role": "customer"}'
    });
    
    final container = ProviderContainer();
    final notifier = container.read(authProvider.notifier);
    
    await notifier.restore();
    
    final state = container.read(authProvider);
    expect(state.isLoggedIn, isTrue);
    expect(state.isCustomer, isTrue);
    expect(state.user?['name'], 'John Doe');
  });
}
