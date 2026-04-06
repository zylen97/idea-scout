import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
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

  Color get _tierColor {
    switch (paper.tier) {
      case 1:
        return const Color(0xFFE53935);
      case 2:
        return const Color(0xFFFF9800);
      default:
        return const Color(0xFF4CAF50);
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = showChinese && paper.titleCn.isNotEmpty
        ? paper.titleCn
        : paper.title;
    final abstract_ = showChinese && paper.abstractCn.isNotEmpty
        ? paper.abstractCn
        : paper.abstract_;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      elevation: paper.isSelected ? 3 : 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: paper.isSelected
            ? BorderSide(color: Theme.of(context).colorScheme.primary, width: 2)
            : BorderSide.none,
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header: journal badge + date + checkbox
              Row(
                children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: _tierColor,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      paper.journalId,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'T${paper.tier}',
                    style: TextStyle(
                      color: _tierColor,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    paper.date,
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 12,
                    ),
                  ),
                  if (paper.isOa) ...[
                    const SizedBox(width: 6),
                    Icon(Icons.lock_open, size: 14, color: Colors.green[700]),
                  ],
                  const Spacer(),
                  SizedBox(
                    width: 32,
                    height: 32,
                    child: Checkbox(
                      value: paper.isSelected,
                      onChanged: (_) => onToggleSelect(),
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // Title
              Text(
                title,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  height: 1.3,
                ),
              ),

              // Abstract (if expanded via onTap)
              if (abstract_.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  abstract_,
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey[700],
                    height: 1.5,
                  ),
                  maxLines: 4,
                  overflow: TextOverflow.ellipsis,
                ),
              ],

              // Topics + citations
              if (paper.topics.isNotEmpty || paper.citedBy > 0) ...[
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: [
                    ...paper.topics.where((t) => t.isNotEmpty).map(
                          (t) => Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.grey[200],
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              t,
                              style: TextStyle(
                                  fontSize: 11, color: Colors.grey[700]),
                            ),
                          ),
                        ),
                    if (paper.citedBy > 0)
                      Text(
                        '📖 ${paper.citedBy}',
                        style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                      ),
                  ],
                ),
              ],

              // DOI link
              if (paper.doi.isNotEmpty) ...[
                const SizedBox(height: 6),
                GestureDetector(
                  onTap: () => launchUrl(Uri.parse(paper.doi)),
                  child: Text(
                    paper.doi,
                    style: const TextStyle(
                      fontSize: 11,
                      color: Colors.blue,
                      decoration: TextDecoration.underline,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
