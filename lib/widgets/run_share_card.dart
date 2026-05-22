import 'package:flutter/material.dart';
import 'package:intl/intl.dart' hide TextDirection;
import '../models/run.dart';
import '../services/units_service.dart';
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

  @override
  Widget build(BuildContext context) {
    final units = UnitsService.instance;
    final dateLabel =
        DateFormat('EEEE d MMMM, HH:mm', 'fr_FR').format(run.startTime);
    final distanceValue = units.distance(run.distanceKm).toStringAsFixed(2);
    final pace = units.paceMinPerUnit(run.averageSpeedKmh);
    final paceLabel = pace > 0
        ? '${pace.floor()}:${((pace - pace.floor()) * 60).round().toString().padLeft(2, '0')} /${units.distanceUnit()}'
        : '--:-- /${units.distanceUnit()}';
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
                  padding: const EdgeInsets.all(56),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.favorite,
                              color: AppColors.stravaOrange, size: 40),
                          const SizedBox(width: 12),
                          const Text(
                            'TRAIN YOUR HEART',
                            style: TextStyle(
                              fontSize: 26,
                              fontWeight: FontWeight.w900,
                              color: Colors.white,
                              letterSpacing: 2,
                            ),
                          ),
                          const Spacer(),
                          if (username.isNotEmpty)
                            Flexible(
                              child: Text(
                                '@$username',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                textAlign: TextAlign.end,
                                style: const TextStyle(
                                  color: AppColors.subtleGrey,
                                  fontSize: 22,
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 56),
                      Text(
                        dateLabel,
                        style: const TextStyle(
                          color: AppColors.subtleGrey,
                          fontSize: 26,
                          letterSpacing: 1.5,
                        ),
                      ),
                      const SizedBox(height: 16),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.bottomLeft,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.baseline,
                          textBaseline: TextBaseline.alphabetic,
                          children: [
                            Text(
                              distanceValue,
                              style: const TextStyle(
                                fontSize: 200,
                                fontWeight: FontWeight.w900,
                                color: Colors.white,
                                height: 1,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Text(
                              units.distanceUnit(),
                              style: const TextStyle(
                                fontSize: 44,
                                color: AppColors.subtleGrey,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 48),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: _StatBlock(
                              label: 'DURÉE',
                              value: _fmtDuration(run.duration),
                            ),
                          ),
                          Expanded(
                            child: _StatBlock(
                              label: 'ALLURE',
                              value: paceLabel,
                            ),
                          ),
                          Expanded(
                            child: _StatBlock(
                              label: 'KCAL',
                              value: run.caloriesBurned.toStringAsFixed(0),
                            ),
                          ),
                        ],
                      ),
                      const Spacer(),
                      Row(
                        children: [
                          Container(
                            width: 56,
                            height: 4,
                            color: AppColors.stravaOrange,
                          ),
                          const SizedBox(width: 16),
                          const Text(
                            'Run. Track. Progress.',
                            style: TextStyle(
                              color: AppColors.subtleGrey,
                              fontSize: 20,
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
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 12),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(
            value,
            style: const TextStyle(
              fontSize: 48,
              fontWeight: FontWeight.w900,
              color: Colors.white,
            ),
          ),
        ),
      ],
    );
  }
}
