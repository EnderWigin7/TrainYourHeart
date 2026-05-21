import 'package:flutter/material.dart';
import '../models/user_profile.dart';
import '../services/biometric_service.dart';
import '../services/password_hasher.dart';
import '../services/storage_service.dart';
import '../theme.dart';
import '../widgets/glass_card.dart';
import 'home_shell.dart';

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
  UserProfile? _existing;

  @override
  void initState() {
    super.initState();
    _loadExisting();
  }

  Future<void> _loadExisting() async {
    final p = await _storage.loadProfile();
    if (p != null && p.passwordHash.isNotEmpty && mounted) {
      setState(() {
        _existing = p;
        _isSignUp = false;
        _usernameCtrl.text = p.username;
        _emailCtrl.text = p.email;
      });
    }
  }

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
        final hashed = PasswordHasher.hash(_passwordCtrl.text);
        final profile = UserProfile(
          username: _usernameCtrl.text.trim(),
          email: _emailCtrl.text.trim(),
          passwordHash: hashed.hash,
          passwordSalt: hashed.salt,
          weightKg: double.parse(_weightCtrl.text.replaceAll(',', '.')),
          age: int.parse(_ageCtrl.text),
          dailyGoalKm: double.parse(_goalCtrl.text.replaceAll(',', '.')),
        );
        await _storage.saveProfile(profile);
        await _storage.setLoggedIn(true);
        didSignUp = true;
      } else {
        final existing = _existing;
        final emailMatches =
            existing != null && existing.email == _emailCtrl.text.trim();
        final passwordMatches = existing != null &&
            PasswordHasher.verify(
              _passwordCtrl.text,
              existing.passwordHash,
              existing.passwordSalt,
            );
        if (!emailMatches || !passwordMatches) {
          if (!mounted) return;
          setState(() => _loading = false);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Identifiants invalides')),
          );
          return;
        }
        await _storage.setLoggedIn(true);
      }
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Erreur d\'enregistrement, réessayez')),
      );
      return;
    }

    if (didSignUp && mounted) {
      await _maybeOfferBiometrics();
    }

    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const HomeShell()),
    );
  }

  Future<void> _maybeOfferBiometrics() async {
    final canUse = await _biometrics.canUseBiometrics();
    if (!canUse || !mounted) return;
    final accepted = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.cardBackground,
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
      (v == null || v.length < 4) ? 'Min 4 caractères' : null;

  String? _validatePasswordConfirm(String? v) =>
      (v != _passwordCtrl.text) ? 'Les mots de passe ne correspondent pas' : null;

  String? _validateDouble(String? v, {required double min, required double max}) {
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
                                        ? (v) =>
                                            _validateDouble(v, min: 20, max: 300)
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
