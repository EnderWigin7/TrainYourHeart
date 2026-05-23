import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../theme.dart';

class ChangePasswordScreen extends StatefulWidget {
  const ChangePasswordScreen({super.key});

  @override
  State<ChangePasswordScreen> createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends State<ChangePasswordScreen> {
  final _formKey = GlobalKey<FormState>();

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

    try {
      await AuthService.changePassword(
        currentPassword: _currentCtrl.text,
        newPassword: _newCtrl.text,
      );
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_friendlyError(e))),
      );
      return;
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

  String _friendlyError(FirebaseAuthException e) {
    switch (e.code) {
      case 'wrong-password':
      case 'invalid-credential':
        return 'Mot de passe actuel incorrect';
      case 'weak-password':
        return 'Nouveau mot de passe trop faible';
      case 'requires-recent-login':
        return 'Reconnectez-vous puis réessayez';
      default:
        return e.message ?? 'Erreur d\'authentification';
    }
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
    if (AuthService.isGoogleAccount) {
      return Scaffold(
        appBar: AppBar(title: const Text('CHANGER LE MOT DE PASSE')),
        body: const Padding(
          padding: EdgeInsets.all(24),
          child: Center(
            child: Text(
              'Votre compte est géré par Google.\n'
              'Modifiez votre mot de passe depuis votre compte Google.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.subtleGrey),
            ),
          ),
        ),
      );
    }
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
                  (v == null || v.length < 6) ? 'Min 6 caractères' : null,
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
