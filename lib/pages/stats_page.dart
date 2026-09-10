import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/db.dart';
import '../widgets/glass.dart';

class StatsPage extends ConsumerWidget {
  const StatsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('统计'),
          bottom: const TabBar(
            tabs: [Tab(text: '近7天'), Tab(text: '近30天')],
            indicatorSize: TabBarIndicatorSize.tab,
          ),
        ),
        body: TabBarView(
          children: [
            _Stats(days: 7),
            _Stats(days: 30),
          ],
        ),
      ),
    );
  }
}

class _Stats extends StatefulWidget {
  final int days;
  const _Stats({required this.days});

  @override
  State<_Stats> createState() => _StatsState();
}

class _StatsState extends State<_Stats> {
  late Future<Map<String, dynamic>> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<Map<String, dynamic>> _load() async {
    final days = await AppDb.instance.statsForDays(widget.days);
    final rank = await AppDb.instance.bookRanking();
    final totals = await AppDb.instance.totals();
    return {'days': days, 'rank': rank, 'totals': totals};
  }

  String fmt(int seconds) {
    if (seconds < 60) return '${seconds}秒';
    if (seconds < 3600) return '${(seconds / 60).floor()}分钟';
    return '${(seconds / 3600).toStringAsFixed(1)}小时';
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return FutureBuilder<Map<String, dynamic>>(
      future: _future,
      builder: (context, snap) {
        if (!snap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final days = snap.data!['days'] as List<Map<String, dynamic>>;
        final rank = snap.data!['rank'] as List<Map<String, dynamic>>;
        final totals = snap.data!['totals'] as Map<String, dynamic>;
        final weekTotal =
            days.fold<int>(0, (a, e) => a + (e['s'] as int? ?? 0));
        final maxS = days.fold<int>(1, (a, e) => (e['s'] as int? ?? 0) > a ? e['s'] as int : a);

        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
          children: [
            GlassContainer(
              borderRadius: BorderRadius.circular(24),
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('本期阅读',
                      style: TextStyle(
                          fontSize: 13, color: scheme.onSurface.withOpacity(0.5))),
                  const SizedBox(height: 6),
                  Text(fmt(weekTotal),
                      style: TextStyle(
                          fontSize: 34,
                          fontWeight: FontWeight.w700,
                          color: scheme.primary)),
                  const SizedBox(height: 20),
                  SizedBox(
                    height: 120,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: days.map((d) {
                        final s = d['s'] as int? ?? 0;
                        final h = (s / maxS * 90).clamp(4.0, 90.0);
                        return Expanded(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              Container(
                                height: h,
                                margin: const EdgeInsets.symmetric(horizontal: 3),
                                decoration: BoxDecoration(
                                  color: scheme.primary.withOpacity(0.7),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                (d['day'] as String).substring(8),
                                style: TextStyle(
                                    fontSize: 10,
                                    color: scheme.onSurface.withOpacity(0.4)),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Text('书籍排行',
                style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: scheme.onSurface.withOpacity(0.8))),
            const SizedBox(height: 8),
            if (rank.isEmpty)
              Padding(
                padding: const EdgeInsets.all(24),
                child: Center(
                    child: Text('还没有阅读记录',
                        style: TextStyle(color: scheme.outline))),
              )
            else
              GlassContainer(
                borderRadius: BorderRadius.circular(24),
                padding: const EdgeInsets.symmetric(
                    horizontal: 20, vertical: 8),
                child: Column(
                  children: rank.map((r) {
                    final s = r['s'] as int? ?? 0;
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      dense: true,
                      title: Text(r['name'] as String,
                          maxLines: 1, overflow: TextOverflow.ellipsis),
                      trailing: Text(fmt(s),
                          style: TextStyle(
                              fontSize: 13, color: scheme.primary)),
                    );
                  }).toList(),
                ),
              ),
            const SizedBox(height: 20),
            GlassContainer(
              borderRadius: BorderRadius.circular(24),
              padding: const EdgeInsets.all(20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _StatItem(
                      label: '总时长', value: fmt(totals['totalSeconds'] as int)),
                  _StatItem(
                      label: '阅读天数', value: '${totals['activeDays']} 天'),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

class _StatItem extends StatelessWidget {
  final String label;
  final String value;
  const _StatItem({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      children: [
        Text(value,
            style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: scheme.onSurface)),
        const SizedBox(height: 4),
        Text(label,
            style: TextStyle(
                fontSize: 12, color: scheme.onSurface.withOpacity(0.5))),
      ],
    );
  }
}
