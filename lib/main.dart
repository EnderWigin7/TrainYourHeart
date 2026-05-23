import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'firebase_options.dart';
import 'screens/home_shell.dart';
import 'screens/login_screen.dart';
import 'screens/onboarding_screen.dart';
import 'services/auth_service.dart';
import 'services/biometric_service.dart';
import 'services/storage_service.dart';
import 'services/units_service.dart';
import 'theme.dart';
import 'widgets/app_gradient_background.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
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

class _AuthGate extends StatefulWidget {
  const _AuthGate();

  @override
  State<_AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<_AuthGate> {
  final _storage = StorageService();
  final _biometrics = BiometricService();
  bool _onboardingDone = false;
  bool _ready = false;
  bool _biometricApproved = false;

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    final onboardingDone = await _storage.isOnboardingDone();
    if (!mounted) return;
    setState(() {
      _onboardingDone = onboardingDone;
      _ready = true;
    });
  }

  Future<void> _maybePromptBiometric(User user) async {
    if (_biometricApproved) return;
    final enabled = await _storage.isBiometricEnabled();
    if (!enabled) {
      _biometricApproved = true;
      return;
    }
    final canUse = await _biometrics.canUseBiometrics();
    if (!canUse) {
      _biometricApproved = true;
      return;
    }
    final ok = await _biometrics.authenticate(
      reason: 'Connectez-vous à Train Your Heart',
    );
    if (ok) {
      _biometricApproved = true;
      if (mounted) setState(() {});
    } else {
      // Failed biometric — sign out so the user can try again or use password.
      await AuthService.signOut();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_ready) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    if (!_onboardingDone) {
      return OnboardingScreen(onDone: () async {
        await _storage.setOnboardingDone(true);
        if (mounted) setState(() => _onboardingDone = true);
      });
    }
    return StreamBuilder<User?>(
      stream: AuthService.authStateChanges(),
      builder: (_, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        final user = snap.data;
        if (user == null) {
          _biometricApproved = false;
          return const LoginScreen();
        }
        // Trigger biometric prompt once per session.
        if (!_biometricApproved) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _maybePromptBiometric(user);
          });
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        return const HomeShell();
      },
    );
  }
}
