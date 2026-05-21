import 'package:flutter/material.dart';
import 'package:intl/intl.dart' hide TextDirection;
import '../models/run.dart';
import '../theme.dart';

class RunShareCard extends StatelessWidget {
  final Run run;
  final String username;
  const RunShareCard({super.key, required this.run, required this.username});

  String _fmtDuration(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes % 60;
    final s = d.inSeconds % 60;
    if (h > 0) {
      return '${h}h ${m.toString().padLeft(2, '0')}m';
    }
    return '${m}m ${s.toString().padLeft(2, '0')}s';
  }

  String _fmtPace(Run r) {
    if (r.averageSpeedKmh <= 0) return '--:--';
    final minPerKm = 60.0 / r.averageSpeedKmh;
    final m = minPerKm.floor();
    final s = ((minPerKm - m) * 60).round();
    return '$m:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final dateLabel =
        DateFormat('EEEE d MMMM, HH:mm', 'fr_FR').format(run.startTime);
    return MediaQuery(
      data: const MediaQueryData(),
      child: Directionality(
        textDirection: TextDirection.ltr,
        child: Material(
          color: Colors.transparent,
          child: Container(
            width: 1080,
            height: 1080,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFF1A0A0A),
                  Color(0xFF111111),
                  Color(0xFF0A0A14),
                ],
              ),
            ),
            child: Stack(
              children: [
                Positioned(
                  top: -160,
                  right: -120,
                  child: Container(
                    width: 600,
                    height: 600,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [
                          AppColors.stravaOrange.withValues(alpha: 0.5),
                          AppColors.stravaOrange.withValues(alpha: 0),
                        ],
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(64),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.favorite,
                              color: AppColors.stravaOrange, size: 42),
                          const SizedBox(width: 12),
                          const Text(
                            'TRAIN YOUR HEART',
                            style: TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.w900,
                              color: Colors.white,
                              letterSpacing: 2,
                            ),
                          ),
                          const Spacer(),
                          if (username.isNotEmpty)
                            Text(
                              '@$username',
                              style: const TextStyle(
                                color: AppColors.subtleGrey,
                                fontSize: 24,
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 48),
                      Text(
                        dateLabel,
                        style: const TextStyle(
                          color: AppColors.subtleGrey,
                          fontSize: 28,
                          letterSpacing: 1.5,
                        ),
                      ),
                      const SizedBox(height: 24),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.baseline,
                        textBaseline: TextBaseline.alphabetic,
                        children: [
                          Text(
                            run.distanceKm.toStringAsFixed(2),
                            style: const TextStyle(
                              fontSize: 220,
                              fontWeight: FontWeight.w900,
                              color: Colors.white,
                              height: 1,
                            ),
                          ),
                          const SizedBox(width: 16),
                          const Text(
                            'km',
                            style: TextStyle(
                              fontSize: 48,
                              color: AppColors.subtleGrey,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 48),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _StatBlock(
                            label: 'DURÉE',
                            value: _fmtDuration(run.duration),
                          ),
                          _StatBlock(
                            label: 'ALLURE',
                            value: '${_fmtPace(run)} /km',
                          ),
                          _StatBlock(
                            label: 'KCAL',
                            value: run.caloriesBurned.toStringAsFixed(0),
                          ),
                        ],
                      ),
                      const Spacer(),
                      Row(
                        children: [
                          Container(
                            width: 64,
                            height: 4,
                            color: AppColors.stravaOrange,
                          ),
                          const SizedBox(width: 16),
                          const Text(
                            'Run. Track. Progress.',
                            style: TextStyle(
                              color: AppColors.subtleGrey,
                              fontSize: 22,
                              letterSpacing: 2,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _StatBlock extends StatelessWidget {
  final String label;
  final String value;
  const _StatBlock({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: AppColors.subtleGrey,
            letterSpacing: 2,
            fontSize: 20,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          value,
          style: const TextStyle(
            fontSize: 56,
            fontWeight: FontWeight.w900,
            color: Colors.white,
          ),
        ),
      ],
    );
  }
}
