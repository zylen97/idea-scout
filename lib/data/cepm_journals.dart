import '../models/journal.dart';

const List<Map<String, dynamic>> _cepmJournalData = [
  {"id": "AEI", "name": "Advanced Engineering Informatics", "openalex_id": "S112141509", "issn": "1474-0346", "tier": 1, "tags": ["智能化", "BIM", "数字孪生"], "transfer_to": ""},
  {"id": "AIC", "name": "Automation in Construction", "openalex_id": "S172073041", "issn": "0926-5805", "tier": 1, "tags": ["智能建造", "自动化"], "transfer_to": ""},
  {"id": "BAE", "name": "Building and Environment", "openalex_id": "S56464651", "issn": "0360-1323", "tier": 1, "tags": ["建筑环境", "室内环境"], "transfer_to": ""},
  {"id": "ECAM", "name": "Engineering Construction & Architectural Management", "openalex_id": "S120049674", "issn": "0969-9988", "tier": 1, "tags": ["建设管理", "项目交付"], "transfer_to": ""},
  {"id": "IJPM", "name": "International Journal of Project Management", "openalex_id": "S69872077", "issn": "0263-7863", "tier": 1, "tags": ["项目管理", "治理"], "transfer_to": ""},
  {"id": "JBE2", "name": "Journal of Building Engineering", "openalex_id": "S2764478331", "issn": "2352-7102", "tier": 1, "tags": ["建筑工程", "结构"], "transfer_to": ""},
  {"id": "JCEM", "name": "Journal of Construction Engineering and Management", "openalex_id": "S2764777209", "issn": "0733-9364", "tier": 1, "tags": ["建工", "合同", "调度"], "transfer_to": ""},
  {"id": "JME", "name": "Journal of Management in Engineering", "openalex_id": "S144495243", "issn": "0742-597X", "tier": 1, "tags": ["工程管理", "组织"], "transfer_to": ""},
  {"id": "PMJ", "name": "Project Management Journal", "openalex_id": "S196205230", "issn": "1938-9507", "tier": 1, "tags": ["项目管理"], "transfer_to": ""},
  {"id": "SS", "name": "Safety Science", "openalex_id": "S123149298", "issn": "0925-7535", "tier": 1, "tags": ["安全", "行为安全"], "transfer_to": ""},
  {"id": "SCS", "name": "Sustainable Cities and Society", "openalex_id": "S163634330", "issn": "2210-6707", "tier": 1, "tags": ["可持续", "城市"], "transfer_to": ""},
];

final List<Journal> cepmJournals =
    _cepmJournalData.map((j) => Journal.fromJson(j)).toList();

Map<String, Journal> get cepmJournalMap =>
    {for (final j in cepmJournals) j.id: j};
