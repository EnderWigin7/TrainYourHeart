import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../models/user_profile.dart';
import '../services/auth_service.dart';
import '../services/biometric_service.dart';
import '../services/firestore_service.dart';
import '../services/storage_service.dart';
import '../theme.dart';
import '../widgets/glass_card.dart';

final _emailRegExp = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
const _kAnim = Duration(milliseconds: 280);

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _storage = StorageService();
  final _biometrics = BiometricService();
  final _firestore = FirestoreService();

  final _usernameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _passwordConfirmCtrl = TextEditingController();
  final _weightCtrl = TextEditingController(text: '70');
  final _ageCtrl = TextEditingController(text: '25');
  final _goalCtrl = TextEditingController(text: '3.0');

  bool _isSignUp = true;
  bool _loading = false;
  bool _obscurePassword = true;
  bool _obscurePasswordConfirm = true;

  @override
  void dispose() {
    _usernameCtrl.dispose();
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _passwordConfirmCtrl.dispose();
    _weightCtrl.dispose();
    _ageCtrl.dispose();
    _goalCtrl.dispose();
    super.dispose();
  }

  void _setMode(bool signUp) {
    if (signUp == _isSignUp) return;
    setState(() {
      _isSignUp = signUp;
      _passwordCtrl.clear();
      _passwordConfirmCtrl.clear();
      _obscurePassword = true;
      _obscurePasswordConfirm = true;
    });
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);

    bool didSignUp = false;
    try {
      if (_isSignUp) {
        await AuthService.signUpWithEmail(
          email: _emailCtrl.text.trim(),
          password: _passwordCtrl.text,
        );
        final profile = UserProfile(
          username: _usernameCtrl.text.trim(),
          email: _emailCtrl.text.trim(),
          weightKg: double.parse(_weightCtrl.text.replaceAll(',', '.')),
          age: int.parse(_ageCtrl.text),
          dailyGoalKm: double.parse(_goalCtrl.text.replaceAll(',', '.')),
        );
        await _firestore.saveProfile(profile);
        didSignUp = true;
      } else {
        await AuthService.signInWithEmail(
          email: _emailCtrl.text.trim(),
          password: _passwordCtrl.text,
        );
      }
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      _showAuthError(e);
      return;
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
      _showError('Erreur, réessayez');
      return;
    }

    if (didSignUp && mounted) {
      await _maybeOfferBiometrics();
    }

    // Auth state stream in _AuthGate will navigate to HomeShell automatically.
  }

  Future<void> _googleSignIn() async {
    setState(() => _loading = true);
    try {
      final cred = await AuthService.signInWithGoogle();
      if (cred == null) {
        if (mounted) setState(() => _loading = false);
        return;
      }
      final user = cred.user!;
      await _firestore.ensureProfile(
        fallbackUsername: user.displayName ?? 'Coureur',
        email: user.email ?? '',
      );
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      _showAuthError(e);
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      // Show the real exception so SHA-1 / Play Services issues are visible.
      _showError('Google: $e');
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          duration: const Duration(seconds: 5),
        ),
      );
  }

  void _showAuthError(FirebaseAuthException e) {
    String message;
    String? actionLabel;
    VoidCallback? action;
    switch (e.code) {
      case 'invalid-credential':
      case 'user-not-found':
        message =
            'Email ou mot de passe incorrect. Vérifiez, ou créez un compte.';
        actionLabel = 'S\'INSCRIRE';
        action = () => _setMode(true);
        break;
      case 'wrong-password':
        message = 'Mot de passe incorrect.';
        break;
      case 'email-already-in-use':
        message = 'Cet email a déjà un compte. Connectez-vous.';
        actionLabel = 'CONNEXION';
        action = () => _setMode(false);
        break;
      case 'weak-password':
        message = 'Mot de passe trop faible (min 6 caractères).';
        break;
      case 'invalid-email':
        message = 'Email invalide.';
        break;
      case 'network-request-failed':
        message = 'Pas de connexion internet.';
        break;
      case 'too-many-requests':
        message = 'Trop de tentatives. Réessayez plus tard.';
        break;
      case 'operation-not-allowed':
        message = 'Méthode de connexion désactivée dans Firebase.';
        break;
      default:
        message = e.message ?? 'Erreur d\'authentification (${e.code})';
    }
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          duration: const Duration(seconds: 6),
          action: actionLabel != null && action != null
              ? SnackBarAction(
                  label: actionLabel,
                  textColor: AppColors.stravaOrange,
                  onPressed: action,
                )
              : null,
        ),
      );
  }

  Future<void> _maybeOfferBiometrics() async {
    final canUse = await _biometrics.canUseBiometrics();
    if (!canUse || !mounted) return;
    final accepted = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Connexion biométrique'),
        content: const Text(
          'Voulez-vous activer la connexion par empreinte ou reconnaissance faciale ?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Plus tard'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text(
              'Activer',
              style: TextStyle(color: AppColors.stravaOrange),
            ),
          ),
        ],
      ),
    );
    if (accepted == true) {
      final ok = await _biometrics.authenticate(
        reason: 'Confirmez pour activer la connexion biométrique',
      );
      if (ok) {
        await _storage.setBiometricEnabled(true);
      }
    }
  }

  String? _validateRequired(String? v) =>
      (v == null || v.trim().isEmpty) ? 'Requis' : null;

  String? _validateEmail(String? v) {
    if (v == null || !_emailRegExp.hasMatch(v.trim())) return 'Email invalide';
    return null;
  }

  String? _validatePassword(String? v) =>
      (v == null || v.length < 6) ? 'Min 6 caractères' : null;

  String? _validatePasswordConfirm(String? v) =>
      (v != _passwordCtrl.text) ? 'Les mots de passe ne correspondent pas' : null;

  String? _validateDouble(String? v,
      {required double min, required double max}) {
    if (v == null || v.trim().isEmpty) return 'Requis';
    final parsed = double.tryParse(v.trim().replaceAll(',', '.'));
    if (parsed == null) return 'Nombre invalide';
    if (parsed < min || parsed > max) return 'Entre $min et $max';
    return null;
  }

  String? _validateInt(String? v, {required int min, required int max}) {
    if (v == null || v.trim().isEmpty) return 'Requis';
    final parsed = int.tryParse(v.trim());
    if (parsed == null) return 'Nombre invalide';
    if (parsed < min || parsed > max) return 'Entre $min et $max';
    return null;
  }

  Widget _animatedReveal({required bool show, required Widget child}) {
    return AnimatedSize(
      duration: _kAnim,
      curve: Curves.easeOutCubic,
      alignment: Alignment.topCenter,
      child: AnimatedSwitcher(
        duration: _kAnim,
        switchInCurve: Curves.easeOutCubic,
        switchOutCurve: Curves.easeInCubic,
        transitionBuilder: (child, anim) => FadeTransition(
          opacity: anim,
          child: SizeTransition(
            sizeFactor: anim,
            axisAlignment: -1,
            child: child,
          ),
        ),
        child: show
            ? KeyedSubtree(key: const ValueKey('shown'), child: child)
            : const SizedBox.shrink(key: ValueKey('hidden')),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 16),
              const Center(
                child: Icon(
                  Icons.favorite,
                  size: 56,
                  color: AppColors.stravaOrange,
                ),
              ),
              const SizedBox(height: 12),
              const Center(
                child: Text(
                  'TRAIN YOUR HEART',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 2,
                  ),
                ),
              ),
              const SizedBox(height: 4),
              const Center(
                child: Text(
                  'Run. Track. Progress.',
                  style: TextStyle(
                    color: AppColors.subtleGrey,
                    fontSize: 13,
                    letterSpacing: 1,
                  ),
                ),
              ),
              const SizedBox(height: 24),
              GlassCard(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Center(
                        child: SegmentedButton<bool>(
                          style: SegmentedButton.styleFrom(
                            selectedBackgroundColor: AppColors.stravaOrange,
                            selectedForegroundColor: Colors.white,
                            foregroundColor: AppColors.subtleGrey,
                            side: const BorderSide(color: Colors.white24),
                          ),
                          segments: const [
                            ButtonSegment(value: false, label: Text('CONNEXION')),
                            ButtonSegment(value: true, label: Text('INSCRIPTION')),
                          ],
                          selected: {_isSignUp},
                          onSelectionChanged: (s) => _setMode(s.first),
                        ),
                      ),
                      const SizedBox(height: 20),
                      _animatedReveal(
                        show: _isSignUp,
                        child: Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: TextFormField(
                            controller: _usernameCtrl,
                            decoration: const InputDecoration(
                                labelText: 'Nom d\'utilisateur'),
                            validator: _isSignUp ? _validateRequired : null,
                          ),
                        ),
                      ),
                      TextFormField(
                        controller: _emailCtrl,
                        decoration: const InputDecoration(labelText: 'Email'),
                        keyboardType: TextInputType.emailAddress,
                        validator: _validateEmail,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _passwordCtrl,
                        decoration: InputDecoration(
                          labelText: 'Mot de passe',
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscurePassword
                                  ? Icons.visibility_off
                                  : Icons.visibility,
                              color: AppColors.subtleGrey,
                            ),
                            onPressed: () => setState(
                                () => _obscurePassword = !_obscurePassword),
                          ),
                        ),
                        obscureText: _obscurePassword,
                        validator: _validatePassword,
                      ),
                      _animatedReveal(
                        show: _isSignUp,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            const SizedBox(height: 12),
                            TextFormField(
                              controller: _passwordConfirmCtrl,
                              decoration: InputDecoration(
                                labelText: 'Confirmer le mot de passe',
                                suffixIcon: IconButton(
                                  icon: Icon(
                                    _obscurePasswordConfirm
                                        ? Icons.visibility_off
                                        : Icons.visibility,
                                    color: AppColors.subtleGrey,
                                  ),
                                  onPressed: () => setState(() =>
                                      _obscurePasswordConfirm =
                                          !_obscurePasswordConfirm),
                                ),
                              ),
                              obscureText: _obscurePasswordConfirm,
                              validator: _isSignUp
                                  ? _validatePasswordConfirm
                                  : null,
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(
                                  child: TextFormField(
                                    controller: _weightCtrl,
                                    decoration: const InputDecoration(
                                        labelText: 'Poids (kg)'),
                                    keyboardType:
                                        const TextInputType.numberWithOptions(
                                            decimal: true),
                                    validator: _isSignUp
                                        ? (v) => _validateDouble(v,
                                            min: 20, max: 300)
                                        : null,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: TextFormField(
                                    controller: _ageCtrl,
                                    decoration:
                                        const InputDecoration(labelText: 'Âge'),
                                    keyboardType: TextInputType.number,
                                    validator: _isSignUp
                                        ? (v) =>
                                            _validateInt(v, min: 5, max: 120)
                                        : null,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            TextFormField(
                              controller: _goalCtrl,
                              decoration: const InputDecoration(
                                  labelText: 'Objectif quotidien (km)'),
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                      decimal: true),
                              validator: _isSignUp
                                  ? (v) =>
                                      _validateDouble(v, min: 0.1, max: 100)
                                  : null,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 22),
                      ElevatedButton(
                        onPressed: _loading ? null : _submit,
                        child: _loading
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2, color: Colors.white),
                              )
                            : AnimatedSwitcher(
                                duration: _kAnim,
                                child: Text(
                                  _isSignUp
                                      ? 'CRÉER MON COMPTE'
                                      : 'SE CONNECTER',
                                  key: ValueKey(_isSignUp),
                                ),
                              ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: Divider(
                                color: Colors.white.withValues(alpha: 0.12)),
                          ),
                          const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 12),
                            child: Text(
                              'OU',
                              style: TextStyle(
                                color: AppColors.subtleGrey,
                                fontSize: 12,
                                letterSpacing: 1.5,
                              ),
                            ),
                          ),
                          Expanded(
                            child: Divider(
                                color: Colors.white.withValues(alpha: 0.12)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      OutlinedButton.icon(
                        onPressed: _loading ? null : _googleSignIn,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white,
                          side: BorderSide(
                              color: Colors.white.withValues(alpha: 0.18)),
                          shape: const StadiumBorder(),
                          padding:
                              const EdgeInsets.symmetric(vertical: 14),
                        ),
                        icon: SvgPicture.asset(
                          'assets/google_g.svg',
                          width: 20,
                          height: 20,
                        ),
                        label: const Text(
                          'CONTINUER AVEC GOOGLE',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.8,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
