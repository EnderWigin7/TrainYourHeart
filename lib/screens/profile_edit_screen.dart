import 'package:flutter/material.dart';
import '../models/user_profile.dart';
import '../services/firestore_service.dart';
import '../services/units_service.dart';
import '../theme.dart';

class ProfileEditScreen extends StatefulWidget {
  const ProfileEditScreen({super.key});

  @override
  State<ProfileEditScreen> createState() => _ProfileEditScreenState();
}

class _ProfileEditScreenState extends State<ProfileEditScreen> {
  final _firestore = FirestoreService();
  final _formKey = GlobalKey<FormState>();

  UserProfile _profile = UserProfile.empty;
  bool _loading = true;
  bool _saving = false;

  late TextEditingController _usernameCtrl;
  late TextEditingController _weightCtrl;
  late TextEditingController _ageCtrl;
  late TextEditingController _goalCtrl;
  late TextEditingController _weeklyGoalCtrl;
  late TextEditingController _monthlyGoalCtrl;

  @override
  void initState() {
    super.initState();
    _usernameCtrl = TextEditingController();
    _weightCtrl = TextEditingController();
    _ageCtrl = TextEditingController();
    _goalCtrl = TextEditingController();
    _weeklyGoalCtrl = TextEditingController();
    _monthlyGoalCtrl = TextEditingController();
    _load();
  }

  Future<void> _load() async {
    final p = await _firestore.loadProfile();
    if (!mounted) return;
    final units = UnitsService.instance;
    final profile = p ?? UserProfile.empty;
    setState(() {
      _profile = profile;
      _usernameCtrl.text = profile.username;
      _weightCtrl.text = profile.weightKg.toString();
      _ageCtrl.text = profile.age.toString();
      _goalCtrl.text =
          units.distance(profile.dailyGoalKm).toStringAsFixed(1);
      _weeklyGoalCtrl.text =
          units.distance(profile.weeklyGoalKm).toStringAsFixed(0);
      _monthlyGoalCtrl.text =
          units.distance(profile.monthlyGoalKm).toStringAsFixed(0);
      _loading = false;
    });
  }

  @override
  void dispose() {
    _usernameCtrl.dispose();
    _weightCtrl.dispose();
    _ageCtrl.dispose();
    _goalCtrl.dispose();
    _weeklyGoalCtrl.dispose();
    _monthlyGoalCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    final units = UnitsService.instance;
    final updated = _profile.copyWith(
      username: _usernameCtrl.text.trim(),
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
      await _firestore.saveProfile(updated);
    } catch (_) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Erreur lors de la sauvegarde')),
      );
      return;
    }
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Profil mis à jour')),
    );
    Navigator.of(context).pop();
  }

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

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final unitsLabel = UnitsService.instance.distanceUnit();
    return Scaffold(
      appBar: AppBar(title: const Text('MODIFIER LE PROFIL')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
          children: [
            const _SectionLabel('IDENTIFIANTS'),
            const SizedBox(height: 8),
            TextFormField(
              controller: _usernameCtrl,
              decoration:
                  const InputDecoration(labelText: 'Nom d\'utilisateur'),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Requis' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              initialValue: _profile.email,
              enabled: false,
              decoration: const InputDecoration(
                labelText: 'Email (géré par votre compte)',
              ),
            ),
            const SizedBox(height: 24),
            const _SectionLabel('INFORMATIONS PHYSIQUES'),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _weightCtrl,
                    decoration:
                        const InputDecoration(labelText: 'Poids (kg)'),
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
              decoration:
                  InputDecoration(labelText: 'Objectif quotidien ($unitsLabel)'),
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              validator: (v) => _validateDouble(v, min: 0.1, max: 200),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _weeklyGoalCtrl,
              decoration: InputDecoration(
                  labelText: 'Objectif hebdomadaire ($unitsLabel)'),
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              validator: (v) => _validateDouble(v, min: 1, max: 1500),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _monthlyGoalCtrl,
              decoration: InputDecoration(
                  labelText: 'Objectif mensuel ($unitsLabel)'),
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              validator: (v) => _validateDouble(v, min: 1, max: 5000),
            ),
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: _saving ? null : _save,
              child: _saving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : const Text('ENREGISTRER'),
            ),
          ],
        ),
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
