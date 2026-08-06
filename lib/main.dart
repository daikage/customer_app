import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'screens/home_screen.dart';

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
      home: const CustomerHomeScreen(),
    );
  }
}
