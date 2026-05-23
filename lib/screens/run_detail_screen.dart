import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/run.dart';
import '../services/firestore_service.dart';
import '../services/run_share_service.dart';
import '../services/units_service.dart';
import '../theme.dart';
import '../widgets/run_route_map.dart';

class RunDetailScreen extends StatefulWidget {
  final Run run;
  final String username;
  const RunDetailScreen({
    super.key,
    required this.run,
    required this.username,
  });

  @override
  State<RunDetailScreen> createState() => _RunDetailScreenState();
}

class _RunDetailScreenState extends State<RunDetailScreen> {
  List<PbBeat> _beats = const [];

  @override
  void initState() {
    super.initState();
    _detectPbs();
  }

  Future<void> _detectPbs() async {
    try {
      final beats = await FirestoreService().detectPbBeats(widget.run.id);
      if (!mounted) return;
      setState(() => _beats = beats);
    } catch (_) {
      // Silent — celebration is best-effort.
    }
  }

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
        run: widget.run,
        username: widget.username,
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
    final run = widget.run;
    final units = UnitsService.instance;
    final avgPace = units.paceMinPerUnit(run.averageSpeedKmh);
    final dateLabel =
        DateFormat('EEEE d MMMM yyyy, HH:mm', 'fr_FR').format(run.startTime);
    final appBarTitle = run.title != null && run.title!.isNotEmpty
        ? run.title!
        : 'DÉTAIL';
    return Scaffold(
      appBar: AppBar(
        title: Text(appBarTitle),
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
          if (_beats.isNotEmpty) ...[
            _PbBanner(beats: _beats),
            const SizedBox(height: 16),
          ],
          ..._buildBody(context, units, avgPace, dateLabel),
        ],
      ),
    );
  }

  List<Widget> _buildBody(
      BuildContext context, UnitsService units, double avgPace, String dateLabel) {
    final run = widget.run;
    return [
          Text(
            dateLabel,
            style: const TextStyle(
              color: AppColors.subtleGrey,
              fontSize: 14,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 16),
          if (run.points.length >= 2) ...[
            Card(
              clipBehavior: Clip.antiAlias,
              child: SizedBox(
                height: 220,
                child: RepaintBoundary(
                  child: RunRouteMap(points: run.points),
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],
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
                        units.distance(run.distanceKm).toStringAsFixed(2),
                        style: const TextStyle(
                          fontSize: 56,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        units.distanceUnit(),
                        style: const TextStyle(
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
                        value: '${_fmtPace(avgPace)} /${units.distanceUnit()}',
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
                      child: RepaintBoundary(
                        child: _PaceChart(splits: run.splits),
                      ),
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
                              padding: const EdgeInsets.only(right: 4),
                              child: Icon(
                                i <= run.difficulty!
                                    ? Icons.star_rounded
                                    : Icons.star_outline_rounded,
                                size: 28,
                                color: i <= run.difficulty!
                                    ? AppColors.stravaOrange
                                    : AppColors.subtleGrey,
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
    ];
  }
}

class _PbBanner extends StatelessWidget {
  final List<PbBeat> beats;
  const _PbBanner({required this.beats});

  String _label(PbBeat b) {
    final units = UnitsService.instance;
    switch (b.kind) {
      case PbKind.distance:
        return 'Distance — ${units.distance(b.current).toStringAsFixed(2)} '
            '${units.distanceUnit()} '
            '(+${units.distance(b.delta).toStringAsFixed(2)} ${units.distanceUnit()})';
      case PbKind.speed:
        return 'Vitesse — ${units.speed(b.current).toStringAsFixed(1)} '
            '${units.speedUnit()} '
            '(+${units.speed(b.delta).toStringAsFixed(1)} ${units.speedUnit()})';
      case PbKind.calories:
        return 'Calories — ${b.current.toStringAsFixed(0)} kcal '
            '(+${b.delta.toStringAsFixed(0)} kcal)';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      color: AppColors.stravaOrange.withValues(alpha: 0.12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: const [
                Icon(Icons.emoji_events,
                    color: AppColors.stravaOrange, size: 22),
                SizedBox(width: 8),
                Text(
                  'NOUVEAU RECORD !',
                  style: TextStyle(
                    color: AppColors.stravaOrange,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.2,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            for (final b in beats)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  _label(b),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                  ),
                ),
              ),
          ],
        ),
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
