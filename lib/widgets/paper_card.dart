import 'package:flutter/material.dart';
import '../models/paper.dart';

class PaperCard extends StatelessWidget {
  final Paper paper;
  final bool showChinese;
  final VoidCallback onToggleSelect;
  final VoidCallback? onTap;

  const PaperCard({
    super.key,
    required this.paper,
    required this.showChinese,
    required this.onToggleSelect,
    this.onTap,
  });

  static const _tierColors = {
    1: Color(0xFFEF4444),
    2: Color(0xFFF59E0B),
    3: Color(0xFF10B981),
  };

  static const _tierBgColors = {
    1: Color(0xFFFEF2F2),
    2: Color(0xFFFFFBEB),
    3: Color(0xFFECFDF5),
  };

  @override
  Widget build(BuildContext context) {
    final tierColor = _tierColors[paper.tier] ?? _tierColors[3]!;
    final tierBg = _tierBgColors[paper.tier] ?? _tierBgColors[3]!;
    final title = showChinese && paper.titleCn.isNotEmpty
        ? paper.titleCn
        : paper.title;
    final abstract_ = showChinese && paper.abstractCn.isNotEmpty
        ? paper.abstractCn
        : paper.abstract_;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
      decoration: BoxDecoration(
        color: paper.isSelected ? const Color(0xFFF0F0FF) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: paper.isSelected
              ? const Color(0xFF6366F1).withValues(alpha: 0.4)
              : const Color(0xFFE2E8F0),
          width: paper.isSelected ? 1.5 : 1,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header row
                Row(
                  children: [
                    // Journal badge
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: tierBg,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                            color: tierColor.withValues(alpha: 0.3)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            paper.journalId,
                            style: TextStyle(
                              color: tierColor,
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.5,
                            ),
                          ),
                          Container(
                            margin: const EdgeInsets.only(left: 6),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 5, vertical: 1),
                            decoration: BoxDecoration(
                              color: tierColor.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              'T${paper.tier}',
                              style: TextStyle(
                                color: tierColor,
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    // Date
                    Text(
                      paper.date,
                      style: TextStyle(
                        color: Colors.grey[500],
                        fontSize: 12,
                      ),
                    ),
                    if (paper.isOa) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFFECFDF5),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text(
                          'OA',
                          style: TextStyle(
                            color: Color(0xFF059669),
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                    const Spacer(),
                    // Checkbox
                    GestureDetector(
                      onTap: onToggleSelect,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        width: 24,
                        height: 24,
                        decoration: BoxDecoration(
                          color: paper.isSelected
                              ? const Color(0xFF6366F1)
                              : Colors.white,
                          borderRadius: BorderRadius.circular(7),
                          border: Border.all(
                            color: paper.isSelected
                                ? const Color(0xFF6366F1)
                                : const Color(0xFFCBD5E1),
                            width: 1.5,
                          ),
                        ),
                        child: paper.isSelected
                            ? const Icon(Icons.check,
                                size: 16, color: Colors.white)
                            : null,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Title
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    height: 1.4,
                    color: Color(0xFF1E293B),
                  ),
                ),

                // Abstract preview
                if (abstract_.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    abstract_,
                    style: const TextStyle(
                      fontSize: 13,
                      color: Color(0xFF64748B),
                      height: 1.6,
                    ),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],

                // Topics + citations
                if (paper.topics.isNotEmpty || paper.citedBy > 0) ...[
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: [
                      ...paper.topics.where((t) => t.isNotEmpty).take(2).map(
                            (t) => Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF1F5F9),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                t,
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: Color(0xFF64748B),
                                ),
                              ),
                            ),
                          ),
                      if (paper.citedBy > 0)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.format_quote_rounded,
                                  size: 12, color: Color(0xFF94A3B8)),
                              const SizedBox(width: 3),
                              Text(
                                '${paper.citedBy}',
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: Color(0xFF64748B),
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
