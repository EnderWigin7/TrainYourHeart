import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'screens/home_shell.dart';
import 'screens/login_screen.dart';
import 'screens/onboarding_screen.dart';
import 'services/biometric_service.dart';
import 'services/storage_service.dart';
import 'services/units_service.dart';
import 'theme.dart';
import 'widgets/app_gradient_background.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('fr_FR', null);
  await UnitsService.instance.load();
  runApp(const TrainYourHeartApp());
}

class TrainYourHeartApp extends StatelessWidget {
  const TrainYourHeartApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Train Your Heart',
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(),
      home: const _AuthGate(),
      builder: (context, child) => AppGradientBackground(
        child: child ?? const SizedBox.shrink(),
      ),
    );
  }
}

enum _GateState { loading, onboarding, login, home }

class _AuthGate extends StatefulWidget {
  const _AuthGate();

  @override
  State<_AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<_AuthGate> {
  final _storage = StorageService();
  final _biometrics = BiometricService();
  _GateState _state = _GateState.loading;

  @override
  void initState() {
    super.initState();
    _check();
  }

  Future<void> _check() async {
    final onboardingDone = await _storage.isOnboardingDone();
    if (!onboardingDone) {
      if (!mounted) return;
      setState(() => _state = _GateState.onboarding);
      return;
    }

    final loggedIn = await _storage.isLoggedIn();
    if (loggedIn) {
      if (!mounted) return;
      setState(() => _state = _GateState.home);
      return;
    }

    final biometricEnabled = await _storage.isBiometricEnabled();
    final profile = await _storage.loadProfile();
    final hasProfile = profile != null && profile.passwordHash.isNotEmpty;
    if (biometricEnabled && hasProfile) {
      final canUse = await _biometrics.canUseBiometrics();
      if (canUse) {
        final ok = await _biometrics.authenticate(
          reason: 'Connectez-vous à Train Your Heart',
        );
        if (ok) {
          await _storage.setLoggedIn(true);
          if (!mounted) return;
          setState(() => _state = _GateState.home);
          return;
        }
      }
    }

    if (!mounted) return;
    setState(() => _state = _GateState.login);
  }

  @override
  Widget build(BuildContext context) {
    switch (_state) {
      case _GateState.loading:
        return const Scaffold(
          body: Center(child: CircularProgressIndicator()),
        );
      case _GateState.onboarding:
        return OnboardingScreen(onDone: _check);
      case _GateState.login:
        return const LoginScreen();
      case _GateState.home:
        return const HomeShell();
    }
  }
}
