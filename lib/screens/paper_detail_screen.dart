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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(paper.journalId),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Journal + Tier badge
            Row(
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: _tierColor,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    '${paper.journalId} · T${paper.tier}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Text(paper.date,
                    style: TextStyle(color: Colors.grey[600], fontSize: 14)),
                if (paper.isOa) ...[
                  const SizedBox(width: 8),
                  const Chip(
                    label: Text('OA', style: TextStyle(fontSize: 11)),
                    padding: EdgeInsets.zero,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ],
              ],
            ),
            const SizedBox(height: 16),

            // Chinese title
            if (paper.titleCn.isNotEmpty) ...[
              Text(
                paper.titleCn,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 8),
            ],

            // English title
            Text(
              paper.title,
              style: TextStyle(
                fontSize: paper.titleCn.isNotEmpty ? 15 : 20,
                fontWeight: paper.titleCn.isNotEmpty
                    ? FontWeight.normal
                    : FontWeight.bold,
                color: paper.titleCn.isNotEmpty ? Colors.grey[700] : null,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 16),

            // DOI
            if (paper.doi.isNotEmpty)
              GestureDetector(
                onTap: () => launchUrl(Uri.parse(paper.doi)),
                child: Text(
                  paper.doi,
                  style: const TextStyle(
                    color: Colors.blue,
                    decoration: TextDecoration.underline,
                    fontSize: 13,
                  ),
                ),
              ),

            const Divider(height: 32),

            // Abstract header
            const Text(
              '摘要',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),

            // Chinese abstract
            if (paper.abstractCn.isNotEmpty) ...[
              Text(
                paper.abstractCn,
                style: const TextStyle(fontSize: 15, height: 1.7),
              ),
              const SizedBox(height: 16),
              ExpansionTile(
                title: const Text('English Abstract',
                    style: TextStyle(fontSize: 13)),
                initiallyExpanded: false,
                children: [
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: SelectableText(
                      paper.abstract_,
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey[700],
                        height: 1.6,
                      ),
                    ),
                  ),
                ],
              ),
            ] else ...[
              SelectableText(
                paper.abstract_,
                style: const TextStyle(fontSize: 15, height: 1.7),
              ),
            ],

            const SizedBox(height: 16),

            // Topics
            if (paper.topics.isNotEmpty) ...[
              const Divider(),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: paper.topics
                    .where((t) => t.isNotEmpty)
                    .map(
                      (t) => Chip(
                        label: Text(t, style: const TextStyle(fontSize: 12)),
                        materialTapTargetSize:
                            MaterialTapTargetSize.shrinkWrap,
                      ),
                    )
                    .toList(),
              ),
            ],

            // PDF link
            if (paper.pdfUrl != null) ...[
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: () => launchUrl(Uri.parse(paper.pdfUrl!)),
                icon: const Icon(Icons.picture_as_pdf),
                label: const Text('查看 PDF'),
              ),
            ],

            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

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
}
