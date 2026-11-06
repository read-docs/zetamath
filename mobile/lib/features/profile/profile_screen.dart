import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../store/difficulty.dart';
import '../../store/history.dart';
import '../../store/history_store.dart';
import '../../store/profile.dart';
import '../../store/settings.dart';
import '../../themes/themes.dart';
import '../common/widgets.dart';
import '../practice/practice_providers.dart';

const _months = ['jan', 'feb', 'mar', 'apr', 'may', 'jun', 'jul', 'aug', 'sep', 'oct', 'nov', 'dec'];

String dateLabel(String iso, {bool time = false}) {
  final d = DateTime.parse(iso).toLocal();
  final date = '${d.day} ${_months[d.month - 1]} ${d.year}';
  return time ? '$date ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}' : date;
}

String modeLabel(Result r) {
  if (r.mode == TestMode.zen) return 'zen${r.isDrill ? ' · drill' : ''}';
  final length = r.isCountRun ? '${r.count} problems' : '${r.duration}s';
  return '${r.mode == TestMode.custom ? 'custom ' : ''}$length${r.isDrill ? ' · drill' : ''}';
}

/// Level, streaks, personal bests, activity, pace history and past tests.
class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  var _shown = 10;

  @override
  Widget build(BuildContext context) {
    final results = ref.watch(historyProvider.select((h) => h.results));
    final s = ref.watch(settingsProvider);
    final z = context.zeta;
    final stats = summary(results);
    final streak = streaks(results);
    final xp = level(results);
    final series = profilePaceSeries(results);
    final difficulty = currentDifficulty(s.ranges);
    final name = s.name.trim().isEmpty ? 'guest' : s.name.trim();

    void open(Result r) {
      ref.read(practiceProvider).show(r);
      ref.read(tabProvider.notifier).go(AppTab.practice);
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      children: [
        Panel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 26,
                    backgroundColor: z.main.withValues(alpha: .2),
                    child: Text(name[0].toUpperCase(), style: TextStyle(color: z.main, fontSize: 22)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(name, style: TextStyle(color: z.text, fontSize: 20)),
                        Text(
                          stats.joined != null ? 'joined ${dateLabel(stats.joined!)}' : 'no tests yet',
                          style: TextStyle(color: z.sub, fontSize: 13),
                        ),
                        Text(
                          '${streak.current} day streak${streak.longest > streak.current ? ' · best ${streak.longest}' : ''}',
                          style: TextStyle(color: z.sub, fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Semantics(
                label: 'level ${xp.level}, ${xp.into} of ${xp.needed} xp',
                excludeSemantics: true,
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(color: z.main, borderRadius: BorderRadius.circular(6)),
                      child: Text('${xp.level}', style: TextStyle(color: z.bg)),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(3),
                        child: LinearProgressIndicator(
                          value: xp.into / xp.needed,
                          minHeight: 6,
                          color: z.main,
                          backgroundColor: z.sub.withValues(alpha: .2),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text('${xp.into}/${xp.needed}', style: TextStyle(color: z.sub, fontSize: 12)),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _Bests(unit: 'seconds', targets: timeOptions, bests: bestsFor(results, TestMode.time, timeOptions, s.ranges)),
        const SizedBox(height: 8),
        _Bests(
          unit: 'problems',
          targets: countOptions,
          bests: bestsFor(results, TestMode.count, countOptions, s.ranges),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Text(
            'personal bests in problems per minute at ${difficulty == 'custom' ? 'your custom ranges' : '$difficulty difficulty'} · long press for details',
            style: TextStyle(color: z.sub, fontSize: 12),
          ),
        ),
        _Heatmap(results: results),
        if (series.length > 1) ...[const SizedBox(height: 12), _HistoryChart(series: series)],
        const SizedBox(height: 12),
        Panel(
          child: Wrap(
            runSpacing: 12,
            children: [
              for (final (label, value) in [
                ('tests completed', '${stats.tests}'),
                ('time practicing', formatDuration(stats.timeMs)),
                ('problems solved', '${stats.solved}'),
                ('total xp', '${xp.xp}'),
                ('highest pace', '${stats.highestPace.round()} ppm'),
                ('average pace', '${stats.averagePace.round()} ppm'),
                ('last 10 average', '${stats.last10Pace.round()} ppm'),
                ('average variation', '${stats.averageVariation.toStringAsFixed(1)}%'),
                ('current streak', '${streak.current}d'),
                ('longest streak', '${streak.longest}d'),
              ])
                FractionallySizedBox(
                  widthFactor: .5,
                  child: StatTile(label: label, value: value),
                ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        if (results.isEmpty)
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              'Your first session is the start of a habit. Completed tests will appear here.',
              textAlign: TextAlign.center,
              style: TextStyle(color: z.sub),
            ),
          )
        else ...[
          Panel(
            title: 'past tests',
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Column(
              children: [
                for (final r in results.take(_shown))
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                    onTap: () => open(r),
                    title: Text(
                      '${r.pace.round()} ppm · ${r.logs.length} solved · ${variation(r).toStringAsFixed(1)}%',
                      style: TextStyle(color: z.text),
                    ),
                    subtitle: Text(
                      '${modeLabel(r)} · ${currentDifficulty(r.ranges)} · ${dateLabel(r.date, time: true)}',
                      style: TextStyle(color: z.sub),
                    ),
                    trailing: Icon(Icons.chevron_right, color: z.sub),
                  ),
              ],
            ),
          ),
          if (_shown < results.length)
            TextButton(onPressed: () => setState(() => _shown += 10), child: const Text('load more')),
        ],
      ],
    );
  }
}

class _Bests extends StatelessWidget {
  const _Bests({required this.unit, required this.targets, required this.bests});
  final String unit;
  final List<int> targets;
  final Map<int, Result> bests;

  @override
  Widget build(BuildContext context) {
    final z = context.zeta;
    return Row(
      children: [
        for (final (i, t) in targets.indexed) ...[
          if (i > 0) const SizedBox(width: 6),
          Expanded(
            child: Builder(
              builder: (context) {
                final r = bests[t];
                final detail = r == null
                    ? 'no personal best yet'
                    : '${r.pace.round()} ppm · ${r.logs.length} solved · ${(r.elapsedMs / 1000).toStringAsFixed(2)}s · ${variation(r).toStringAsFixed(1)}% var · ${dateLabel(r.date)}';
                return Tooltip(
                  message: detail,
                  triggerMode: TooltipTriggerMode.longPress,
                  child: Semantics(
                    label: '$t $unit personal best: $detail',
                    excludeSemantics: true,
                    child: Panel(
                      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
                      child: Column(
                        children: [
                          Text(
                            '$t $unit',
                            style: TextStyle(color: z.sub, fontSize: 11),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(r == null ? '-' : '${r.pace.round()}', style: TextStyle(color: z.main, fontSize: 24)),
                          Text(
                            r == null
                                ? '-'
                                : r.isCountRun
                                ? '${(r.elapsedMs / 1000).toStringAsFixed(1)}s'
                                : '${r.logs.length} solved',
                            style: TextStyle(color: z.sub, fontSize: 11),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ],
    );
  }
}

/// A year of daily activity, newest week on the right, scrolled to today.
class _Heatmap extends StatelessWidget {
  const _Heatmap({required this.results});
  final List<Result> results;

  @override
  Widget build(BuildContext context) {
    final z = context.zeta;
    final days = activityByDay(results);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final start = DateTime(today.year, today.month, today.day - today.weekday % 7 - 52 * 7);
    final weeks = <List<(DateTime, int)>>[];
    var total = 0, max = 0;
    for (var d = start; !d.isAfter(today); d = DateTime(d.year, d.month, d.day + 1)) {
      if (d.weekday % 7 == 0) weeks.add([]);
      final n = days[dayKey(d)] ?? 0;
      weeks.last.add((d, n));
      total += n;
      if (n > max) max = n;
    }
    Color shade(int n) => n == 0
        ? z.sub.withValues(alpha: .12)
        : z.main.withValues(alpha: .25 + .75 * (n / max * 4).ceil().clamp(1, 4) / 4);
    const cell = 11.0, gap = 3.0;

    return Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 12,
            alignment: WrapAlignment.spaceBetween,
            runAlignment: WrapAlignment.start,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text('test activity', style: TextStyle(color: z.sub)),
              Text(
                '$total ${total == 1 ? 'test' : 'tests'} in the last year',
                style: TextStyle(color: z.sub, fontSize: 12),
              ),
            ],
          ),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            reverse: true,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final w in weeks)
                  Padding(
                    padding: const EdgeInsets.only(right: gap),
                    child: Column(
                      children: [
                        SizedBox(
                          height: 14,
                          width: cell,
                          child: OverflowBox(
                            maxWidth: 40,
                            alignment: Alignment.centerLeft,
                            child: Text(
                              w.where((d) => d.$1.day == 1).map((d) => _months[d.$1.month - 1]).firstOrNull ?? '',
                              style: TextStyle(color: z.sub, fontSize: 9),
                            ),
                          ),
                        ),
                        for (final (_, n) in w)
                          Container(
                            width: cell,
                            height: cell,
                            margin: const EdgeInsets.only(bottom: gap),
                            decoration: BoxDecoration(color: shade(n), borderRadius: BorderRadius.circular(2)),
                          ),
                      ],
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

class _HistoryChart extends StatelessWidget {
  const _HistoryChart({required this.series});
  final List<HistoryPoint> series;

  @override
  Widget build(BuildContext context) {
    final z = context.zeta;
    final axis = TextStyle(color: z.sub, fontSize: 10);
    LineChartBarData line(double Function(HistoryPoint) y, Color color, {bool dots = false}) => LineChartBarData(
      spots: [for (final p in series) FlSpot(p.test.toDouble(), y(p))],
      isCurved: !dots,
      preventCurveOverShooting: true,
      color: dots ? Colors.transparent : color,
      barWidth: dots ? 0 : 2,
      dotData: FlDotData(
        show: dots,
        getDotPainter: (_, _, _, _) =>
            FlDotCirclePainter(radius: 3, color: color.withValues(alpha: .6), strokeWidth: 0),
      ),
    );
    Widget key(String label, Color color) => Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 10, height: 3, color: color),
        const SizedBox(width: 4),
        Text(label, style: TextStyle(color: z.sub, fontSize: 11)),
      ],
    );

    return Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('history', style: TextStyle(color: z.sub)),
          Wrap(
            spacing: 12,
            children: [
              key('ppm', z.main.withValues(alpha: .6)),
              key('last 10 avg', z.main),
              key('last 100 avg', z.sub),
            ],
          ),
          const SizedBox(height: 8),
          Semantics(
            label: 'Pace history over ${series.length} tests',
            child: SizedBox(
              height: 220,
              child: LineChart(
                LineChartData(
                  minY: 0,
                  gridData: FlGridData(
                    drawVerticalLine: false,
                    getDrawingHorizontalLine: (_) => FlLine(color: z.sub.withValues(alpha: .12), strokeWidth: 1),
                  ),
                  borderData: FlBorderData(show: false),
                  lineTouchData: const LineTouchData(enabled: false),
                  titlesData: FlTitlesData(
                    topTitles: const AxisTitles(),
                    rightTitles: const AxisTitles(),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 32,
                        getTitlesWidget: (v, meta) => SideTitleWidget(
                          meta: meta,
                          child: Text(meta.formattedValue, style: axis),
                        ),
                      ),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 22,
                        getTitlesWidget: (v, meta) => SideTitleWidget(
                          meta: meta,
                          child: Text(meta.formattedValue, style: axis),
                        ),
                      ),
                    ),
                  ),
                  lineBarsData: [
                    line((p) => p.ppm.toDouble(), z.main, dots: true),
                    line((p) => p.average10.toDouble(), z.main),
                    line((p) => p.average100.toDouble(), z.sub),
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
