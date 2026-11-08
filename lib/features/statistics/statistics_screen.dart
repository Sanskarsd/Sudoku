import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../data/database/local_database.dart';
import '../../data/repositories/sudoku_repository.dart';

class StatisticsScreen extends StatefulWidget {
  const StatisticsScreen({super.key});
  @override
  State<StatisticsScreen> createState() => _StatisticsScreenState();
}

class _StatisticsScreenState extends State<StatisticsScreen> {
  late Future<
      (
        Map<String, Object?>,
        List<Map<String, Object?>>,
        List<Map<String, Object?>>,
        List<Map<String, Object?>>
      )> data;
  @override
  void initState() {
    super.initState();
    data = _load();
  }

  Future<
      (
        Map<String, Object?>,
        List<Map<String, Object?>>,
        List<Map<String, Object?>>,
        List<Map<String, Object?>>
      )> _load() async {
    final repo = SudokuRepository(LocalDatabase.instance);
    return (
      await repo.statistics(),
      await repo.completionBreakdown(groupBy: 'difficulty'),
      await repo.completionBreakdown(groupBy: 'mode'),
      await repo.completionBreakdown()
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Statistics')),
        body: FutureBuilder<
            (
              Map<String, Object?>,
              List<Map<String, Object?>>,
              List<Map<String, Object?>>,
              List<Map<String, Object?>>
            )>(
          future: data,
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return Center(
                  child: Text(
                      'Statistics could not be loaded: ${snapshot.error}'));
            }
            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            final (stats, byDifficulty, byMode, history) = snapshot.data!;
            final started = stats['games_started']! as int;
            final won = stats['games_won']! as int;
            final totalSeconds = stats['total_seconds']! as int;
            final average = won == 0 ? 0 : totalSeconds ~/ won;
            return ListView(padding: const EdgeInsets.all(16), children: [
              Wrap(spacing: 10, runSpacing: 10, children: [
                _Metric('Started', '$started'),
                _Metric('Completed',
                    '$won (${started == 0 ? 0 : (won * 100 ~/ started)}%)'),
                _Metric('Best time', _duration(stats['best_seconds'] as int?)),
                _Metric('Average', _duration(average)),
                _Metric('Current streak', '${stats['current_streak']}'),
                _Metric('Longest streak', '${stats['longest_streak']}'),
                _Metric('Hints', '${stats['hints_used']}'),
                _Metric('Mistakes', '${stats['mistakes_made']}'),
              ]),
              const SizedBox(height: 20),
              Text('Completed by difficulty',
                  style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 12),
              SizedBox(
                  height: 220,
                  child: _CategoryChart(
                      rows: byDifficulty,
                      labels: const ['Easy', 'Medium', 'Hard', 'Expert'])),
              const SizedBox(height: 20),
              Text('Completed by board size',
                  style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 12),
              SizedBox(
                  height: 220,
                  child: _CategoryChart(
                      rows: byMode,
                      labels: const ['Mini', 'Compact', 'Classic'])),
              const SizedBox(height: 20),
              Text('Recent completions',
                  style: Theme.of(context).textTheme.titleMedium),
              if (history.isEmpty)
                const ListTile(title: Text('No completed games yet')),
              ...history.take(10).map((row) => ListTile(
                    leading: const Icon(Icons.check_circle_outline),
                    title: Text(
                        '${_mode(row['mode']! as int)} · ${_difficulty(row['difficulty']! as int)}'),
                    subtitle: Text(
                        DateTime.parse(row['completed_at']! as String)
                            .toLocal()
                            .toString()
                            .substring(0, 16)),
                    trailing: Text(_duration(row['seconds']! as int)),
                  )),
            ]);
          },
        ),
      );

  static String _duration(int? seconds) => seconds == null
      ? '—'
      : '${seconds ~/ 60}:${(seconds % 60).toString().padLeft(2, '0')}';
  static String _mode(int mode) => ['Mini', 'Compact', 'Classic'][mode];
  static String _difficulty(int difficulty) =>
      ['Easy', 'Medium', 'Hard', 'Expert'][difficulty];
}

class _Metric extends StatelessWidget {
  const _Metric(this.label, this.value);
  final String label, value;
  @override
  Widget build(BuildContext context) => SizedBox(
        width: 150,
        child: Card(
            child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(label,
                          style: Theme.of(context).textTheme.labelMedium),
                      const SizedBox(height: 5),
                      Text(value, style: Theme.of(context).textTheme.titleLarge)
                    ]))),
      );
}

class _CategoryChart extends StatelessWidget {
  const _CategoryChart({required this.rows, required this.labels});
  final List<Map<String, Object?>> rows;
  final List<String> labels;
  @override
  Widget build(BuildContext context) {
    if (rows.isEmpty) {
      return const Center(child: Text('Complete a game to see your progress.'));
    }
    final counts = List<double>.filled(labels.length, 0);
    for (final row in rows) {
      final difficulty = row['category']! as int;
      counts[difficulty] = (row['games']! as int).toDouble();
    }
    return BarChart(BarChartData(
      maxY: (counts.reduce((a, b) => a > b ? a : b) + 1).ceilToDouble(),
      barGroups: [
        for (var i = 0; i < counts.length; i++)
          BarChartGroupData(x: i, barRods: [
            BarChartRodData(
                toY: counts[i],
                color: Theme.of(context).colorScheme.primary,
                width: 28,
                borderRadius: BorderRadius.circular(5))
          ])
      ],
      titlesData: FlTitlesData(
        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        rightTitles:
            const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        bottomTitles: AxisTitles(
            sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (value, _) => Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(labels[value.toInt()])))),
      ),
      borderData: FlBorderData(show: false),
      gridData: const FlGridData(show: false),
    ));
  }
}
