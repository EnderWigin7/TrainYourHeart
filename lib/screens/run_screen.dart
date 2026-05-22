import 'package:flutter/material.dart';
import '../models/run.dart';
import '../services/run_tracker.dart';
import '../services/storage_service.dart';
import '../services/units_service.dart';
import '../theme.dart';

class RunScreen extends StatefulWidget {
  final double weightKg;
  const RunScreen({super.key, required this.weightKg});

  @override
  State<RunScreen> createState() => _RunScreenState();
}

class _RunScreenState extends State<RunScreen> {
  RunTracker? _tracker;
  final _storage = StorageService();

  @override
  void initState() {
    super.initState();
    _initTracker();
  }

  Future<void> _initTracker() async {
    final autoPause = await _storage.isAutoPauseEnabled();
    final haptic = await _storage.isHapticEnabled();
    if (!mounted) return;
    final tracker = RunTracker(
      weightKg: widget.weightKg,
      autoPause: autoPause,
      hapticFeedback: haptic,
    );
    tracker.addListener(_onUpdate);
    setState(() => _tracker = tracker);
    await tracker.start();
  }

  void _onUpdate() => setState(() {});

  @override
  void dispose() {
    _tracker?.removeListener(_onUpdate);
    _tracker?.dispose();
    super.dispose();
  }

  Future<void> _stopAndSave() async {
    final tracker = _tracker;
    if (tracker == null) {
      Navigator.of(context).pop();
      return;
    }
    if (tracker.duration.inSeconds < 3) {
      await tracker.stop();
      if (mounted) Navigator.of(context).pop();
      return;
    }
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.cardBackground,
        title: const Text('Terminer la course ?'),
        content: const Text('Votre activité sera sauvegardée.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Terminer',
                style: TextStyle(color: AppColors.stravaOrange)),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    await tracker.stop();

    _RunRecap? recap;
    if (mounted) {
      recap = await showModalBottomSheet<_RunRecap>(
        context: context,
        isScrollControlled: true,
        builder: (_) => const _RunRecapSheet(),
      );
    }

    final run = Run(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      startTime: tracker.startTime ?? DateTime.now(),
      duration: tracker.duration,
      distanceMeters: tracker.distanceMeters,
      caloriesBurned: tracker.caloriesBurned,
      averageSpeedKmh: tracker.averageSpeedKmh,
      splits: tracker.splits,
      note: recap?.note,
      difficulty: recap?.difficulty,
    );
    try {
      await _storage.addRun(run);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Erreur, course non sauvegardée')),
        );
      }
    }
    if (mounted) Navigator.of(context).pop();
  }

  String _fmtDuration(Duration d) {
    final h = d.inHours.toString().padLeft(2, '0');
    final m = (d.inMinutes % 60).toString().padLeft(2, '0');
    final s = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$h:$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final tracker = _tracker;
    if (tracker == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: _stopAndSave,
                  ),
                  const Spacer(),
                  if (tracker.isPaused)
                    Chip(
                      backgroundColor: Colors.white12,
                      label: Text(tracker.isAutoPaused
                          ? 'PAUSE AUTO'
                          : 'EN PAUSE'),
                    ),
                ],
              ),
              const SizedBox(height: 40),
              const Text(
                'DURÉE',
                style: TextStyle(
                  color: AppColors.subtleGrey,
                  letterSpacing: 2,
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _fmtDuration(tracker.duration),
                style: const TextStyle(
                  fontSize: 64,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                  fontFeatures: [FontFeature.tabularFigures()],
                ),
              ),
              const SizedBox(height: 40),
              _BigMetric(
                label: 'DISTANCE',
                value: UnitsService.instance
                    .distance(tracker.distanceKm)
                    .toStringAsFixed(2),
                unit: UnitsService.instance.distanceUnit(),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: _MetricTile(
                      label: 'VITESSE',
                      value: UnitsService.instance
                          .speed(tracker.currentSpeedKmh)
                          .toStringAsFixed(1),
                      unit: UnitsService.instance.speedUnit(),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _MetricTile(
                      label: 'CALORIES',
                      value: tracker.caloriesBurned.toStringAsFixed(0),
                      unit: 'kcal',
                    ),
                  ),
                ],
              ),
              const Spacer(),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _CircleButton(
                    icon: tracker.isPaused ? Icons.play_arrow : Icons.pause,
                    color: Colors.white24,
                    onTap: () =>
                        tracker.isPaused ? tracker.resume() : tracker.pause(),
                  ),
                  _CircleButton(
                    icon: Icons.stop,
                    color: AppColors.stravaOrange,
                    size: 84,
                    onTap: _stopAndSave,
                  ),
                ],
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}

