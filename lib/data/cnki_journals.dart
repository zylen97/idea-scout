import '../models/journal.dart';

const List<Map<String, dynamic>> _cnkiJournalData = [
  // 管理A → tier 1
  {"id": "JJYJ", "name": "经济研究", "openalex_id": "", "issn": "", "tier": 1, "tags": <String>[], "transfer_to": ""},
  {"id": "JCYJ", "name": "管理科学学报", "openalex_id": "", "issn": "", "tier": 1, "tags": <String>[], "transfer_to": ""},
  {"id": "GLSJ", "name": "管理世界", "openalex_id": "", "issn": "", "tier": 1, "tags": <String>[], "transfer_to": ""},
  // 管理B1 → tier 2
  {"id": "XTLL", "name": "系统工程理论与实践", "openalex_id": "", "issn": "", "tier": 2, "tags": <String>[], "transfer_to": ""},
  {"id": "SLJY", "name": "数量经济技术经济研究", "openalex_id": "", "issn": "", "tier": 2, "tags": <String>[], "transfer_to": ""},
  {"id": "JRYJ", "name": "金融研究", "openalex_id": "", "issn": "", "tier": 2, "tags": <String>[], "transfer_to": ""},
  {"id": "ZGRK", "name": "中国软科学", "openalex_id": "", "issn": "", "tier": 2, "tags": <String>[], "transfer_to": ""},
  {"id": "ZGGK", "name": "中国管理科学", "openalex_id": "", "issn": "", "tier": 2, "tags": <String>[], "transfer_to": ""},
  {"id": "KJYJ", "name": "会计研究", "openalex_id": "", "issn": "", "tier": 2, "tags": <String>[], "transfer_to": ""},
  {"id": "WGJG", "name": "外国经济与管理", "openalex_id": "", "issn": "", "tier": 2, "tags": <String>[], "transfer_to": ""},
  {"id": "ZWGD", "name": "管理评论", "openalex_id": "", "issn": "", "tier": 2, "tags": <String>[], "transfer_to": ""},
  {"id": "LKGP", "name": "南开管理评论", "openalex_id": "", "issn": "", "tier": 2, "tags": <String>[], "transfer_to": ""},
  {"id": "KYGL", "name": "科研管理", "openalex_id": "", "issn": "", "tier": 2, "tags": <String>[], "transfer_to": ""},
  {"id": "GLGU", "name": "管理工程学报", "openalex_id": "", "issn": "", "tier": 2, "tags": <String>[], "transfer_to": ""},
  {"id": "XTGC", "name": "系统工程学报", "openalex_id": "", "issn": "", "tier": 2, "tags": <String>[], "transfer_to": ""},
  {"id": "XTGL", "name": "系统管理学报", "openalex_id": "", "issn": "", "tier": 2, "tags": <String>[], "transfer_to": ""},
  {"id": "GGGL", "name": "公共管理学报", "openalex_id": "", "issn": "", "tier": 2, "tags": <String>[], "transfer_to": ""},
  // 管理B2 → tier 3
  {"id": "JCJJ", "name": "管理科学", "openalex_id": "", "issn": "", "tier": 3, "tags": <String>[], "transfer_to": ""},
  {"id": "GLXB", "name": "管理学报", "openalex_id": "", "issn": "", "tier": 3, "tags": <String>[], "transfer_to": ""},
  {"id": "YCGL", "name": "运筹与管理", "openalex_id": "", "issn": "", "tier": 3, "tags": <String>[], "transfer_to": ""},
  {"id": "GCXT", "name": "系统工程", "openalex_id": "", "issn": "", "tier": 3, "tags": <String>[], "transfer_to": ""},
  {"id": "KZYC", "name": "控制与决策", "openalex_id": "", "issn": "", "tier": 3, "tags": <String>[], "transfer_to": ""},
  {"id": "STYS", "name": "系统科学与数学", "openalex_id": "", "issn": "", "tier": 3, "tags": <String>[], "transfer_to": ""},
  {"id": "YJYF", "name": "研究与发展管理", "openalex_id": "", "issn": "", "tier": 3, "tags": <String>[], "transfer_to": ""},
  {"id": "ZGRZ", "name": "中国人口·资源与环境", "openalex_id": "", "issn": "", "tier": 3, "tags": <String>[], "transfer_to": ""},
  {"id": "SLTJ", "name": "数理统计与管理", "openalex_id": "", "issn": "", "tier": 3, "tags": <String>[], "transfer_to": ""},
  {"id": "KXXG", "name": "科学学与科学技术管理", "openalex_id": "", "issn": "", "tier": 3, "tags": <String>[], "transfer_to": ""},
  {"id": "GGYY", "name": "中国工业经济", "openalex_id": "", "issn": "", "tier": 3, "tags": <String>[], "transfer_to": ""},
  {"id": "SJJJ", "name": "世界经济", "openalex_id": "", "issn": "", "tier": 3, "tags": <String>[], "transfer_to": ""},
  {"id": "JJDL", "name": "经济地理", "openalex_id": "", "issn": "", "tier": 3, "tags": <String>[], "transfer_to": ""},
  {"id": "CYJJ", "name": "产业经济研究", "openalex_id": "", "issn": "", "tier": 3, "tags": <String>[], "transfer_to": ""},
  {"id": "KXYJ", "name": "科学学研究", "openalex_id": "", "issn": "", "tier": 3, "tags": <String>[], "transfer_to": ""},
  {"id": "TJYJ", "name": "统计研究", "openalex_id": "", "issn": "", "tier": 3, "tags": <String>[], "transfer_to": ""},
  {"id": "TJLT", "name": "统计与信息论坛", "openalex_id": "", "issn": "", "tier": 3, "tags": <String>[], "transfer_to": ""},
  {"id": "XUXI", "name": "软科学", "openalex_id": "", "issn": "", "tier": 3, "tags": <String>[], "transfer_to": ""},
  // 工程 → tier 3
  {"id": "GYGC", "name": "工业工程与管理", "openalex_id": "", "issn": "", "tier": 3, "tags": <String>[], "transfer_to": ""},
  {"id": "JZJJ", "name": "建筑经济", "openalex_id": "", "issn": "", "tier": 3, "tags": <String>[], "transfer_to": ""},
  {"id": "GCZJ", "name": "工程造价管理", "openalex_id": "", "issn": "", "tier": 3, "tags": <String>[], "transfer_to": ""},
  {"id": "XMGJ", "name": "项目管理技术", "openalex_id": "", "issn": "", "tier": 3, "tags": <String>[], "transfer_to": ""},
  {"id": "TMGC", "name": "土木工程学报", "openalex_id": "", "issn": "", "tier": 3, "tags": <String>[], "transfer_to": ""},
  // 其他 → tier 3
  {"id": "ZHXU", "name": "灾害学", "openalex_id": "", "issn": "", "tier": 3, "tags": <String>[], "transfer_to": ""},
  {"id": "YSXT", "name": "交通运输系统工程与信息", "openalex_id": "", "issn": "", "tier": 3, "tags": <String>[], "transfer_to": ""},
  {"id": "DLXB", "name": "地理学报", "openalex_id": "", "issn": "", "tier": 3, "tags": <String>[], "transfer_to": ""},
];

final List<Journal> cnkiJournals =
    _cnkiJournalData.map((j) => Journal.fromJson(j)).toList();

Map<String, Journal> get cnkiJournalMap =>
    {for (final j in cnkiJournals) j.id: j};
