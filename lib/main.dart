import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'providers/auth_provider.dart';
import 'screens/home_screen.dart';
import 'screens/login_screen.dart';

void main() {
  runApp(const ProviderScope(child: PairrideCustomerApp()));
}

class PairrideCustomerApp extends StatelessWidget {
  const PairrideCustomerApp({super.key});

  @override
  Widget build(BuildContext context) {
    const primaryOlive = Color(0xFF556B2F);

    return MaterialApp(
      title: 'Pairride Customer',
      themeMode: ThemeMode.system,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: primaryOlive,
          brightness: Brightness.light,
        ),
        useMaterial3: true,
        fontFamily: 'Inter',
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: primaryOlive,
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
        fontFamily: 'Inter',
      ),
      home: const RootGate(),
    );
  }
}

/// Shows a splash while restoring the session, then either the login screen
/// or the customer home screen depending on whether the user is authenticated.
class RootGate extends ConsumerWidget {
  const RootGate({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authProvider);

    if (auth.restoring) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (!auth.isLoggedIn) {
      return const LoginScreen();
    }

    return const CustomerHomeScreen();
  }
}

