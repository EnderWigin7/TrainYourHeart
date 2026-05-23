import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import '../models/user_profile.dart';
import '../services/achievements_service.dart';
import '../services/auth_service.dart';
import '../services/firestore_service.dart';
import '../services/profile_photo_service.dart';
import '../services/units_service.dart';
import '../theme.dart';
import '../widgets/animated_number.dart';
import 'achievements_screen.dart';
import 'profile_edit_screen.dart';
import 'settings_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _firestore = FirestoreService();
  final _photo = ProfilePhotoService();

  UserProfile _profile = UserProfile.empty;
  LifetimeStats _lifetime = LifetimeStats.empty;
  List<Achievement> _achievements = const [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
    FirestoreService.runsChanged.addListener(_load);
    UnitsService.instance.addListener(_onUnitsChanged);
  }

  @override
  void dispose() {
    FirestoreService.runsChanged.removeListener(_load);
    UnitsService.instance.removeListener(_onUnitsChanged);
    super.dispose();
  }

  void _onUnitsChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _load() async {
    final p = await _firestore.loadProfile();
    final stats = await _firestore.loadLifetimeStats();
    final achievements = await AchievementsService().compute();
    if (!mounted) return;
    setState(() {
      _profile = p ?? UserProfile.empty;
      _lifetime = stats;
      _achievements = achievements;
      _loading = false;
    });
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
                leading:
                    const Icon(Icons.delete_outline, color: Colors.redAccent),
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
        await _firestore.saveProfile(updated);
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
      await _firestore.saveProfile(updated);
      if (!mounted) return;
      setState(() => _profile = updated);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Impossible de charger la photo')),
      );
    }
  }

  Future<void> _openEdit() async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const ProfileEditScreen()),
    );
    _load();
  }

  String _fmtDuration(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes % 60;
    if (h == 0) return '${m}min';
    return '${h}h ${m.toString().padLeft(2, '0')}min';
  }

  String _memberSinceLabel() {
    final user = AuthService.currentUser;
    final created = user?.metadata.creationTime;
    if (created == null) return '—';
    return DateFormat('MMMM yyyy', 'fr_FR').format(created);
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final units = UnitsService.instance;
    return Scaffold(
      appBar: AppBar(
        title: const Text('PROFIL'),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            tooltip: 'Modifier le profil',
            onPressed: _openEdit,
          ),
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            tooltip: 'Paramètres',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const SettingsScreen()),
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
        children: [
          Center(child: _Avatar(profile: _profile, onTap: _changePhoto)),
          const SizedBox(height: 16),
          Center(
            child: Text(
              _profile.username.isNotEmpty ? _profile.username : 'Anonyme',
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: Colors.white,
              ),
            ),
          ),
          const SizedBox(height: 4),
          Center(
            child: Text(
              _profile.email,
              style: const TextStyle(
                color: AppColors.subtleGrey,
                fontSize: 13,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Center(
            child: Text(
              'Membre depuis ${_memberSinceLabel()}',
              style: const TextStyle(
                color: AppColors.subtleGrey,
                fontSize: 12,
                letterSpacing: 0.5,
              ),
            ),
          ),
          const SizedBox(height: 24),
          const _SectionLabel('TES STATISTIQUES'),
          const SizedBox(height: 8),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  _StatRow(
                    icon: Icons.directions_run,
                    label: 'Courses',
                    value: _lifetime.totalRuns.toDouble(),
                    format: (v) => v.toInt().toString(),
                  ),
                  const Divider(color: Colors.white12, height: 24),
                  _StatRow(
                    icon: Icons.straighten,
                    label: 'Distance totale',
                    value: units.distance(_lifetime.totalDistanceKm),
                    format: (v) =>
                        '${v.toStringAsFixed(1)} ${units.distanceUnit()}',
                  ),
                  const Divider(color: Colors.white12, height: 24),
                  _StatRow(
                    icon: Icons.timer_outlined,
                    label: 'Temps total',
                    value: _lifetime.totalActiveTime.inSeconds.toDouble(),
                    format: (_) => _fmtDuration(_lifetime.totalActiveTime),
                  ),
                  const Divider(color: Colors.white12, height: 24),
                  _StatRow(
                    icon: Icons.show_chart,
                    label: 'Moyenne par course',
                    value: units.distance(_lifetime.avgDistanceKm),
                    format: (v) =>
                        '${v.toStringAsFixed(2)} ${units.distanceUnit()}',
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          const _SectionLabel('BADGES'),
          const SizedBox(height: 8),
          Card(
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const AchievementsScreen(),
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.emoji_events,
                            color: AppColors.stravaOrange),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            '${_achievements.where((a) => a.unlocked).length} / ${_achievements.length} débloqués',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        const Icon(Icons.chevron_right,
                            color: AppColors.subtleGrey),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final a in _achievements
                            .where((a) => a.unlocked)
                            .take(6))
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: AppColors.stravaOrange
                                  .withValues(alpha: 0.18),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(a.icon,
                                    color: AppColors.stravaOrange, size: 14),
                                const SizedBox(width: 6),
                                Text(
                                  a.title,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        if (_achievements.every((a) => !a.unlocked))
                          const Text(
                            'Aucun badge débloqué pour l\'instant.',
                            style: TextStyle(
                              color: AppColors.subtleGrey,
                              fontSize: 12,
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final double value;
  final String Function(double) format;
  const _StatRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.format,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: AppColors.stravaOrange, size: 22),
        const SizedBox(width: 14),
        Expanded(
          child: Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
            ),
          ),
        ),
        AnimatedNumber(
          value: value,
          formatter: format,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
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
