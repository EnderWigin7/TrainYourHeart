import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../services/biometric_service.dart';
import '../services/profile_photo_service.dart';
import '../services/storage_service.dart';
import '../services/units_service.dart';
import '../theme.dart';
import 'change_password_screen.dart';
import 'login_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _storage = StorageService();
  final _biometrics = BiometricService();
  final _photo = ProfilePhotoService();

  bool _loading = true;
  bool _biometricEnabled = false;
  bool _biometricSupported = false;
  bool _autoPause = false;
  bool _haptic = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final biometricEnabled = await _storage.isBiometricEnabled();
    final biometricSupported = await _biometrics.canUseBiometrics();
    final autoPause = await _storage.isAutoPauseEnabled();
    final haptic = await _storage.isHapticEnabled();
    if (!mounted) return;
    setState(() {
      _biometricEnabled = biometricEnabled;
      _biometricSupported = biometricSupported;
      _autoPause = autoPause;
      _haptic = haptic;
      _loading = false;
    });
  }

  Future<void> _toggleBiometric(bool value) async {
    if (value) {
      final ok = await _biometrics.authenticate(
        reason: 'Confirmez pour activer la connexion biométrique',
      );
      if (!ok) return;
      await _storage.setBiometricEnabled(true);
    } else {
      await _storage.setBiometricEnabled(false);
    }
    if (!mounted) return;
    setState(() => _biometricEnabled = value);
  }

  Future<void> _toggleAutoPause(bool value) async {
    await _storage.setAutoPauseEnabled(value);
    if (!mounted) return;
    setState(() => _autoPause = value);
  }

  Future<void> _toggleHaptic(bool value) async {
    await _storage.setHapticEnabled(value);
    if (!mounted) return;
    setState(() => _haptic = value);
  }

  Future<void> _exportData() async {
    try {
      final profile = await _storage.loadProfile();
      final runs = await _storage.loadRuns();
      final payload = {
        'exportedAt': DateTime.now().toIso8601String(),
        'profile': profile?.toJson(),
        'runs': runs.map((r) => r.toJson()).toList(),
      };
      final tmp = await getTemporaryDirectory();
      final file = File(
        '${tmp.path}/train_your_heart_export_${DateTime.now().millisecondsSinceEpoch}.json',
      );
      await file.writeAsString(
        const JsonEncoder.withIndent('  ').convert(payload),
      );
      await Share.shareXFiles(
        [XFile(file.path)],
        subject: 'Train Your Heart - Export',
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Erreur lors de l\'export')),
      );
    }
  }

  Future<void> _wipeData() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.cardBackground,
        title: const Text('Effacer toutes les données ?'),
        content: const Text(
          'Cette action est irréversible. Votre profil, vos courses et vos réglages seront supprimés.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text(
              'Effacer',
              style: TextStyle(color: Colors.redAccent),
            ),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    try {
      final profile = await _storage.loadProfile();
      await _photo.deleteIfExists(profile?.photoPath);
      await _storage.clearAll();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Erreur lors de la suppression')),
      );
      return;
    }
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (_) => false,
    );
  }

  Future<void> _logout() async {
    try {
      await _storage.setLoggedIn(false);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Erreur lors de la déconnexion')),
      );
      return;
    }
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (_) => false,
    );
  }

  void _showPrivacy() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.cardBackground,
        title: const Text('Confidentialité'),
        content: const SingleChildScrollView(
          child: Text(
            'Train Your Heart fonctionne entièrement sur votre appareil. '
            'Aucune donnée n\'est envoyée vers un serveur. '
            'Votre profil, vos courses et votre photo restent dans le stockage local de l\'application. '
            'Vous pouvez à tout moment exporter vos données ou les effacer depuis cet écran.',
            style: TextStyle(color: AppColors.subtleGrey, height: 1.4),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Fermer'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    return Scaffold(
      appBar: AppBar(title: const Text('PARAMÈTRES')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
        children: [
          const _SectionLabel('SÉCURITÉ'),
          const SizedBox(height: 8),
          Card(
            child: Column(
              children: [
                if (_biometricSupported) ...[
                  SwitchListTile(
                    value: _biometricEnabled,
                    onChanged: _toggleBiometric,
                    activeThumbColor: AppColors.stravaOrange,
                    title: const Text('Connexion biométrique'),
                    subtitle: const Text(
                      'Empreinte ou Face ID pour vous connecter',
                      style: TextStyle(
                          color: AppColors.subtleGrey, fontSize: 12),
                    ),
                  ),
                  const Divider(height: 0, color: Colors.white12),
                ],
                ListTile(
                  leading: const Icon(Icons.lock_outline,
                      color: AppColors.stravaOrange),
                  title: const Text('Changer le mot de passe'),
                  trailing: const Icon(Icons.chevron_right,
                      color: AppColors.subtleGrey),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const ChangePasswordScreen(),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          const _SectionLabel('COURSE'),
          const SizedBox(height: 8),
          Card(
            child: Column(
              children: [
                ListenableBuilder(
                  listenable: UnitsService.instance,
                  builder: (_, _) => SwitchListTile(
                    value: UnitsService.instance.imperial,
                    onChanged: (v) =>
                        UnitsService.instance.setImperial(v),
                    activeThumbColor: AppColors.stravaOrange,
                    title: const Text('Unités impériales'),
                    subtitle: Text(
                      UnitsService.instance.imperial
                          ? 'Distances en miles (mi)'
                          : 'Distances en kilomètres (km)',
                      style: const TextStyle(
                          color: AppColors.subtleGrey, fontSize: 12),
                    ),
                  ),
                ),
                const Divider(height: 0, color: Colors.white12),
                SwitchListTile(
                  value: _autoPause,
                  onChanged: _toggleAutoPause,
                  activeThumbColor: AppColors.stravaOrange,
                  title: const Text('Pause automatique'),
                  subtitle: const Text(
                    'Mettre la course en pause lorsque vous êtes immobile',
                    style:
                        TextStyle(color: AppColors.subtleGrey, fontSize: 12),
                  ),
                ),
                const Divider(height: 0, color: Colors.white12),
                SwitchListTile(
                  value: _haptic,
                  onChanged: _toggleHaptic,
                  activeThumbColor: AppColors.stravaOrange,
                  title: const Text('Retours haptiques'),
                  subtitle: const Text(
                    'Vibrations au démarrage, pause et chaque km',
                    style:
                        TextStyle(color: AppColors.subtleGrey, fontSize: 12),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          const _SectionLabel('DONNÉES'),
          const SizedBox(height: 8),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.ios_share,
                      color: AppColors.stravaOrange),
                  title: const Text('Exporter mes données'),
                  subtitle: const Text(
                    'Profil et historique au format JSON',
                    style: TextStyle(
                        color: AppColors.subtleGrey, fontSize: 12),
                  ),
                  onTap: _exportData,
                ),
                const Divider(height: 0, color: Colors.white12),
                ListTile(
                  leading:
                      const Icon(Icons.delete_forever, color: Colors.redAccent),
                  title: const Text(
                    'Effacer toutes les données',
                    style: TextStyle(color: Colors.redAccent),
                  ),
                  onTap: _wipeData,
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          const _SectionLabel('COMPTE'),
          const SizedBox(height: 8),
          Card(
            child: ListTile(
              leading: const Icon(Icons.logout, color: AppColors.subtleGrey),
              title: const Text('Se déconnecter'),
              onTap: _logout,
            ),
          ),
          const SizedBox(height: 24),
          const _SectionLabel('À PROPOS'),
          const SizedBox(height: 8),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.shield_outlined,
                      color: AppColors.subtleGrey),
                  title: const Text('Confidentialité'),
                  trailing: const Icon(Icons.chevron_right,
                      color: AppColors.subtleGrey),
                  onTap: _showPrivacy,
                ),
                const Divider(height: 0, color: Colors.white12),
                ListTile(
                  leading: const Icon(Icons.description_outlined,
                      color: AppColors.subtleGrey),
                  title: const Text('Licences open-source'),
                  trailing: const Icon(Icons.chevron_right,
                      color: AppColors.subtleGrey),
                  onTap: () => showLicensePage(
                    context: context,
                    applicationName: 'Train Your Heart',
                    applicationVersion: '1.0.0',
                  ),
                ),
                const Divider(height: 0, color: Colors.white12),
                const ListTile(
                  leading: Icon(Icons.favorite, color: AppColors.stravaOrange),
                  title: Text('Train Your Heart'),
                  subtitle: Text(
                    'Version 1.0.0',
                    style:
                        TextStyle(color: AppColors.subtleGrey, fontSize: 12),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String label;
  const _SectionLabel(this.label);
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Text(
        label,
        style: const TextStyle(
          color: AppColors.subtleGrey,
          letterSpacing: 1.5,
          fontWeight: FontWeight.w700,
          fontSize: 12,
        ),
      ),
    );
  }
}
