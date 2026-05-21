import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/run.dart';
import '../models/user_profile.dart';
import '../services/run_share_service.dart';
import '../services/storage_service.dart';
import '../theme.dart';
import '../widgets/empty_state.dart';
import 'home_shell.dart';
import 'run_detail_screen.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  final _storage = StorageService();
  final _shareService = RunShareService();
  List<Run> _runs = [];
  UserProfile _profile = UserProfile.empty;
  Map<DateTime, double> _last14 = const {};
  Map<DateTime, List<Run>> _runsByDay = const {};
  bool _loading = true;
  bool _calendarMode = false;

  @override
  void initState() {
    super.initState();
    _load();
    StorageService.runsChanged.addListener(_load);
  }

  @override
  void dispose() {
    StorageService.runsChanged.removeListener(_load);
    super.dispose();
  }

  Future<void> _load() async {
    final r = await _storage.loadRuns();
    final last14 = await _storage.last14DaysKm();
    final profile = await _storage.loadProfile();
    final byDay = <DateTime, List<Run>>{};
    for (final run in r) {
      final d = DateTime(
          run.startTime.year, run.startTime.month, run.startTime.day);
      byDay.putIfAbsent(d, () => []).add(run);
    }
    if (!mounted) return;
    setState(() {
      _runs = r;
      _profile = profile ?? UserProfile.empty;
      _last14 = last14;
      _runsByDay = byDay;
      _loading = false;
    });
  }

  Future<void> _share(Run run) async {
    try {
      await _shareService.shareRun(
        run: run,
        username: _profile.username,
        context: context,
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Erreur lors du partage')),
      );
    }
  }

  String _fmtDuration(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes % 60;
    final s = d.inSeconds % 60;
    if (h > 0) return '${h}h ${m}m';
    if (m > 0) return '${m}m ${s}s';
    return '${s}s';
  }

  void _openRun(Run run) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => RunDetailScreen(
          run: run,
          username: _profile.username,
        ),
      ),
    );
  }

  Future<void> _onCalendarDayTap(DateTime day) async {
    final runs = _runsByDay[day];
    if (runs == null || runs.isEmpty) return;
    if (runs.length == 1) {
      _openRun(runs.first);
      return;
    }
    final picked = await showModalBottomSheet<Run>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: Text(
                DateFormat('EEEE d MMM', 'fr_FR').format(day).toUpperCase(),
                style: const TextStyle(
                  color: AppColors.subtleGrey,
                  letterSpacing: 1.2,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            for (final r in runs)
              ListTile(
                leading: const Icon(Icons.directions_run,
                    color: AppColors.stravaOrange),
                title: Text(DateFormat('HH:mm').format(r.startTime)),
                subtitle: Text(
                  '${r.distanceKm.toStringAsFixed(2)} km · ${_fmtDuration(r.duration)}',
                  style: const TextStyle(
                      color: AppColors.subtleGrey, fontSize: 12),
                ),
                onTap: () => Navigator.pop(ctx, r),
              ),
          ],
        ),
      ),
    );
    if (picked != null) _openRun(picked);
  }

  @override
  Widget build(BuildContext context) {
    final bottomPad = MediaQuery.of(context).padding.bottom +
        kBottomNavigationBarHeight +
        16;
    return Scaffold(
      appBar: AppBar(title: const Text('HISTORIQUE')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _runs.isEmpty
              ? Padding(
                  padding: EdgeInsets.only(bottom: bottomPad),
                  child: EmptyState(
                    icon: Icons.directions_run,
                    title: 'Aucune course pour l\'instant',
                    subtitle:
                        'Vos courses apparaîtront ici une fois enregistrées.',
                    actionLabel: 'COMMENCER UNE COURSE',
                    onAction: () => HomeShell.controller.value = 0,
                  ),
                )
              : Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                      child: Center(
                        child: SegmentedButton<bool>(
                          style: SegmentedButton.styleFrom(
                            selectedBackgroundColor: AppColors.stravaOrange,
                            selectedForegroundColor: Colors.white,
                            foregroundColor: AppColors.subtleGrey,
                            side: const BorderSide(color: Colors.white24),
                          ),
                          segments: const [
                            ButtonSegment(value: false, label: Text('LISTE')),
                            ButtonSegment(
                                value: true, label: Text('CALENDRIER')),
                          ],
                          selected: {_calendarMode},
                          onSelectionChanged: (s) =>
                              setState(() => _calendarMode = s.first),
                        ),
                      ),
                    ),
                    Expanded(
                      child: _calendarMode
                          ? Padding(
                              padding: EdgeInsets.fromLTRB(
                                  16, 8, 16, bottomPad),
                              child: SingleChildScrollView(
                                child: RepaintBoundary(
                                  child: _RunCalendar(
                                    runsByDay: _runsByDay,
                                    onDayTap: _onCalendarDayTap,
                                  ),
                                ),
                              ),
                            )
                          : RefreshIndicator(
                              onRefresh: _load,
                              child: ListView.builder(
                                padding: EdgeInsets.fromLTRB(
                                    16, 8, 16, bottomPad),
                                itemCount: _runs.length + 1,
                                cacheExtent: 800,
                                itemBuilder: (_, i) {
                                  if (i == 0) {
                                    return Padding(
                                      padding:
                                          const EdgeInsets.only(bottom: 16),
                                      child: RepaintBoundary(
                                        child: _Last14DaysChart(data: _last14),
                                      ),
                                    );
                                  }
                                  final r = _runs[i - 1];
                                  return Padding(
                                    padding: const EdgeInsets.only(bottom: 12),
                                    child: Card(
                                      color: const Color(0xFF181820),
                                      clipBehavior: Clip.antiAlias,
                                      child: InkWell(
                                        onTap: () => _openRun(r),
                                        child: Padding(
                                          padding: const EdgeInsets.all(16),
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Row(
                                                children: [
                                                  const Icon(
                                                      Icons.directions_run,
                                                      color: AppColors
                                                          .stravaOrange),
                                                  const SizedBox(width: 8),
                                                  Expanded(
                                                    child: Text(
                                                      DateFormat(
                                                              'EEEE d MMM, HH:mm',
                                                              'fr_FR')
                                                          .format(r.startTime),
                                                      style: const TextStyle(
                                                        fontWeight:
                                                            FontWeight.w600,
                                                      ),
                                                    ),
                                                  ),
                                                  IconButton(
                                                    icon: const Icon(
                                                        Icons.ios_share,
                                                        size: 20,
                                                        color: AppColors
                                                            .subtleGrey),
                                                    tooltip: 'Partager',
                                                    onPressed: () => _share(r),
                                                  ),
                                                ],
                                              ),
                                              const Divider(height: 24),
                                              Row(
                                                mainAxisAlignment:
                                                    MainAxisAlignment
                                                        .spaceBetween,
                                                children: [
                                                  _Stat(
                                                    label: 'Distance',
                                                    value:
                                                        '${r.distanceKm.toStringAsFixed(2)} km',
                                                  ),
                                                  _Stat(
                                                    label: 'Durée',
                                                    value: _fmtDuration(
                                                        r.duration),
                                                  ),
                                                  _Stat(
                                                    label: 'Vitesse',
                                                    value:
                                                        '${r.averageSpeedKmh.toStringAsFixed(1)} km/h',
                                                  ),
                                                  _Stat(
                                                    label: 'Kcal',
                                                    value: r.caloriesBurned
                                                        .toStringAsFixed(0),
                                                  ),
                                                ],
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                    ),
                  ],
                ),
    );
  }
}

class _RunCalendar extends StatefulWidget {
  final Map<DateTime, List<Run>> runsByDay;
  final ValueChanged<DateTime> onDayTap;
  const _RunCalendar({required this.runsByDay, required this.onDayTap});

  @override
  State<_RunCalendar> createState() => _RunCalendarState();
}

class _RunCalendarState extends State<_RunCalendar> {
  late DateTime _visibleMonth;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _visibleMonth = DateTime(now.year, now.month);
  }

  void _shiftMonth(int delta) {
    setState(() {
      _visibleMonth =
          DateTime(_visibleMonth.year, _visibleMonth.month + delta);
    });
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    final firstOfMonth = _visibleMonth;
    // Monday-first: weekday 1=Mon, 7=Sun
    final leadingBlanks = (firstOfMonth.weekday - 1) % 7;
    final daysInMonth =
        DateTime(firstOfMonth.year, firstOfMonth.month + 1, 0).day;

    const weekdayLabels = ['L', 'M', 'M', 'J', 'V', 'S', 'D'];

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.chevron_left),
                  onPressed: () => _shiftMonth(-1),
                ),
                Expanded(
                  child: Center(
                    child: Text(
                      DateFormat('MMMM yyyy', 'fr_FR')
                          .format(_visibleMonth)
                          .toUpperCase(),
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.2,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.chevron_right),
                  onPressed: () => _shiftMonth(1),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                for (final l in weekdayLabels)
                  Expanded(
                    child: Center(
                      child: Text(
                        l,
                        style: const TextStyle(
                          color: AppColors.subtleGrey,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 4),
            GridView.count(
              crossAxisCount: 7,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              childAspectRatio: 1.05,
              children: [
                for (int i = 0; i < leadingBlanks; i++) const SizedBox(),
                for (int d = 1; d <= daysInMonth; d++)
                  _CalendarDay(
                    day: DateTime(firstOfMonth.year, firstOfMonth.month, d),
                    isToday:
                        DateTime(firstOfMonth.year, firstOfMonth.month, d) ==
                            today,
                    hasRun: widget.runsByDay.containsKey(
                        DateTime(firstOfMonth.year, firstOfMonth.month, d)),
                    onTap: widget.onDayTap,
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _CalendarDay extends StatelessWidget {
  final DateTime day;
  final bool isToday;
  final bool hasRun;
  final ValueChanged<DateTime> onTap;
  const _CalendarDay({
    required this.day,
    required this.isToday,
    required this.hasRun,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkResponse(
      onTap: hasRun ? () => onTap(day) : null,
      radius: 22,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 32,
            height: 32,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: isToday
                  ? Border.all(color: AppColors.stravaOrange, width: 1.5)
                  : null,
            ),
            child: Text(
              '${day.day}',
              style: TextStyle(
                color: hasRun ? Colors.white : AppColors.subtleGrey,
                fontWeight: hasRun ? FontWeight.w800 : FontWeight.w500,
                fontSize: 13,
              ),
            ),
          ),
          const SizedBox(height: 2),
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: hasRun ? AppColors.stravaOrange : Colors.transparent,
            ),
          ),
        ],
      ),
    );
  }
}

class _Last14DaysChart extends StatelessWidget {
  final Map<DateTime, double> data;
  const _Last14DaysChart({required this.data});

  @override
  Widget build(BuildContext context) {
    final days = data.keys.toList()..sort();
    final maxValue = data.values.isEmpty
        ? 1.0
        : data.values.reduce((a, b) => a > b ? a : b);
    final maxY = maxValue <= 0 ? 1.0 : (maxValue * 1.2);

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: const [
                Icon(Icons.bar_chart, color: AppColors.stravaOrange),
                SizedBox(width: 8),
                Text(
                  '14 DERNIERS JOURS',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.2,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 140,
              child: BarChart(
                BarChartData(
                  alignment: BarChartAlignment.spaceBetween,
                  maxY: maxY,
                  minY: 0,
                  barTouchData: BarTouchData(
                    enabled: true,
                    touchTooltipData: BarTouchTooltipData(
                      getTooltipColor: (_) => AppColors.darkBackground,
                      getTooltipItem: (group, _, rod, _) {
                        final day = days[group.x];
                        final label =
                            DateFormat('d MMM', 'fr_FR').format(day);
                        return BarTooltipItem(
                          '$label\n${rod.toY.toStringAsFixed(2)} km',
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
                    leftTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false)),
                    rightTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false)),
                    topTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false)),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 22,
                        interval: 1,
                        getTitlesWidget: (value, _) {
                          final i = value.toInt();
                          if (i < 0 || i >= days.length) {
                            return const SizedBox.shrink();
                          }
                          if (i % 3 != 0 && i != days.length - 1) {
                            return const SizedBox.shrink();
                          }
                          return Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(
                              DateFormat('d/M').format(days[i]),
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
                    for (int i = 0; i < days.length; i++)
                      BarChartGroupData(
                        x: i,
                        barRods: [
                          BarChartRodData(
                            toY: data[days[i]] ?? 0,
                            color: AppColors.stravaOrange,
                            width: 10,
                            borderRadius: const BorderRadius.vertical(
                                top: Radius.circular(3)),
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
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  final String label;
  final String value;
  const _Stat({required this.label, required this.value});
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: const TextStyle(
            color: AppColors.subtleGrey,
            fontSize: 10,
            letterSpacing: 1,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}
