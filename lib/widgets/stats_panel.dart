import 'package:flutter/material.dart';
import '../data/source_config.dart';

class StatsPanel extends StatefulWidget {
  final Map<DataSource, Map<String, String>> deletedDoisBySource;
  final Map<DataSource, Set<String>> readDoisBySource;
  final Map<DataSource, List<Map<String, dynamic>>> ideaPapersBySource;
  final Map<DataSource, int> ideaEverCountBySource;
  final bool showChinese;
  final VoidCallback? onClose;

  const StatsPanel({
    super.key,
    required this.deletedDoisBySource,
    required this.readDoisBySource,
    required this.ideaPapersBySource,
    required this.ideaEverCountBySource,
    required this.showChinese,
    this.onClose,
  });

  @override
  State<StatsPanel> createState() => _StatsPanelState();
}

class _StatsPanelState extends State<StatsPanel> {
  static const _sources = DataSource.values;
  static const _sourceColors = {
    DataSource.cnki: Color(0xFFC25B3F),
    DataSource.ft50: Color(0xFF8B7355),
    DataSource.cepm: Color(0xFF2E7D6F),
  };

  String _selectedRange = '7d';

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.bar_chart_rounded, size: 22, color: Color(0xFF8B7355)),
              const SizedBox(width: 8),
              Text(
                widget.showChinese ? '浏览统计' : 'Statistics',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Color(0xFF2D2A26)),
              ),
              const Spacer(),
              if (widget.onClose != null)
                IconButton(
                  icon: const Icon(Icons.close, size: 20, color: Color(0xFF9B9488)),
                  onPressed: widget.onClose,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
            ],
          ),
          const SizedBox(height: 20),
          _buildSummaryTable(),
          const SizedBox(height: 24),
          Row(
            children: [
              Text(widget.showChinese ? '处理趋势' : 'Activity Trend',
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF2D2A26))),
              const Spacer(),
              _buildRangeChip('7d', widget.showChinese ? '7天' : '7D'),
              const SizedBox(width: 6),
              _buildRangeChip('30d', widget.showChinese ? '30天' : '30D'),
              const SizedBox(width: 6),
              _buildRangeChip('all', widget.showChinese ? '全部' : 'All'),
            ],
          ),
          const SizedBox(height: 12),
          _buildTrendBars(),
        ],
      ),
    );
  }

  Widget _buildRangeChip(String value, String label) {
    final selected = _selectedRange == value;
    return GestureDetector(
      onTap: () => setState(() => _selectedRange = value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFF8B7355) : const Color(0xFFE8E6DC),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(label, style: TextStyle(
          fontSize: 11, fontWeight: FontWeight.w600,
          color: selected ? Colors.white : const Color(0xFF6B6560),
        )),
      ),
    );
  }

  Widget _buildSummaryTable() {
    final reviewedCounts = <DataSource, int>{};
    final ideaCounts = <DataSource, int>{};
    for (final s in _sources) {
      final deleted = widget.deletedDoisBySource[s]?.length ?? 0;
      final currentIdeas = widget.ideaPapersBySource[s]?.length ?? 0;
      reviewedCounts[s] = deleted + currentIdeas;
      final everCount = widget.ideaEverCountBySource[s] ?? 0;
      ideaCounts[s] = everCount > currentIdeas ? everCount : currentIdeas;
    }

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF5F3ED),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFD8D4CA)),
      ),
      child: Column(
        children: [
          _buildHeaderRow(),
          const Divider(height: 1, color: Color(0xFFD8D4CA)),
          _buildMetricRow(label: widget.showChinese ? '已读' : 'Reviewed', counts: reviewedCounts, color: const Color(0xFF8B7355)),
          const Divider(height: 1, indent: 12, endIndent: 12, color: Color(0xFFE8E6DC)),
          _buildMetricRow(label: widget.showChinese ? '收藏' : 'Idea', counts: ideaCounts, color: const Color(0xFF5A8A6A)),
        ],
      ),
    );
  }

  Widget _buildHeaderRow() {
    const style = TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF9B9488));
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(
        children: [
          const SizedBox(width: 56),
          for (final s in _sources) Expanded(child: Text(s.label, textAlign: TextAlign.center, style: style)),
          SizedBox(width: 48, child: Text(widget.showChinese ? '合计' : 'Total', textAlign: TextAlign.center, style: style)),
        ],
      ),
    );
  }

  Widget _buildMetricRow({required String label, required Map<DataSource, int> counts, required Color color}) {
    final total = counts.values.fold(0, (a, b) => a + b);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(
        children: [
          SizedBox(width: 56, child: Row(children: [
            Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
            const SizedBox(width: 6),
            Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: Color(0xFF6B6560))),
          ])),
          for (final s in _sources)
            Expanded(child: Text('${counts[s] ?? 0}', textAlign: TextAlign.center, style: TextStyle(
              fontSize: 14, fontWeight: FontWeight.w700,
              color: (counts[s] ?? 0) > 0 ? const Color(0xFF2D2A26) : const Color(0xFFBDB8B0),
            ))),
          SizedBox(width: 48, child: Text('$total', textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFF2D2A26)))),
        ],
      ),
    );
  }

  Map<String, Map<DataSource, int>> _computeDailyCounts() {
    final result = <String, Map<DataSource, int>>{};
    for (final source in _sources) {
      for (final date in (widget.deletedDoisBySource[source] ?? {}).values) {
        result.putIfAbsent(date, () => {});
        result[date]![source] = (result[date]![source] ?? 0) + 1;
      }
      for (final idea in widget.ideaPapersBySource[source] ?? []) {
        final date = idea['added_date'] as String?;
        if (date != null) {
          result.putIfAbsent(date, () => {});
          result[date]![source] = (result[date]![source] ?? 0) + 1;
        }
      }
    }
    return result;
  }

  Widget _buildTrendBars() {
    final dailyCounts = _computeDailyCounts();
    final now = DateTime.now();
    List<String> displayDays;

    if (_selectedRange == 'all') {
      displayDays = dailyCounts.keys.toList()..sort((a, b) => b.compareTo(a));
    } else {
      final rangeDays = _selectedRange == '30d' ? 30 : 7;
      final allDays = List.generate(rangeDays, (i) {
        final d = now.subtract(Duration(days: i));
        return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
      });
      displayDays = allDays.where((d) => dailyCounts.containsKey(d)).toList();
    }

    if (displayDays.isEmpty) {
      return Center(child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: Text(widget.showChinese ? '暂无数据' : 'No activity',
            style: const TextStyle(fontSize: 13, color: Color(0xFF9B9488))),
      ));
    }

    int maxTotal = 0;
    for (final date in displayDays) {
      final total = (dailyCounts[date] ?? {}).values.fold(0, (a, b) => a + b);
      if (total > maxTotal) maxTotal = total;
    }

    return Column(children: [
      Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Row(children: [
          for (final source in _sources) ...[
            Container(width: 10, height: 10, decoration: BoxDecoration(
              color: _sourceColors[source], borderRadius: BorderRadius.circular(2))),
            const SizedBox(width: 4),
            Text(source.label, style: const TextStyle(fontSize: 11, color: Color(0xFF6B6560))),
            const SizedBox(width: 12),
          ],
        ]),
      ),
      for (final date in displayDays) _buildDayBar(date, dailyCounts[date] ?? {}, maxTotal),
    ]);
  }

  Widget _buildDayBar(String date, Map<DataSource, int> counts, int maxTotal) {
    final total = counts.values.fold(0, (a, b) => a + b);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(children: [
        SizedBox(width: 44, child: Text(date.substring(5),
            style: const TextStyle(fontSize: 11, color: Color(0xFF9B9488), fontWeight: FontWeight.w500))),
        Expanded(child: LayoutBuilder(builder: (context, constraints) {
          final maxWidth = constraints.maxWidth;
          final bars = <Widget>[];
          for (final source in _sources) {
            final count = counts[source] ?? 0;
            if (count > 0) {
              bars.add(Container(
                width: maxWidth * (count / maxTotal), height: 20,
                color: _sourceColors[source]!.withOpacity(0.8),
              ));
            }
          }
          if (bars.isEmpty) return const SizedBox(height: 20);
          return ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: Row(children: bars),
          );
        })),
        SizedBox(width: 32, child: Text(total > 0 ? '$total' : '', textAlign: TextAlign.right,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF6B6560)))),
      ]),
    );
  }
}
