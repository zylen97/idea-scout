class Journal {
  final String id;
  final String name;
  final String openalexId;
  final String issn;
  final int tier;
  final List<String> tags;
  final String transferTo;

  const Journal({
    required this.id,
    required this.name,
    required this.openalexId,
    required this.issn,
    required this.tier,
    required this.tags,
    required this.transferTo,
  });

  factory Journal.fromJson(Map<String, dynamic> json) {
    return Journal(
      id: json['id'] as String,
      name: json['name'] as String,
      openalexId: json['openalex_id'] as String,
      issn: json['issn'] as String,
      tier: json['tier'] as int,
      tags: List<String>.from(json['tags'] as List),
      transferTo: json['transfer_to'] as String,
    );
  }
}
