import 'package:flutter/material.dart';
import '../services/password_hasher.dart';
import '../services/storage_service.dart';
import '../theme.dart';

class ChangePasswordScreen extends StatefulWidget {
  const ChangePasswordScreen({super.key});

  @override
  State<ChangePasswordScreen> createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends State<ChangePasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _storage = StorageService();

  final _currentCtrl = TextEditingController();
  final _newCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();

  bool _loading = false;
  bool _obscureCurrent = true;
  bool _obscureNew = true;
  bool _obscureConfirm = true;

  @override
  void dispose() {
    _currentCtrl.dispose();
    _newCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);

    final profile = await _storage.loadProfile();
    if (profile == null) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profil introuvable')),
      );
      return;
    }

    final ok = PasswordHasher.verify(
      _currentCtrl.text,
      profile.passwordHash,
      profile.passwordSalt,
    );
    if (!ok) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Mot de passe actuel incorrect')),
      );
      return;
    }

    final hashed = PasswordHasher.hash(_newCtrl.text);
    try {
      await _storage.saveProfile(profile.copyWith(
        passwordHash: hashed.hash,
        passwordSalt: hashed.salt,
      ));
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Erreur lors de la sauvegarde')),
      );
      return;
    }

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Mot de passe mis à jour')),
    );
    Navigator.of(context).pop();
  }

  InputDecoration _decoration(
      String label, bool obscured, VoidCallback toggle) {
    return InputDecoration(
      labelText: label,
      suffixIcon: IconButton(
        icon: Icon(
          obscured ? Icons.visibility_off : Icons.visibility,
          color: AppColors.subtleGrey,
        ),
        onPressed: toggle,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('CHANGER LE MOT DE PASSE')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const SizedBox(height: 8),
            TextFormField(
              controller: _currentCtrl,
              decoration: _decoration(
                'Mot de passe actuel',
                _obscureCurrent,
                () => setState(() => _obscureCurrent = !_obscureCurrent),
              ),
              obscureText: _obscureCurrent,
              validator: (v) =>
                  (v == null || v.isEmpty) ? 'Requis' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _newCtrl,
              decoration: _decoration(
                'Nouveau mot de passe',
                _obscureNew,
                () => setState(() => _obscureNew = !_obscureNew),
              ),
              obscureText: _obscureNew,
              validator: (v) =>
                  (v == null || v.length < 4) ? 'Min 4 caractères' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _confirmCtrl,
              decoration: _decoration(
                'Confirmer le nouveau mot de passe',
                _obscureConfirm,
                () => setState(() => _obscureConfirm = !_obscureConfirm),
              ),
              obscureText: _obscureConfirm,
              validator: (v) =>
                  (v != _newCtrl.text) ? 'Les mots de passe ne correspondent pas' : null,
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _loading ? null : _submit,
              child: _loading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : const Text('METTRE À JOUR'),
            ),
          ],
        ),
      ),
    );
  }
}