class _BigMetric extends StatelessWidget {
  final String label;
  final String value;
  final String unit;
  const _BigMetric({
    required this.label,
    required this.value,
    required this.unit,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          label,
          style: const TextStyle(
            color: AppColors.subtleGrey,
            letterSpacing: 2,
            fontSize: 12,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text(
              value,
              style: const TextStyle(
                fontSize: 72,
                fontWeight: FontWeight.w900,
                color: AppColors.stravaOrange,
              ),
            ),
            const SizedBox(width: 4),
            Text(
              unit,
              style: const TextStyle(
                color: AppColors.subtleGrey,
                fontSize: 20,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _MetricTile extends StatelessWidget {
  final String label;
  final String value;
  final String unit;
  const _MetricTile({
    required this.label,
    required this.value,
    required this.unit,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: const TextStyle(
                color: AppColors.subtleGrey,
                letterSpacing: 1.2,
                fontSize: 11,
              ),
            ),
            const SizedBox(height: 6),
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(width: 4),
                Text(
                  unit,
                  style: const TextStyle(
                    color: AppColors.subtleGrey,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _CircleButton extends StatelessWidget {
  final IconData icon;
  final Color color;
  final double size;
  final VoidCallback onTap;
  const _CircleButton({
    required this.icon,
    required this.color,
    required this.onTap,
    this.size = 64,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      customBorder: const CircleBorder(),
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: color,
        ),
        child: Icon(icon, color: Colors.white, size: size * 0.5),
      ),
    );
  }
}

class _RunRecap {
  final String? note;
  final int? difficulty;
  const _RunRecap({this.note, this.difficulty});
}

class _RunRecapSheet extends StatefulWidget {
  const _RunRecapSheet();

  @override
  State<_RunRecapSheet> createState() => _RunRecapSheetState();
}

class _RunRecapSheetState extends State<_RunRecapSheet> {
  final _noteCtrl = TextEditingController();
  int? _difficulty;

  @override
  void dispose() {
    _noteCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'COMMENT C\'ÉTAIT ?',
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.2,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Difficulté',
                style: TextStyle(color: AppColors.subtleGrey, fontSize: 12),
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  for (int i = 1; i <= 5; i++)
                    _DifficultyButton(
                      level: i,
                      selected: _difficulty == i,
                      onTap: () => setState(
                          () => _difficulty = _difficulty == i ? null : i),
                    ),
                ],
              ),
              const SizedBox(height: 20),
              TextField(
                controller: _noteCtrl,
                decoration: const InputDecoration(
                  labelText: 'Note (optionnel)',
                ),
                maxLines: 3,
                textInputAction: TextInputAction.done,
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () =>
                          Navigator.of(context).pop(const _RunRecap()),
                      child: const Text(
                        'IGNORER',
                        style: TextStyle(color: AppColors.subtleGrey),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => Navigator.of(context).pop(
                        _RunRecap(
                          note: _noteCtrl.text.trim().isEmpty
                              ? null
                              : _noteCtrl.text.trim(),
                          difficulty: _difficulty,
                        ),
                      ),
                      child: const Text('SAUVEGARDER'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DifficultyButton extends StatelessWidget {
  final int level;
  final bool selected;
  final VoidCallback onTap;
  const _DifficultyButton({
    required this.level,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      customBorder: const CircleBorder(),
      child: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: selected ? AppColors.stravaOrange : Colors.white12,
          border: Border.all(
            color: selected
                ? AppColors.stravaOrange
                : Colors.white.withValues(alpha: 0.08),
          ),
        ),
        alignment: Alignment.center,
        child: Text(
          '$level',
          style: TextStyle(
            color: selected ? Colors.white : AppColors.subtleGrey,
            fontWeight: FontWeight.w800,
            fontSize: 16,
          ),
        ),
      ),
    );
  }
}
