import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/paper.dart';

class PaperDetailScreen extends StatelessWidget {
  final Paper paper;
  final bool showChinese;

  const PaperDetailScreen({
    super.key,
    required this.paper,
    required this.showChinese,
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

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new,
              size: 18, color: Color(0xFF475569)),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          paper.journalName,
          style: const TextStyle(
            fontSize: 14,
            color: Color(0xFF64748B),
            fontWeight: FontWeight.w500,
          ),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header card
            Container(
              width: double.infinity,
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Badges row
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 5),
                        decoration: BoxDecoration(
                          color: tierBg,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                              color: tierColor.withValues(alpha: 0.3)),
                        ),
                        child: Text(
                          '${paper.journalId} · Tier ${paper.tier}',
                          style: TextStyle(
                            color: tierColor,
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          paper.date,
                          style: const TextStyle(
                            color: Color(0xFF64748B),
                            fontSize: 13,
                          ),
                        ),
                      ),
                      if (paper.isOa)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: const Color(0xFFECFDF5),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.lock_open,
                                  size: 14, color: Color(0xFF059669)),
                              SizedBox(width: 4),
                              Text(
                                'Open Access',
                                style: TextStyle(
                                  color: Color(0xFF059669),
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      if (paper.citedBy > 0)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.format_quote,
                                  size: 14, color: Color(0xFF64748B)),
                              const SizedBox(width: 4),
                              Text(
                                'Cited ${paper.citedBy}',
                                style: const TextStyle(
                                  color: Color(0xFF64748B),
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // Chinese title
                  if (paper.titleCn.isNotEmpty) ...[
                    Text(
                      paper.titleCn,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        height: 1.4,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 10),
                  ],

                  // English title
                  Text(
                    paper.title,
                    style: TextStyle(
                      fontSize: paper.titleCn.isNotEmpty ? 14 : 20,
                      fontWeight: paper.titleCn.isNotEmpty
                          ? FontWeight.w400
                          : FontWeight.w700,
                      color: paper.titleCn.isNotEmpty
                          ? const Color(0xFF64748B)
                          : const Color(0xFF0F172A),
                      height: 1.5,
                    ),
                  ),

                  // DOI
                  if (paper.doi.isNotEmpty) ...[
                    const SizedBox(height: 14),
                    GestureDetector(
                      onTap: () => launchUrl(Uri.parse(paper.doi)),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF0F9FF),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                              color: const Color(0xFFBAE6FD)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.link,
                                size: 16, color: Color(0xFF0284C7)),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                paper.doi,
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Color(0xFF0284C7),
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const Icon(Icons.open_in_new,
                                size: 14, color: Color(0xFF0284C7)),
                          ],
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),

            // Abstract card
            Container(
              width: double.infinity,
              margin: const EdgeInsets.symmetric(horizontal: 16),
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.subject,
                          size: 18, color: Color(0xFF6366F1)),
                      SizedBox(width: 8),
                      Text(
                        'Abstract',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF1E293B),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  if (paper.abstractCn.isNotEmpty) ...[
                    SelectableText(
                      paper.abstractCn,
                      style: const TextStyle(
                        fontSize: 15,
                        height: 1.8,
                        color: Color(0xFF334155),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(12),
                        border:
                            Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: ExpansionTile(
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                        title: const Text(
                          'English Abstract',
                          style: TextStyle(
                            fontSize: 13,
                            color: Color(0xFF64748B),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        children: [
                          Padding(
                            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                            child: SelectableText(
                              paper.abstract_,
                              style: const TextStyle(
                                fontSize: 13,
                                color: Color(0xFF64748B),
                                height: 1.7,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ] else ...[
                    SelectableText(
                      paper.abstract_,
                      style: const TextStyle(
                        fontSize: 15,
                        height: 1.8,
                        color: Color(0xFF334155),
                      ),
                    ),
                  ],
                ],
              ),
            ),

            // Topics card
            if (paper.topics.isNotEmpty) ...[
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                margin: const EdgeInsets.symmetric(horizontal: 16),
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.label_outline,
                            size: 18, color: Color(0xFF6366F1)),
                        SizedBox(width: 8),
                        Text(
                          'Topics',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF1E293B),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: paper.topics
                          .where((t) => t.isNotEmpty)
                          .map(
                            (t) => Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: const Color(0xFFEEF2FF),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                t,
                                style: const TextStyle(
                                  fontSize: 13,
                                  color: Color(0xFF4338CA),
                                ),
                              ),
                            ),
                          )
                          .toList(),
                    ),
                  ],
                ),
              ),
            ],

            // PDF button
            if (paper.pdfUrl != null) ...[
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () => launchUrl(Uri.parse(paper.pdfUrl!)),
                    icon: const Icon(Icons.picture_as_pdf),
                    label: const Text('View PDF'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF6366F1),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                  ),
                ),
              ),
            ],

            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
}
