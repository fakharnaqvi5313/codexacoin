import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'services/wallet_service.dart';
import 'screens/lock_screen.dart';
import 'screens/onboarding_screen.dart';
import 'screens/home_screen.dart';

void main() {
  runApp(const CacWalletApp());
}

class CacWalletApp extends StatelessWidget {
  const CacWalletApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => WalletService(),
      child: MaterialApp(
        title: 'CodexaCoin Wallet',
        theme: ThemeData(
          colorSchemeSeed: const Color(0xFFF0C350), // matches the CAC logo's gold
          brightness: Brightness.dark,
          useMaterial3: true,
        ),
        home: const _Bootstrap(),
      ),
    );
  }
}

/// Loads wallet state (does it exist? which network?) before deciding
/// whether to show onboarding, the biometric lock screen, or the home
/// screen directly.
class _Bootstrap extends StatefulWidget {
  const _Bootstrap();

  @override
  State<_Bootstrap> createState() => _BootstrapState();
}

class _BootstrapState extends State<_Bootstrap> {
  @override
  void initState() {
    super.initState();
    context.read<WalletService>().bootstrap();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<WalletService>(
      builder: (context, wallet, _) {
        if (!wallet.loaded) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        if (!wallet.hasWallet) {
          return const OnboardingScreen();
        }
        return const LockScreen(child: HomeScreen());
      },
    );
  }
}
