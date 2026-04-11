import '../models/journal.dart';

const String openalexMailto = 'zylenw97@usts.edu.cn';

const List<Map<String, dynamic>> _journalData = [
  {"id": "MS", "name": "Management Science", "openalex_id": "S33323087", "issn": "0025-1909", "tier": 1, "tags": ["博弈论", "优化", "决策", "机制设计"], "transfer_to": "工程合同/激励/项目决策"},
  {"id": "OR", "name": "Operations Research", "openalex_id": "S125775545", "issn": "0030-364X", "tier": 1, "tags": ["网络优化", "调度", "鲁棒优化"], "transfer_to": "施工调度/资源分配/供应链"},
  {"id": "MSOM", "name": "Manufacturing & Service Operations Management", "openalex_id": "S81410195", "issn": "1523-4614", "tier": 1, "tags": ["供应链博弈", "服务运营", "平台"], "transfer_to": "建筑供应链/项目交付"},
  {"id": "POM", "name": "Production and Operations Management", "openalex_id": "S149070780", "issn": "1059-1478", "tier": 1, "tags": ["生产系统", "运营优化"], "transfer_to": "预制建筑/施工生产"},
  {"id": "JOM", "name": "Journal of Operations Management", "openalex_id": "S142306484", "issn": "0272-6963", "tier": 1, "tags": ["运营管理", "韧性", "供应链"], "transfer_to": "项目管理"},
  {"id": "ISR", "name": "Information Systems Research", "openalex_id": "S202812398", "issn": "1047-7047", "tier": 1, "tags": ["平台", "数字化", "AI采纳"], "transfer_to": "智能建造/BIM"},
  {"id": "MISQ", "name": "MIS Quarterly", "openalex_id": "S57293258", "issn": "0276-7783", "tier": 1, "tags": ["信息系统", "技术采纳"], "transfer_to": "建筑信息化"},
  {"id": "SMJ", "name": "Strategic Management Journal", "openalex_id": "S102949365", "issn": "0143-2095", "tier": 2, "tags": ["竞合策略", "资源基础观", "联盟"], "transfer_to": "工程企业战略/项目联盟"},
  {"id": "OS", "name": "Organization Science", "openalex_id": "S206124708", "issn": "1047-7039", "tier": 3, "tags": ["组织网络", "协调机制"], "transfer_to": "项目组织/利益相关方治理"},
  {"id": "AMJ", "name": "Academy of Management Journal", "openalex_id": "S117778295", "issn": "0001-4273", "tier": 3, "tags": ["实证方法", "组织行为"], "transfer_to": "工程团队/领导力"},
  {"id": "RP", "name": "Research Policy", "openalex_id": "S9731383", "issn": "0048-7333", "tier": 2, "tags": ["创新扩散", "技术采纳", "政策"], "transfer_to": "建筑业技术变革"},
  {"id": "JMS", "name": "Journal of Management Studies", "openalex_id": "S151705444", "issn": "0022-2380", "tier": 3, "tags": ["制度理论", "跨层分析"], "transfer_to": "建筑业制度环境"},
  {"id": "JSCM", "name": "Journal of Supply Chain Management", "openalex_id": "S59007373", "issn": "1523-2409", "tier": 1, "tags": ["供应链治理", "采购"], "transfer_to": "建筑供应链"},
  {"id": "JBE", "name": "Journal of Business Ethics", "openalex_id": "S76633192", "issn": "0167-4544", "tier": 3, "tags": ["商业伦理", "ESG", "可持续", "利益相关方"], "transfer_to": "工程伦理/ESG/可持续建筑"},
  {"id": "AER", "name": "American Economic Review", "openalex_id": "S23254222", "issn": "0002-8282", "tier": 2, "tags": ["机制设计", "公共经济学", "博弈论"], "transfer_to": "工程公共政策/激励机制"},

  {"id": "JIBS", "name": "Journal of International Business Studies", "openalex_id": "S38024979", "issn": "0047-2506", "tier": 2, "tags": ["跨国运营", "制度距离", "国际化"], "transfer_to": "国际工程项目"},

  {"id": "AMR", "name": "Academy of Management Review", "openalex_id": "S46763546", "issn": "0363-7425", "tier": 3, "tags": ["理论构建", "概念框架"], "transfer_to": "研究框架借鉴"},
  {"id": "ASQ", "name": "Administrative Science Quarterly", "openalex_id": "S143668711", "issn": "0001-8392", "tier": 3, "tags": ["深度案例", "定性方法"], "transfer_to": "工程案例研究"},
  {"id": "DS", "name": "Decision Sciences", "openalex_id": "S177792750", "issn": "0011-7315", "tier": 1, "tags": ["决策分析", "行为运筹"], "transfer_to": "工程决策"},
  {"id": "JBV", "name": "Journal of Business Venturing", "openalex_id": "S66201313", "issn": "0883-9026", "tier": 3, "tags": ["创业", "不确定性决策"], "transfer_to": "PPP/项目投资"},

  {"id": "JOM2", "name": "Journal of Management", "openalex_id": "S122767448", "issn": "0149-2063", "tier": 3, "tags": ["管理理论", "综述"], "transfer_to": "研究框架参考"},
  {"id": "OBHDP", "name": "Organizational Behavior and Human Decision Processes", "openalex_id": "S64744539", "issn": "0749-5978", "tier": 3, "tags": ["行为决策", "团队决策", "判断偏差"], "transfer_to": "工程项目决策行为"},
  {"id": "OrgStudies", "name": "Organization Studies", "openalex_id": "S28882882", "issn": "0170-8406", "tier": 3, "tags": ["组织理论", "制度逻辑", "实践理论"], "transfer_to": "建筑业组织/制度分析"},
  {"id": "JAP", "name": "Journal of Applied Psychology", "openalex_id": "S166002381", "issn": "0021-9010", "tier": 3, "tags": ["团队效能", "领导力", "安全行为"], "transfer_to": "施工安全行为/工程团队"},
  {"id": "HR", "name": "Human Relations", "openalex_id": "S61446109", "issn": "0018-7267", "tier": 3, "tags": ["工作关系", "组织公正", "员工行为"], "transfer_to": "工程项目劳动关系/组织公正"},
];

final List<Journal> journals =
    _journalData.map((j) => Journal.fromJson(j)).toList();

Map<String, Journal> get journalMap =>
    {for (final j in journals) j.id: j};
