import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/journal.dart';
import '../models/paper.dart';
import '../data/journals.dart';

class OpenAlexService {
  static const _base = 'https://api.openalex.org';

  /// Fetch recent papers from a journal (last 3 months by default)
  static Future<List<Paper>> fetchJournalPapers(
    Journal journal, {
    int months = 3,
    int perPage = 50,
  }) async {
    final now = DateTime.now();
    final from = DateTime(now.year, now.month - months, now.day);
    final fromStr =
        '${from.year}-${from.month.toString().padLeft(2, '0')}-${from.day.toString().padLeft(2, '0')}';

    final url = Uri.parse(
      '$_base/works?filter=primary_location.source.id:${journal.openalexId},'
      'from_publication_date:$fromStr,type:article'
      '&sort=publication_date:desc'
      '&per_page=$perPage'
      '&mailto=$openalexMailto',
    );

    final resp = await http.get(url);
    if (resp.statusCode != 200) {
      throw Exception('OpenAlex API error: ${resp.statusCode}');
    }

    final data = jsonDecode(resp.body);
    final results = data['results'] as List;

    return results.map((w) => _parseWork(w, journal)).toList();
  }

  /// Fetch papers from multiple journals
  static Future<List<Paper>> fetchMultipleJournals(
    List<Journal> targetJournals, {
    int months = 3,
    Function(String journalId, int count)? onProgress,
  }) async {
    final allPapers = <Paper>[];

    for (final journal in targetJournals) {
      try {
        final papers = await fetchJournalPapers(journal, months: months);
        allPapers.addAll(papers);
        onProgress?.call(journal.id, papers.length);
      } catch (e) {
        onProgress?.call(journal.id, -1); // -1 indicates error
      }
    }

    return allPapers;
  }

  static Paper _parseWork(Map<String, dynamic> w, Journal journal) {
    // Reconstruct abstract from inverted index
    String abstract_ = '';
    final invertedAbstract = w['abstract_inverted_index'];
    if (invertedAbstract != null && invertedAbstract is Map) {
      final positions = <int, String>{};
      for (final entry in invertedAbstract.entries) {
        final word = entry.key as String;
        final indices = entry.value as List;
        for (final idx in indices) {
          positions[idx as int] = word;
        }
      }
      final sortedKeys = positions.keys.toList()..sort();
      abstract_ = sortedKeys.map((k) => positions[k]).join(' ');
    }

    // Extract topics
    final topics = <String>[];
    final topicsList = w['topics'] as List?;
    if (topicsList != null) {
      for (final t in topicsList.take(3)) {
        topics.add(t['display_name'] as String? ?? '');
      }
    }

    // DOI
    final doi = w['doi'] as String? ?? '';

    // PDF URL
    String? pdfUrl;
    final bestOa = w['best_oa_location'];
    if (bestOa != null) {
      pdfUrl = bestOa['pdf_url'] as String?;
    }

    return Paper(
      id: w['id'] as String? ?? '',
      title: w['title'] as String? ?? '',
      abstract_: abstract_,
      doi: doi,
      date: w['publication_date'] as String? ?? '',
      journalId: journal.id,
      journalName: journal.name,
      tier: journal.tier,
      topics: topics,
      citedBy: w['cited_by_count'] as int? ?? 0,
      isOa: w['open_access']?['is_oa'] as bool? ?? false,
      pdfUrl: pdfUrl,
    );
  }
}
