import 'package:flutter/material.dart';
import '../models/paper.dart';

/// Predefined keywords for highlighting
const List<String> highlightKeywordsEn = [
  'game theory', 'supply chain', 'network', 'optimization', 'prediction',
  'platform', 'resilience', 'contract', 'auction', 'mechanism design',
  'Nash', 'equilibrium', 'Stackelberg', 'coordination', 'disruption',
  'ESG', 'sustainability',
];

const List<String> highlightKeywordsCn = [
  '博弈论', '供应链', '网络', '优化', '预测', '平台', '韧性', '合同',
  '拍卖', '机制设计', '纳什', '均衡', '斯塔克尔伯格', '协调', '中断',
  'ESG', '可持续',
];

List<String> get allHighlightKeywords => [...highlightKeywordsEn, ...highlightKeywordsCn];

/// Build a TextSpan with keyword highlighting
TextSpan buildHighlightedText(String text, TextStyle baseStyle) {
  if (text.isEmpty) return TextSpan(text: text, style: baseStyle);

  // Sort keywords by length descending to match longer ones first
  final keywords = List<String>.from(allHighlightKeywords)
    ..sort((a, b) => b.length.compareTo(a.length));

  // Build regex pattern
  final pattern = keywords.map((k) => RegExp.escape(k)).join('|');
  final regex = RegExp('($pattern)', caseSensitive: false);

  final spans = <TextSpan>[];
  int lastEnd = 0;

  for (final match in regex.allMatches(text)) {
    if (match.start > lastEnd) {
      spans.add(TextSpan(text: text.substring(lastEnd, match.start)));
    }
    spans.add(TextSpan(
      text: match.group(0),
      style: baseStyle.copyWith(
        backgroundColor: const Color(0xFFFFF3CD),
        fontWeight: FontWeight.w600,
      ),
    ));
    lastEnd = match.end;
  }
  if (lastEnd < text.length) {
    spans.add(TextSpan(text: text.substring(lastEnd)));
  }

  return TextSpan(style: baseStyle, children: spans);
}

class PaperCard extends StatefulWidget {
  final Paper paper;
  final bool showChinese;
  final VoidCallback onToggleSelect;
  final VoidCallback? onTap;
  final VoidCallback? onDelete;
  final bool isRead;
  final bool isDeleted;

  const PaperCard({
    super.key,
    required this.paper,
    required this.showChinese,
    required this.onToggleSelect,
    this.onTap,
    this.onDelete,
    this.isRead = false,
    this.isDeleted = false,
  });

  @override
  State<PaperCard> createState() => _PaperCardState();
}

class _PaperCardState extends State<PaperCard> with SingleTickerProviderStateMixin {
  late AnimationController _starController;
  late Animation<double> _starScale;

  static const _tierColors = {
    1: Color(0xFFC25B3F),
    2: Color(0xFFB8963E),
    3: Color(0xFF5A8A6A),
  };

  static const _tierBgColors = {
    1: Color(0xFFFAF0ED),
    2: Color(0xFFFAF6ED),
    3: Color(0xFFEDF5F0),
  };

