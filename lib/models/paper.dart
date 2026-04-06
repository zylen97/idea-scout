class Paper {
  final String id; // OpenAlex work ID
  final String title;
  String titleCn;
  final String abstract_;
  String abstractCn;
  final String doi;
  final String date;
  final String journalId;
  final String journalName;
  final int tier;
  final List<String> topics;
  final int citedBy;
  final bool isOa;
  final String? pdfUrl;
  bool isSelected;

  Paper({
    required this.id,
    required this.title,
    this.titleCn = '',
    required this.abstract_,
    this.abstractCn = '',
    required this.doi,
    required this.date,
    required this.journalId,
    required this.journalName,
    required this.tier,
    required this.topics,
    required this.citedBy,
    required this.isOa,
    this.pdfUrl,
    this.isSelected = false,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'title_cn': titleCn,
        'abstract': abstract_,
        'abstract_cn': abstractCn,
        'doi': doi,
        'date': date,
        'journal_id': journalId,
        'journal_name': journalName,
        'tier': tier,
        'topics': topics,
        'cited_by': citedBy,
        'is_oa': isOa,
        'pdf_url': pdfUrl,
        'is_selected': isSelected,
      };

  factory Paper.fromJson(Map<String, dynamic> json) {
    return Paper(
      id: json['id'] as String? ?? '',
      title: json['title'] as String? ?? '',
      titleCn: json['title_cn'] as String? ?? '',
      abstract_: json['abstract'] as String? ?? '',
      abstractCn: json['abstract_cn'] as String? ?? '',
      doi: json['doi'] as String? ?? '',
      date: json['date'] as String? ?? '',
      journalId: json['journal_id'] as String? ?? '',
      journalName: json['journal_name'] as String? ?? '',
      tier: json['tier'] as int? ?? 3,
      topics: json['topics'] != null
          ? List<String>.from(json['topics'] as List)
          : [],
      citedBy: json['cited_by'] as int? ?? 0,
      isOa: json['is_oa'] as bool? ?? false,
      pdfUrl: json['pdf_url'] as String?,
      isSelected: json['is_selected'] as bool? ?? false,
    );
  }
}
