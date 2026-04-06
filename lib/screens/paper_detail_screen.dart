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

    return Scaffold(
      backgroundColor: const Color(0xFFE8E6DC),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF0EEE6),
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new,
              size: 18, color: Color(0xFF6B6560)),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          paper.journalName,
          style: const TextStyle(
            fontSize: 14,
            color: Color(0xFF6B6560),
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
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: const Color(0xFFF5F3ED),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFD8D4CA)),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x0A000000),
                    offset: Offset(0, 1),
                    blurRadius: 3,
                  ),
                ],
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
                              color: tierColor.withValues(alpha: 0.25)),
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
                          color: const Color(0xFFECE9E1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          paper.date,
                          style: const TextStyle(
                            color: Color(0xFF6B6560),
                            fontSize: 13,
                          ),
                        ),
                      ),
                      if (paper.isOa)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: const Color(0xFFEDF5F0),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.lock_open,
                                  size: 14, color: Color(0xFF5A8A6A)),
                              SizedBox(width: 4),
                              Text(
                                'Open Access',
                                style: TextStyle(
                                  color: Color(0xFF5A8A6A),
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
                            color: const Color(0xFFECE9E1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.format_quote,
                                  size: 14, color: Color(0xFF6B6560)),
                              const SizedBox(width: 4),
                              Text(
                                'Cited ${paper.citedBy}',
                                style: const TextStyle(
                                  color: Color(0xFF6B6560),
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // Chinese title
                  if (paper.titleCn.isNotEmpty) ...[
                    Text(
                      paper.titleCn,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        height: 1.4,
                        color: Color(0xFF2D2A26),
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
                          ? const Color(0xFF6B6560)
                          : const Color(0xFF2D2A26),
                      height: 1.5,
                    ),
                  ),

                  // DOI
                  if (paper.doi.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    GestureDetector(
                      onTap: () => launchUrl(Uri.parse(paper.doi)),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: const Color(0xFFECE9E1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                              color: const Color(0xFFD8D4CA)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.link,
                                size: 16, color: Color(0xFF8B7355)),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                paper.doi,
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Color(0xFF8B7355),
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const Icon(Icons.open_in_new,
                                size: 14, color: Color(0xFF8B7355)),
                          ],
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),

            // Abstract section heading
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
              child: Row(
                children: [
                  Container(
                    width: 6,
                    height: 6,
                    decoration: const BoxDecoration(
                      color: Color(0xFF8B7355),
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 10),
                  const Text(
                    'Abstract',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF2D2A26),
                      letterSpacing: 0.3,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Container(
                      height: 1,
                      color: const Color(0xFFD8D4CA),
                    ),
                  ),
                ],
              ),
            ),

            // Abstract card
            Container(
              width: double.infinity,
              margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: const Color(0xFFF5F3ED),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFD8D4CA)),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x0A000000),
                    offset: Offset(0, 1),
                    blurRadius: 3,
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (paper.abstractCn.isNotEmpty) ...[
                    SelectableText(
                      paper.abstractCn,
                      style: const TextStyle(
                        fontSize: 15,
                        height: 1.8,
                        color: Color(0xFF3D3A36),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFFECE9E1),
                        borderRadius: BorderRadius.circular(12),
                        border:
                            Border.all(color: const Color(0xFFD8D4CA)),
                      ),
                      child: ExpansionTile(
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                        title: const Text(
                          'English Abstract',
                          style: TextStyle(
                            fontSize: 13,
                            color: Color(0xFF6B6560),
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
                                color: Color(0xFF6B6560),
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
                        color: Color(0xFF3D3A36),
                      ),
                    ),
                  ],
                ],
              ),
            ),

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
                      backgroundColor: const Color(0xFF8B7355),
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
