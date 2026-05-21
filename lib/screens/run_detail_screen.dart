import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/run.dart';
import '../services/run_share_service.dart';
import '../theme.dart';

class RunDetailScreen extends StatelessWidget {
  final Run run;
  final String username;
  const RunDetailScreen({
    super.key,
    required this.run,
    required this.username,
  });

  String _fmtDuration(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes % 60;
    final s = d.inSeconds % 60;
    if (h > 0) {
      return '${h}h ${m.toString().padLeft(2, '0')}m ${s.toString().padLeft(2, '0')}s';
    }
    return '${m}m ${s.toString().padLeft(2, '0')}s';
  }

  String _fmtPace(double minPerKm) {
    if (minPerKm <= 0 || !minPerKm.isFinite) return '--:--';
    final m = minPerKm.floor();
    final s = ((minPerKm - m) * 60).round();
    return '$m:${s.toString().padLeft(2, '0')}';
  }

  Future<void> _share(BuildContext context) async {
    try {
      await RunShareService().shareRun(
        run: run,
        username: username,
        context: context,
      );
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Erreur lors du partage')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final avgPace = run.averageSpeedKmh > 0 ? 60.0 / run.averageSpeedKmh : 0;
    final dateLabel =
        DateFormat('EEEE d MMMM yyyy, HH:mm', 'fr_FR').format(run.startTime);
    return Scaffold(
      appBar: AppBar(
        title: const Text('DÉTAIL'),
        actions: [
          IconButton(
            icon: const Icon(Icons.ios_share),
            tooltip: 'Partager',
            onPressed: () => _share(context),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          Text(
            dateLabel,
            style: const TextStyle(
              color: AppColors.subtleGrey,
              fontSize: 14,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Text(
                        run.distanceKm.toStringAsFixed(2),
                        style: const TextStyle(
                          fontSize: 56,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(width: 6),
                      const Text(
                        'km',
                        style: TextStyle(
                          fontSize: 22,
                          color: AppColors.subtleGrey,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _DetailStat(
                        label: 'DURÉE',
                        value: _fmtDuration(run.duration),
                      ),
                      _DetailStat(
                        label: 'ALLURE',
                        value: '${_fmtPace(avgPace.toDouble())} /km',
                      ),
                      _DetailStat(
                        label: 'KCAL',
                        value: run.caloriesBurned.toStringAsFixed(0),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: const [
                      Icon(Icons.bar_chart, color: AppColors.stravaOrange),
                      SizedBox(width: 8),
                      Text(
                        'ALLURE PAR KM',
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.2,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  if (run.splits.isEmpty)
                    const Text(
                      'Pas de splits enregistrés pour cette course.',
                      style: TextStyle(
                          color: AppColors.subtleGrey, fontSize: 13),
                    )
                  else
                    SizedBox(
                      height: 180,
                      child: _PaceChart(splits: run.splits),
                    ),
                ],
              ),
            ),
          ),
          if (run.note != null || run.difficulty != null) ...[
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: const [
                        Icon(Icons.mood, color: AppColors.stravaOrange),
                        SizedBox(width: 8),
                        Text(
                          'RESSENTI',
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.2,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                    if (run.difficulty != null) ...[
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          for (int i = 1; i <= 5; i++)
                            Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: Container(
                                width: 32,
                                height: 32,
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: i <= run.difficulty!
                                      ? AppColors.stravaOrange
                                      : Colors.white12,
                                ),
                                child: Text(
                                  '$i',
                                  style: TextStyle(
                                    color: i <= run.difficulty!
                                        ? Colors.white
                                        : AppColors.subtleGrey,
                                    fontWeight: FontWeight.w800,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ],
                    if (run.note != null) ...[
                      const SizedBox(height: 16),
                      Text(
                        run.note!,
                        style: const TextStyle(
                          color: Colors.white,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
          if (run.splits.isNotEmpty) ...[
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 4, vertical: 8),
                      child: Row(
                        children: const [
                          SizedBox(
                            width: 40,
                            child: Text(
                              'KM',
                              style: TextStyle(
                                color: AppColors.subtleGrey,
                                fontSize: 11,
                                letterSpacing: 1,
                              ),
                            ),
                          ),
                          Expanded(
                            child: Text(
                              'TEMPS',
                              style: TextStyle(
                                color: AppColors.subtleGrey,
                                fontSize: 11,
                                letterSpacing: 1,
                              ),
                            ),
                          ),
                          Text(
                            'ALLURE',
                            style: TextStyle(
                              color: AppColors.subtleGrey,
                              fontSize: 11,
                              letterSpacing: 1,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Divider(color: Colors.white12, height: 0),
                    for (final split in run.splits)
                      Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 4, vertical: 10),
                        child: Row(
                          children: [
                            SizedBox(
                              width: 40,
                              child: Text(
                                '${split.km}',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            Expanded(
                              child: Text(
                                _fmtDuration(split.duration),
                                style: const TextStyle(color: Colors.white),
                              ),
                            ),
                            Text(
                              '${_fmtPace(split.paceMinPerKm)} /km',
                              style: const TextStyle(
                                color: AppColors.stravaOrange,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _DetailStat extends StatelessWidget {
  final String label;
  final String value;
  const _DetailStat({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: AppColors.subtleGrey,
            letterSpacing: 1.2,
            fontSize: 10,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }
}

class _PaceChart extends StatelessWidget {
  final List<KmSplit> splits;
  const _PaceChart({required this.splits});

  @override
  Widget build(BuildContext context) {
    final paces = splits.map((s) => s.paceMinPerKm).toList();
    final maxPace = paces.reduce((a, b) => a > b ? a : b);
    final minPace = paces.reduce((a, b) => a < b ? a : b);
    final padding = (maxPace - minPace) * 0.2;
    final maxY = (maxPace + padding).clamp(0.0, double.infinity);
    final minY = (minPace - padding).clamp(0.0, double.infinity);

    return BarChart(
      BarChartData(
        alignment: BarChartAlignment.spaceBetween,
        maxY: maxY,
        minY: minY,
        barTouchData: BarTouchData(
          enabled: true,
          touchTooltipData: BarTouchTooltipData(
            getTooltipColor: (_) => AppColors.darkBackground,
            getTooltipItem: (group, _, rod, _) {
              final pace = rod.toY;
              final m = pace.floor();
              final s = ((pace - m) * 60).round();
              return BarTooltipItem(
                'km ${group.x + 1}\n$m:${s.toString().padLeft(2, '0')} /km',
                const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                ),
              );
            },
          ),
        ),
        titlesData: FlTitlesData(
          leftTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 22,
              interval: 1,
              getTitlesWidget: (value, _) {
                final i = value.toInt();
                if (i < 0 || i >= splits.length) {
                  return const SizedBox.shrink();
                }
                return Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    'k${splits[i].km}',
                    style: const TextStyle(
                      color: AppColors.subtleGrey,
                      fontSize: 10,
                    ),
                  ),
                );
              },
            ),
          ),
        ),
        gridData: const FlGridData(show: false),
        borderData: FlBorderData(show: false),
        barGroups: [
          for (int i = 0; i < splits.length; i++)
            BarChartGroupData(
              x: i,
              barRods: [
                BarChartRodData(
                  toY: splits[i].paceMinPerKm,
                  color: AppColors.stravaOrange,
                  width: 14,
                  borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(4)),
                  backDrawRodData: BackgroundBarChartRodData(
                    show: true,
                    toY: maxY,
                    color: Colors.white10,
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}
