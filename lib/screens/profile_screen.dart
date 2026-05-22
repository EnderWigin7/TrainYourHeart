import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../models/user_profile.dart';
import '../services/profile_photo_service.dart';
import '../services/storage_service.dart';
import '../services/units_service.dart';
import '../theme.dart';
import 'settings_screen.dart';

final _emailRegExp = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _storage = StorageService();
  final _photo = ProfilePhotoService();
  final _formKey = GlobalKey<FormState>();

  UserProfile _profile = UserProfile.empty;
  bool _loading = true;

  late TextEditingController _usernameCtrl;
  late TextEditingController _emailCtrl;
  late TextEditingController _weightCtrl;
  late TextEditingController _ageCtrl;
  late TextEditingController _goalCtrl;
  late TextEditingController _weeklyGoalCtrl;
  late TextEditingController _monthlyGoalCtrl;

  @override
  void initState() {
    super.initState();
    _usernameCtrl = TextEditingController();
    _emailCtrl = TextEditingController();
    _weightCtrl = TextEditingController();
    _ageCtrl = TextEditingController();
    _goalCtrl = TextEditingController();
    _weeklyGoalCtrl = TextEditingController();
    _monthlyGoalCtrl = TextEditingController();
    UnitsService.instance.addListener(_onUnitsChanged);
    _load();
  }

  void _onUnitsChanged() {
    if (!mounted) return;
    final units = UnitsService.instance;
    setState(() {
      _goalCtrl.text =
          units.distance(_profile.dailyGoalKm).toStringAsFixed(1);
      _weeklyGoalCtrl.text =
          units.distance(_profile.weeklyGoalKm).toStringAsFixed(0);
      _monthlyGoalCtrl.text =
          units.distance(_profile.monthlyGoalKm).toStringAsFixed(0);
    });
  }

  Future<void> _load() async {
    final p = await _storage.loadProfile();
    if (!mounted) return;
    final units = UnitsService.instance;
    setState(() {
      _profile = p ?? UserProfile.empty;
      _usernameCtrl.text = _profile.username;
      _emailCtrl.text = _profile.email;
      _weightCtrl.text = _profile.weightKg.toString();
      _ageCtrl.text = _profile.age.toString();
      _goalCtrl.text =
          units.distance(_profile.dailyGoalKm).toStringAsFixed(1);
      _weeklyGoalCtrl.text =
          units.distance(_profile.weeklyGoalKm).toStringAsFixed(0);
      _monthlyGoalCtrl.text =
          units.distance(_profile.monthlyGoalKm).toStringAsFixed(0);
      _loading = false;
    });
  }

  @override
  void dispose() {
    UnitsService.instance.removeListener(_onUnitsChanged);
    _usernameCtrl.dispose();
    _emailCtrl.dispose();
    _weightCtrl.dispose();
    _ageCtrl.dispose();
    _goalCtrl.dispose();
    _weeklyGoalCtrl.dispose();
    _monthlyGoalCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final units = UnitsService.instance;
    final updated = _profile.copyWith(
      username: _usernameCtrl.text.trim(),
      email: _emailCtrl.text.trim(),
      weightKg: double.parse(_weightCtrl.text.replaceAll(',', '.')),
      age: int.parse(_ageCtrl.text),
      dailyGoalKm: units.distanceToKm(
          double.parse(_goalCtrl.text.replaceAll(',', '.'))),
      weeklyGoalKm: units.distanceToKm(
          double.parse(_weeklyGoalCtrl.text.replaceAll(',', '.'))),
      monthlyGoalKm: units.distanceToKm(
          double.parse(_monthlyGoalCtrl.text.replaceAll(',', '.'))),
    );
    try {
      await _storage.saveProfile(updated);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Erreur lors de la sauvegarde')),
      );
      return;
    }
    if (!mounted) return;
    setState(() => _profile = updated);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Profil mis à jour')),
    );
  }

  Future<void> _changePhoto() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 12),
            ListTile(
              leading: const Icon(Icons.photo_library,
                  color: AppColors.stravaOrange),
              title: const Text('Choisir depuis la galerie'),
              onTap: () => Navigator.pop(ctx, ImageSource.gallery),
            ),
            ListTile(
              leading: const Icon(Icons.photo_camera,
                  color: AppColors.stravaOrange),
              title: const Text('Prendre une photo'),
              onTap: () => Navigator.pop(ctx, ImageSource.camera),
            ),
            if (_profile.photoPath != null)
              ListTile(
                leading: const Icon(Icons.delete_outline, color: Colors.redAccent),
                title: const Text('Supprimer la photo'),
                onTap: () => Navigator.pop(ctx, null),
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (!mounted) return;

    if (source == null && _profile.photoPath != null) {
      await _photo.deleteIfExists(_profile.photoPath);
      final updated = _profile.copyWith(clearPhoto: true);
      try {
        await _storage.saveProfile(updated);
      } catch (_) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Erreur lors de la suppression')),
        );
        return;
      }
      if (!mounted) return;
      setState(() => _profile = updated);
      return;
    }
    if (source == null) return;

    try {
      final path = await _photo.pickAndSave(source: source);
      if (path == null || !mounted) return;
      await _photo.deleteIfExists(_profile.photoPath);
      final updated = _profile.copyWith(photoPath: path);
      await _storage.saveProfile(updated);
      if (!mounted) return;
      setState(() => _profile = updated);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Impossible de charger la photo')),
      );
    }
  }

  String? _validateEmail(String? v) {
    if (v == null || !_emailRegExp.hasMatch(v.trim())) return 'Email invalide';
    return null;
  }

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

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    return Scaffold(
      appBar: AppBar(
        title: const Text('PROFIL'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            tooltip: 'Paramètres',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const SettingsScreen()),
            ),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
          children: [
            Center(child: _Avatar(profile: _profile, onTap: _changePhoto)),
            const SizedBox(height: 24),
            const _SectionLabel('IDENTIFIANTS'),
            const SizedBox(height: 8),
            TextFormField(
              controller: _usernameCtrl,
              decoration: const InputDecoration(labelText: 'Nom d\'utilisateur'),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Requis' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _emailCtrl,
              decoration: const InputDecoration(labelText: 'Email'),
              keyboardType: TextInputType.emailAddress,
              validator: _validateEmail,
            ),
            const SizedBox(height: 24),
            const _SectionLabel('INFORMATIONS PHYSIQUES'),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _weightCtrl,
                    decoration: const InputDecoration(labelText: 'Poids (kg)'),
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    validator: (v) => _validateDouble(v, min: 20, max: 300),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _ageCtrl,
                    decoration: const InputDecoration(labelText: 'Âge'),
                    keyboardType: TextInputType.number,
                    validator: (v) => _validateInt(v, min: 5, max: 120),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            const _SectionLabel('OBJECTIFS'),
            const SizedBox(height: 8),
            TextFormField(
              controller: _goalCtrl,
              decoration: InputDecoration(
                  labelText:
                      'Objectif quotidien (${UnitsService.instance.distanceUnit()})'),
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              validator: (v) => _validateDouble(v, min: 0.1, max: 200),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _weeklyGoalCtrl,
              decoration: InputDecoration(
                  labelText:
                      'Objectif hebdomadaire (${UnitsService.instance.distanceUnit()})'),
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              validator: (v) => _validateDouble(v, min: 1, max: 1500),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _monthlyGoalCtrl,
              decoration: InputDecoration(
                  labelText:
                      'Objectif mensuel (${UnitsService.instance.distanceUnit()})'),
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              validator: (v) => _validateDouble(v, min: 1, max: 5000),
            ),
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: _save,
              child: const Text('ENREGISTRER'),
            ),
          ],
        ),
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  final UserProfile profile;
  final VoidCallback onTap;
  const _Avatar({required this.profile, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final hasPhoto = profile.photoPath != null;
    return GestureDetector(
      onTap: onTap,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: 112,
            height: 112,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(
                colors: [AppColors.stravaOrange, Color(0xFFFF7A36)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              boxShadow: [
                BoxShadow(
                  color: AppColors.stravaOrange.withValues(alpha: 0.4),
                  blurRadius: 24,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            padding: const EdgeInsets.all(3),
            child: ClipOval(
              child: hasPhoto
                  ? Image.file(
                      File(profile.photoPath!),
                      fit: BoxFit.cover,
                    )
                  : Container(
                      color: AppColors.cardBackground,
                      alignment: Alignment.center,
                      child: Text(
                        (profile.username.isNotEmpty
                                ? profile.username[0]
                                : '?')
                            .toUpperCase(),
                        style: const TextStyle(
                          fontSize: 42,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
            ),
          ),
          Positioned(
            right: 0,
            bottom: 0,
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: AppColors.darkBackground,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white24),
              ),
              child: const Icon(
                Icons.camera_alt,
                size: 18,
                color: Colors.white,
              ),
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
    return Text(
      label,
      style: const TextStyle(
        color: AppColors.subtleGrey,
        letterSpacing: 1.5,
        fontWeight: FontWeight.w700,
        fontSize: 12,
      ),
    );
  }
}
