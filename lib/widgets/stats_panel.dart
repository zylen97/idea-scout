import 'package:flutter/material.dart';
import '../data/source_config.dart';

class StatsPanel extends StatelessWidget {
  final Map<DataSource, Map<String, String>> deletedDoisBySource;
  final Map<DataSource, Set<String>> readDoisBySource;
  final Map<DataSource, List<Map<String, dynamic>>> ideaPapersBySource;
  final bool showChinese;
  final ScrollController scrollController;

  const StatsPanel({
    super.key,
    required this.deletedDoisBySource,
    required this.readDoisBySource,
    required this.ideaPapersBySource,
    required this.showChinese,
    required this.scrollController,
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
      controller: scrollController,
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Drag handle
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFFD8D4CA),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),
          // Title
          Row(
            children: [
              const Icon(Icons.bar_chart_rounded, size: 22, color: Color(0xFF8B7355)),
              const SizedBox(width: 8),
              Text(
                showChinese ? '浏览统计' : 'Statistics',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF2D2A26),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          _buildSummaryTable(),
          const SizedBox(height: 28),
          Text(
            showChinese ? '最近 7 天' : 'Last 7 Days',
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Color(0xFF2D2A26),
            ),
          ),
          const SizedBox(height: 12),
          _buildWeeklyTrend(),
        ],
      ),
    );
  }

  Widget _buildSummaryTable() {
    final deletedCounts = {for (final s in _sources) s: (deletedDoisBySource[s]?.length ?? 0)};
    final readCounts = {for (final s in _sources) s: (readDoisBySource[s]?.length ?? 0)};
    final ideaCounts = {for (final s in _sources) s: (ideaPapersBySource[s]?.length ?? 0)};

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF5F3ED),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFD8D4CA)),
      ),
      child: Column(
        children: [
          // Header row
          _buildTableRow(
            label: '',
            values: {for (final s in _sources) s: s.label},
            isHeader: true,
            showTotal: true,
            totalLabel: showChinese ? '合计' : 'Total',
          ),
          const Divider(height: 1, color: Color(0xFFD8D4CA)),
          _buildMetricRow(
            label: showChinese ? '已读' : 'Read',
            counts: readCounts,
            color: const Color(0xFF8B7355),
          ),
          const Divider(height: 1, indent: 12, endIndent: 12, color: Color(0xFFE8E6DC)),
          _buildMetricRow(
            label: 'Idea',
            counts: ideaCounts,
            color: const Color(0xFF5A8A6A),
          ),
          const Divider(height: 1, indent: 12, endIndent: 12, color: Color(0xFFE8E6DC)),
          _buildMetricRow(
            label: showChinese ? '已删' : 'Deleted',
            counts: deletedCounts,
            color: const Color(0xFFC25B3F),
          ),
        ],
      ),
    );
  }

  Widget _buildTableRow({
    required String label,
    required Map<DataSource, String> values,
    bool isHeader = false,
    bool showTotal = false,
    String totalLabel = '',
  }) {
    final style = TextStyle(
      fontSize: 12,
      fontWeight: isHeader ? FontWeight.w600 : FontWeight.w500,
      color: isHeader ? const Color(0xFF9B9488) : const Color(0xFF2D2A26),
    );
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(
        children: [
          SizedBox(width: 56, child: Text(label, style: style)),
          for (final s in _sources)
            Expanded(
              child: Text(
                values[s] ?? '',
                textAlign: TextAlign.center,
                style: style,
              ),
            ),
          if (showTotal)
            SizedBox(
              width: 48,
              child: Text(totalLabel, textAlign: TextAlign.center, style: style),
            ),
        ],
      ),
    );
  }

  Widget _buildMetricRow({
    required String label,
    required Map<DataSource, int> counts,
    required Color color,
  }) {
    final total = counts.values.fold(0, (a, b) => a + b);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(
        children: [
          SizedBox(
            width: 56,
            child: Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                ),
                const SizedBox(width: 6),
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF6B6560),
                  ),
                ),
              ],
            ),
          ),
          for (final s in _sources)
            Expanded(
              child: Text(
                '${counts[s] ?? 0}',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: (counts[s] ?? 0) > 0 ? const Color(0xFF2D2A26) : const Color(0xFFBDB8B0),
                ),
              ),
            ),
          SizedBox(
            width: 48,
            child: Text(
              '$total',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: Color(0xFF2D2A26),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Aggregate daily counts for deletions + ideas across all sources
  Map<String, Map<DataSource, int>> _computeDailyCounts() {
    final result = <String, Map<DataSource, int>>{};

    for (final source in _sources) {
      // Deletions (have dates as values)
      final deleted = deletedDoisBySource[source] ?? {};
      for (final date in deleted.values) {
        result.putIfAbsent(date, () => {});
        result[date]![source] = (result[date]![source] ?? 0) + 1;
      }
      // Ideas (have added_date field)
      for (final idea in ideaPapersBySource[source] ?? []) {
        final date = idea['added_date'] as String?;
        if (date != null) {
          result.putIfAbsent(date, () => {});
          result[date]![source] = (result[date]![source] ?? 0) + 1;
        }
      }
    }
    return result;
  }

  Widget _buildWeeklyTrend() {
    final dailyCounts = _computeDailyCounts();
    final now = DateTime.now();
    final days = List.generate(7, (i) {
      final d = now.subtract(Duration(days: i));
      return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
    });

    // Find max total for scaling
    int maxTotal = 0;
    for (final date in days) {
      final counts = dailyCounts[date] ?? {};
      final total = counts.values.fold(0, (a, b) => a + b);
      if (total > maxTotal) maxTotal = total;
    }
    if (maxTotal == 0) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 24),
          child: Text(
            showChinese ? '暂无数据' : 'No activity',
            style: const TextStyle(fontSize: 13, color: Color(0xFF9B9488)),
          ),
        ),
      );
    }

    return Column(
      children: [
        // Legend
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Row(
            children: [
              for (final source in _sources) ...[
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: _sourceColors[source],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 4),
                Text(
                  source.label,
                  style: const TextStyle(fontSize: 11, color: Color(0xFF6B6560)),
                ),
                const SizedBox(width: 12),
              ],
            ],
          ),
        ),
        // Bars
        for (final date in days) _buildDayBar(date, dailyCounts[date] ?? {}, maxTotal),
      ],
    );
  }

  Widget _buildDayBar(String date, Map<DataSource, int> counts, int maxTotal) {
    final total = counts.values.fold(0, (a, b) => a + b);
    final shortDate = date.substring(5); // "04-10"

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          SizedBox(
            width: 44,
            child: Text(
              shortDate,
              style: const TextStyle(fontSize: 11, color: Color(0xFF9B9488), fontWeight: FontWeight.w500),
            ),
          ),
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final maxWidth = constraints.maxWidth;
                return Row(
                  children: [
                    for (final source in _sources)
                      if ((counts[source] ?? 0) > 0)
                        Container(
                          width: maxWidth * (counts[source]! / maxTotal),
                          height: 20,
                          decoration: BoxDecoration(
                            color: _sourceColors[source]!.withOpacity(0.8),
                            borderRadius: source == _sources.first
                                ? const BorderRadius.horizontal(left: Radius.circular(4))
                                : source == _sources.last || counts.keys.last == source
                                    ? const BorderRadius.horizontal(right: Radius.circular(4))
                                    : BorderRadius.zero,
                          ),
                        ),
                    if (total == 0)
                      Container(
                        height: 20,
                        width: 1,
                        color: const Color(0xFFE8E6DC),
                      ),
                  ],
                );
              },
            ),
          ),
          SizedBox(
            width: 32,
            child: Text(
              total > 0 ? '$total' : '',
              textAlign: TextAlign.right,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Color(0xFF6B6560),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
