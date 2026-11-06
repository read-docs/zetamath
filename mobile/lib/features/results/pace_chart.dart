import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../engine/scoring.dart';
import '../../themes/themes.dart';

/// Problems per minute over the test, with slow seconds marked in the error colour.
class PaceChart extends StatelessWidget {
  const PaceChart({super.key, required this.points});
  final List<PacePoint> points;

  @override
  Widget build(BuildContext context) {
    final z = context.zeta;
    final axis = TextStyle(color: z.sub, fontSize: 10);
    return Semantics(
      label: 'Pace over time',
      child: SizedBox(
        height: 200,
        child: LineChart(
          LineChartData(
            minY: 0,
            gridData: FlGridData(
              drawVerticalLine: false,
              getDrawingHorizontalLine: (_) => FlLine(color: z.sub.withValues(alpha: .15), strokeWidth: 1),
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
                    child: Text('${meta.formattedValue}s', style: axis),
                  ),
                ),
              ),
            ),
            lineBarsData: [
              LineChartBarData(
                spots: [for (final p in points) FlSpot(p.second, p.ppm)],
                isCurved: true,
                preventCurveOverShooting: true,
                color: z.main,
                barWidth: 2,
                dotData: FlDotData(
                  checkToShowDot: (spot, _) => points.any((p) => p.second == spot.x && p.slow),
                  getDotPainter: (_, _, _, _) => FlDotCirclePainter(radius: 4, color: z.error, strokeWidth: 0),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
