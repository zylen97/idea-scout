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
        color: paper.isSelected ? const Color(0xFFF5F0E8) : const Color(0xFFF5F3ED),
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
                            color: tierColor.withValues(alpha: 0.25)),
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
                              color: tierColor.withValues(alpha: 0.12),
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
                      style: const TextStyle(
                        color: Color(0xFF9B9488),
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
                    // Checkbox
                    GestureDetector(
                      onTap: onToggleSelect,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        width: 24,
                        height: 24,
                        decoration: BoxDecoration(
                          color: paper.isSelected
                              ? const Color(0xFF8B7355)
                              : const Color(0xFFF5F3ED),
                          borderRadius: BorderRadius.circular(7),
                          border: Border.all(
                            color: paper.isSelected
                                ? const Color(0xFF8B7355)
                                : const Color(0xFFC5BFB5),
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
                    color: Color(0xFF2D2A26),
                  ),
                ),

                // Abstract preview
                if (abstract_.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    abstract_,
                    style: const TextStyle(
                      fontSize: 13,
                      color: Color(0xFF6B6560),
                      height: 1.6,
                    ),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],

                // Citations only (topics removed)
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
    );
  }
}
