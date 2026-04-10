import 'package:flutter/material.dart';
import '../data/source_config.dart';

class StatsPanel extends StatelessWidget {
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

  static const _sources = DataSource.values;
  static const _sourceColors = {
    DataSource.cnki: Color(0xFFC25B3F),
    DataSource.ft50: Color(0xFF8B7355),
    DataSource.cepm: Color(0xFF2E7D6F),
  };

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
              Text(showChinese ? '浏览统计' : 'Statistics',
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Color(0xFF2D2A26))),
              const Spacer(),
              if (onClose != null)
                IconButton(
                  icon: const Icon(Icons.close, size: 20, color: Color(0xFF9B9488)),
                  onPressed: onClose,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
            ],
          ),
          const SizedBox(height: 20),
          _buildSummaryTable(),
          const SizedBox(height: 28),
          Text(showChinese ? '月度趋势' : 'Monthly Trend',
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF2D2A26))),
          const SizedBox(height: 4),
          Text(showChinese ? '每月已读论文数（按模块）' : 'Papers reviewed per month by source',
              style: const TextStyle(fontSize: 11, color: Color(0xFF9B9488))),
          const SizedBox(height: 16),
          _buildMonthlyChart(),
        ],
      ),
    );
  }

  Widget _buildSummaryTable() {
    final reviewedCounts = <DataSource, int>{};
    final ideaCounts = <DataSource, int>{};
    for (final s in _sources) {
      final deleted = deletedDoisBySource[s]?.length ?? 0;
      final currentIdeas = ideaPapersBySource[s]?.length ?? 0;
      reviewedCounts[s] = deleted + currentIdeas;
      final everCount = ideaEverCountBySource[s] ?? 0;
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
          _buildMetricRow(label: showChinese ? '已读' : 'Reviewed', counts: reviewedCounts, color: const Color(0xFF8B7355)),
          const Divider(height: 1, indent: 12, endIndent: 12, color: Color(0xFFE8E6DC)),
          _buildMetricRow(label: showChinese ? '收藏' : 'Idea', counts: ideaCounts, color: const Color(0xFF5A8A6A)),
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
          SizedBox(width: 48, child: Text(showChinese ? '合计' : 'Total', textAlign: TextAlign.center, style: style)),
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

  // Group all dates (deletions + idea adds) into monthly buckets per source
  Map<String, Map<DataSource, int>> _computeMonthlyCounts() {
    final result = <String, Map<DataSource, int>>{};
    for (final source in _sources) {
      // Deletions
      for (final date in (deletedDoisBySource[source] ?? {}).values) {
        if (date.length >= 7) {
          final month = date.substring(0, 7); // "2026-04"
          result.putIfAbsent(month, () => {});
          result[month]![source] = (result[month]![source] ?? 0) + 1;
        }
      }
      // Ideas (current ones, by added_date)
      for (final idea in ideaPapersBySource[source] ?? []) {
        final date = idea['added_date'] as String?;
        if (date != null && date.length >= 7) {
          final month = date.substring(0, 7);
          result.putIfAbsent(month, () => {});
          result[month]![source] = (result[month]![source] ?? 0) + 1;
        }
      }
    }
    return result;
  }

  Widget _buildMonthlyChart() {
    final monthlyCounts = _computeMonthlyCounts();
    if (monthlyCounts.isEmpty) {
      return Center(child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: Text(showChinese ? '暂无数据' : 'No activity',
            style: const TextStyle(fontSize: 13, color: Color(0xFF9B9488))),
      ));
    }

    final months = monthlyCounts.keys.toList()..sort();

    // Find max for scaling
    int maxTotal = 0;
    for (final month in months) {
      final total = (monthlyCounts[month] ?? {}).values.fold(0, (a, b) => a + b);
      if (total > maxTotal) maxTotal = total;
    }

    return Column(
      children: [
        // Legend
        Padding(
          padding: const EdgeInsets.only(bottom: 16),
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
        // Bars (one row per month)
        for (final month in months)
          _buildMonthBar(month, monthlyCounts[month] ?? {}, maxTotal),
      ],
    );
  }

  Widget _buildMonthBar(String month, Map<DataSource, int> counts, int maxTotal) {
    final total = counts.values.fold(0, (a, b) => a + b);
    // Format "2026-04" -> "4月" or "Apr"
    final monthNum = int.tryParse(month.substring(5, 7)) ?? 0;
    const monthNames = ['', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    final label = showChinese ? '${monthNum}月' : monthNames[monthNum];

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(children: [
        SizedBox(width: 40, child: Text(label,
            style: const TextStyle(fontSize: 12, color: Color(0xFF6B6560), fontWeight: FontWeight.w600))),
        Expanded(child: LayoutBuilder(builder: (context, constraints) {
          final maxWidth = constraints.maxWidth;
          final bars = <Widget>[];
          for (final source in _sources) {
            final count = counts[source] ?? 0;
            if (count > 0) {
              bars.add(Tooltip(
                message: '${source.label}: $count',
                child: Container(
                  width: maxWidth * (count / maxTotal),
                  height: 28,
                  alignment: Alignment.center,
                  color: _sourceColors[source]!.withOpacity(0.85),
                  child: count >= 5
                      ? Text('$count', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Colors.white))
                      : null,
                ),
              ));
            }
          }
          if (bars.isEmpty) return const SizedBox(height: 28);
          return ClipRRect(
            borderRadius: BorderRadius.circular(5),
            child: Row(children: bars),
          );
        })),
        SizedBox(width: 36, child: Text('$total', textAlign: TextAlign.right,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF2D2A26)))),
      ]),
    );
  }
}
