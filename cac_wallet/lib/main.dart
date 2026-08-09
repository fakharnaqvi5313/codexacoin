import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'services/wallet_service.dart';
import 'screens/lock_screen.dart';
import 'screens/onboarding_screen.dart';
import 'screens/home_screen.dart';

void main() {
  runApp(const CacWalletApp());
}

const _goldSeed = Color(0xFFF0C350); // matches the CAC logo's gold

final ThemeData _darkTheme = ThemeData(
  colorSchemeSeed: _goldSeed,
  brightness: Brightness.dark,
  useMaterial3: true,
);
final ThemeData _lightTheme = ThemeData(
  colorSchemeSeed: _goldSeed,
  brightness: Brightness.light,
  useMaterial3: true,
);

ThemeMode _themeModeFor(String stored) {
  switch (stored) {
    case 'dark':
      return ThemeMode.dark;
    case 'light':
      return ThemeMode.light;
    default:
      return ThemeMode.system;
  }
}

class CacWalletApp extends StatelessWidget {
  const CacWalletApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => WalletService(),
      // Consumer (not a plain child) so MaterialApp rebuilds with the new
      // themeMode as soon as Settings changes it -- no app restart needed.
      child: Consumer<WalletService>(
        builder: (context, wallet, _) => MaterialApp(
          title: 'CodexaCoin Wallet',
          theme: _lightTheme,
          darkTheme: _darkTheme,
          themeMode: _themeModeFor(wallet.themeMode),
          home: const _Bootstrap(),
        ),
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