  @override
  void initState() {
    super.initState();
    _starController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _starScale = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.4), weight: 50),
      TweenSequenceItem(tween: Tween(begin: 1.4, end: 1.0), weight: 50),
    ]).animate(CurvedAnimation(parent: _starController, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _starController.dispose();
    super.dispose();
  }

  static String _tierLabel(int tier) {
    const labels = {1: 'A', 2: 'B', 3: 'C'};
    return labels[tier] ?? 'C';
  }

  void _onStarTap() {
    _starController.forward(from: 0);
    widget.onToggleSelect();
  }

  @override
  Widget build(BuildContext context) {
    final paper = widget.paper;
    final tierColor = _tierColors[paper.tier] ?? _tierColors[3]!;
    final tierBg = _tierBgColors[paper.tier] ?? _tierBgColors[3]!;
    final title = widget.showChinese && paper.titleCn.isNotEmpty
        ? paper.titleCn
        : paper.title;
    final abstract_ = widget.showChinese && paper.abstractCn.isNotEmpty
        ? paper.abstractCn
        : paper.abstract_;

    final isRead = widget.isRead;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
      decoration: BoxDecoration(
        color: paper.isSelected
            ? const Color(0xFFF5F0E8)
            : isRead
                ? const Color(0xFFF0EEE8)
                : const Color(0xFFF5F3ED),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: paper.isSelected
              ? const Color(0xFF8B7355).withValues(alpha: 0.5)
              : const Color(0xFFD8D4CA),
          width: paper.isSelected ? 1.5 : 1,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A000000),
            offset: Offset(0, 1),
            blurRadius: 3,
          ),
        ],
      ),
      child: Row(
        children: [
          // Left border accent for unread
          if (!isRead)
            Container(
              width: 4,
              height: 80,
              decoration: BoxDecoration(
                color: tierColor,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(16),
                  bottomLeft: Radius.circular(16),
                ),
              ),
            ),
          Expanded(
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: widget.onTap,
                child: Padding(
                  padding: EdgeInsets.fromLTRB(
                    isRead ? 16 : 12, 16, 16, 16,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header row
                      Row(
                        children: [
                          // Journal badge with inline category
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: tierColor,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              '${paper.journalId} · ${_tierLabel(paper.tier)}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          // Date
                          Text(
                            paper.date,
                            style: TextStyle(
                              color: isRead
                                  ? const Color(0xFFB5AFA6)
                                  : const Color(0xFF9B9488),
                              fontSize: 12,
                            ),
                          ),
                          if (paper.isOa) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFFEDF5F0),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: const Text(
                                'OA',
                                style: TextStyle(
                                  color: Color(0xFF5A8A6A),
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                          const Spacer(),
                          // Delete / Restore button
                          if (widget.onDelete != null)
                            GestureDetector(
                              onTap: widget.onDelete,
                              child: Container(
                                margin: const EdgeInsets.only(right: 6),
                                padding: const EdgeInsets.all(4),
                                decoration: BoxDecoration(
                                  color: widget.isDeleted
                                      ? const Color(0xFFEDF5F0)
                                      : const Color(0xFFF0EDED),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Icon(
                                  widget.isDeleted
                                      ? Icons.restore_rounded
                                      : Icons.close_rounded,
                                  size: 16,
                                  color: widget.isDeleted
                                      ? const Color(0xFF5A8A6A)
                                      : const Color(0xFF9B9488),
                                ),
                              ),
                            ),
                          // Star icon
                          GestureDetector(
                            onTap: _onStarTap,
                            child: ScaleTransition(
                              scale: _starScale,
                              child: Icon(
                                paper.isSelected
                                    ? Icons.star_rounded
                                    : Icons.star_border_rounded,
                                size: 26,
                                color: paper.isSelected
                                    ? const Color(0xFFB8963E)
                                    : const Color(0xFFC5BFB5),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // Title with keyword highlighting
                      RichText(
                        text: buildHighlightedText(
                          title,
                          TextStyle(
                            fontSize: 15,
                            fontWeight: isRead ? FontWeight.w400 : FontWeight.w600,
                            height: 1.4,
                            color: isRead
                                ? const Color(0xFF6B6560)
                                : const Color(0xFF2D2A26),
                          ),
                        ),
                      ),

                      // Abstract preview with keyword highlighting
                      if (abstract_.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        RichText(
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                          text: buildHighlightedText(
                            abstract_,
                            TextStyle(
                              fontSize: 13,
                              color: isRead
                                  ? const Color(0xFF9B9488)
                                  : const Color(0xFF6B6560),
                              height: 1.6,
                            ),
                          ),
                        ),
                      ],

                      // Citations
                      if (paper.citedBy > 0) ...[
                        const SizedBox(height: 10),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: const Color(0xFFECE9E1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.format_quote_rounded,
                                  size: 12, color: Color(0xFF9B9488)),
                              const SizedBox(width: 3),
                              Text(
                                '${paper.citedBy}',
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: Color(0xFF6B6560),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
