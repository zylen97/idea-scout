import 'package:flutter/material.dart';
import '../models/paper.dart';

/// Predefined keywords for highlighting
const List<String> highlightKeywordsEn = [
  // Game theory & mechanism design
  'game theory', 'mechanism design', 'Nash', 'Stackelberg', 'equilibrium',
  'biform game', 'differential game', 'evolutionary game', 'cooperative game',
  'principal-agent', 'moral hazard', 'adverse selection', 'signaling',
  'contract', 'auction', 'incentive', 'bargaining',
  // Supply chain & operations
  'supply chain', 'procurement', 'logistics', 'scheduling', 'inventory',
  'coordination', 'disruption', 'resilience', 'lean construction',
  'prefabricated', 'modular construction', 'off-site',
  // Network & data
  'network', 'social network', 'centrality', 'Shapley', 'community detection',
  'SAOM', 'graph', 'knowledge graph',
  // Prediction & optimization
  'optimization', 'prediction', 'forecasting', 'machine learning', 'deep learning',
  'predict-then-optimize', 'end-to-end', 'decision-focused',
  'neural network', 'random forest', 'XGBoost', 'LSTM',
  // Digital & technology
  'digital transformation', 'digitalization', 'BIM', 'digital twin',
  'blockchain', 'IoT', 'artificial intelligence', 'smart construction',
  'automation', 'robotics', 'information system',
  // Sustainability & ESG
  'ESG', 'sustainability', 'sustainable development', 'carbon',
  'green', 'circular economy', 'climate', 'emission',
  'environmental disclosure', 'greenwashing', 'carbon label',
  'corporate social responsibility', 'CSR',
  // Construction & project management
  'construction', 'project management', 'contractor', 'stakeholder',
  'project delivery', 'PPP', 'risk', 'safety', 'accident',
  'cost overrun', 'delay', 'dispute', 'claim',
  'housing', 'affordable housing', 'infrastructure',
  // Organization & strategy
  'competitive advantage', 'innovation', 'collaboration', 'alliance',
  'organizational learning', 'knowledge transfer', 'improvisation',
  'team', 'leadership', 'trust', 'governance',
  // Quantitative methods
  'QCA', 'regression', 'panel data', 'causal inference',
  'difference-in-difference', 'instrumental variable',
  'Bayesian', 'Monte Carlo', 'simulation',
  // Platform & market
  'platform', 'two-sided market', 'matching', 'sharing economy',
  'SaaS', 'coopetition',
  // Disaster & emergency
  'disaster', 'hazard', 'emergency', 'earthquake', 'flood',
  'urban resilience', 'vulnerability',
];

const List<String> highlightKeywordsCn = [
  // 博弈论
  '博弈论', '博弈', '纳什', '斯塔克尔伯格', '均衡', '演化博弈', '微分博弈',
  '合作博弈', '机制设计', '委托代理', '信号博弈', '激励', '合同',
  // 供应链与运营
  '供应链', '采购', '物流', '调度', '协调', '中断', '韧性',
  '装配式', '预制', '模块化',
  // 网络与数据
  '网络', '社会网络', '中心性', 'Shapley', '知识图谱',
  // 预测与优化
  '优化', '预测', '机器学习', '深度学习', '神经网络',
  '端到端', '决策优化', '随机森林',
  // 数字化
  '数字化', '数字化转型', 'BIM', '数字孪生', '区块链',
  '人工智能', '智能建造', '自动化', '信息化', '物联网',
  // 可持续与ESG
  'ESG', '可持续', '碳排放', '碳标签', '绿色', '低碳',
  '环境信息披露', '漂绿', '循环经济', '社会责任',
  // 工程管理
  '工程管理', '项目管理', '承包商', '利益相关方',
  '施工', '安全', '事故', '风险', '延误', '超支',
  '保障性住房', '基础设施', 'PPP',
  // 组织与战略
  '竞争优势', '创新', '合作', '联盟', '组织学习',
  '知识转移', '即兴', '团队', '领导力', '信任', '治理',
  // 方法
  'QCA', '回归', '面板数据', '因果推断',
  '双重差分', '工具变量', '贝叶斯', '仿真', '模拟',
  // 平台
  '平台', '共享经济', '竞合',
  // 灾害
  '灾害', '应急', '地震', '洪水', '城市韧性', '脆弱性',
  // 城市与土地
  '城市', '土地利用', '智慧城市', '数据治理',
];

List<String> get allHighlightKeywords => [...highlightKeywordsEn, ...highlightKeywordsCn];

/// Build a TextSpan with keyword highlighting
TextSpan buildHighlightedText(String text, TextStyle baseStyle) {
  if (text.isEmpty) return TextSpan(text: text, style: baseStyle);

  // Sort keywords by length descending to match longer ones first
  final keywords = List<String>.from(allHighlightKeywords)
    ..sort((a, b) => b.length.compareTo(a.length));

  // Build regex pattern
  final pattern = keywords.map((k) => RegExp.escape(k)).join('|');
  final regex = RegExp('($pattern)', caseSensitive: false);

  final spans = <TextSpan>[];
  int lastEnd = 0;

  for (final match in regex.allMatches(text)) {
    if (match.start > lastEnd) {
      spans.add(TextSpan(text: text.substring(lastEnd, match.start)));
    }
    spans.add(TextSpan(
      text: match.group(0),
      style: baseStyle.copyWith(
        backgroundColor: const Color(0xFFFFF3CD),
        fontWeight: FontWeight.w600,
      ),
    ));
    lastEnd = match.end;
  }
  if (lastEnd < text.length) {
    spans.add(TextSpan(text: text.substring(lastEnd)));
  }

  return TextSpan(style: baseStyle, children: spans);
}

class PaperCard extends StatefulWidget {
  final Paper paper;
  final bool showChinese;
  final VoidCallback? onTap;
  final VoidCallback? onDelete;
  final VoidCallback? onIdea;
  final VoidCallback? onRemoveFromIdea;
  final bool isRead;
  final bool isInIdea;
  final bool isIdeaZone; // true when displayed in the Idea tab
  final bool showTier;

  const PaperCard({
    super.key,
    required this.paper,
    required this.showChinese,
    this.onTap,
    this.onDelete,
    this.onIdea,
    this.onRemoveFromIdea,
    this.isRead = false,
    this.isInIdea = false,
    this.isIdeaZone = false,
    this.showTier = true,
  });

  @override
  State<PaperCard> createState() => _PaperCardState();
}

class _PaperCardState extends State<PaperCard> {

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


  static String _tierLabel(int tier) {
    const labels = {1: 'A', 2: 'B', 3: 'C'};
    return labels[tier] ?? 'C';
  }


  @override
  Widget build(BuildContext context) {
    final paper = widget.paper;
    final tierColor = widget.showTier
        ? (_tierColors[paper.tier] ?? _tierColors[3]!)
        : const Color(0xFF6B5B4E);
    final tierBg = widget.showTier
        ? (_tierBgColors[paper.tier] ?? _tierBgColors[3]!)
        : const Color(0xFFF0EDE8);
    final title = widget.showChinese && paper.titleCn.isNotEmpty
        ? paper.titleCn
        : paper.title;
    final abstract_ = widget.showChinese && paper.abstractCn.isNotEmpty
        ? paper.abstractCn
        : paper.abstract_;

    final isRead = widget.isRead;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
      decoration: BoxDecoration(
        color: isRead
            ? const Color(0xFFF0EEE8)
            : const Color(0xFFF5F3ED),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFFD8D4CA),
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A000000),
            offset: Offset(0, 1),
            blurRadius: 3,
          ),
        ],
      ),
      child: Row(
        children: [
          // Left border accent for unread
          if (!isRead)
            Container(
              width: 4,
              height: 80,
              decoration: BoxDecoration(
                color: tierColor,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(16),
                  bottomLeft: Radius.circular(16),
                ),
              ),
            ),
          Expanded(
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: widget.onTap,
                child: Padding(
                  padding: EdgeInsets.fromLTRB(
                    isRead ? 16 : 12, 16, 16, 16,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header row
                      Row(
                        children: [
                          // Journal badge with inline category
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: tierColor,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              widget.showTier
                                  ? '${paper.journalName} · ${_tierLabel(paper.tier)}'
                                  : paper.journalName,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          // Date
                          Text(
                            paper.date,
                            style: TextStyle(
                              color: isRead
                                  ? const Color(0xFFB5AFA6)
                                  : const Color(0xFF9B9488),
                              fontSize: 12,
                            ),
                          ),
                          if (paper.isOa) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFFEDF5F0),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: const Text(
                                'OA',
                                style: TextStyle(
                                  color: Color(0xFF5A8A6A),
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                          const Spacer(),
                          // Action buttons
                          if (widget.isIdeaZone) ...[
                            // Idea zone: remove button
                            if (widget.onRemoveFromIdea != null)
                              GestureDetector(
                                onTap: widget.onRemoveFromIdea,
                                child: Container(
                                  margin: const EdgeInsets.only(right: 6),
                                  padding: const EdgeInsets.all(4),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFFAF0ED),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: const Icon(
                                    Icons.remove_circle_outline,
                                    size: 16,
                                    color: Color(0xFFC25B3F),
                                  ),
                                ),
                              ),
                          ] else ...[
                            // Pending zone: idea button + delete button
                            if (widget.onIdea != null)
                              GestureDetector(
                                onTap: widget.onIdea,
                                child: Container(
                                  margin: const EdgeInsets.only(right: 6),
                                  padding: const EdgeInsets.all(4),
                                  decoration: BoxDecoration(
                                    color: widget.isInIdea
                                        ? const Color(0xFFFAF6ED)
                                        : const Color(0xFFFAF6ED),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Icon(
                                    widget.isInIdea
                                        ? Icons.lightbulb
                                        : Icons.lightbulb_outline,
                                    size: 16,
                                    color: const Color(0xFFB8963E),
                                  ),
                                ),
                              ),
                            if (widget.onDelete != null)
                              GestureDetector(
                                onTap: widget.onDelete,
                                child: Container(
                                  margin: const EdgeInsets.only(right: 6),
                                  padding: const EdgeInsets.all(4),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFFAF0ED),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: const Icon(
                                    Icons.close_rounded,
                                    size: 16,
                                    color: Color(0xFFC25B3F),
                                  ),
                                ),
                              ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 12),

                      // Title with keyword highlighting
                      RichText(
                        text: buildHighlightedText(
                          title,
                          TextStyle(
                            fontSize: 15,
                            fontWeight: isRead ? FontWeight.w400 : FontWeight.w600,
                            height: 1.4,
                            color: isRead
                                ? const Color(0xFF6B6560)
                                : const Color(0xFF2D2A26),
                          ),
                        ),
                      ),

                      // Abstract preview with keyword highlighting
                      if (abstract_.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        RichText(
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                          text: buildHighlightedText(
                            abstract_,
                            TextStyle(
                              fontSize: 13,
                              color: isRead
                                  ? const Color(0xFF9B9488)
                                  : const Color(0xFF6B6560),
                              height: 1.6,
                            ),
                          ),
                        ),
                      ],

                      // Citations
                      if (paper.citedBy > 0) ...[
                        const SizedBox(height: 10),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: const Color(0xFFECE9E1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.format_quote_rounded,
                                  size: 12, color: Color(0xFF9B9488)),
                              const SizedBox(width: 3),
                              Text(
                                '${paper.citedBy}',
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: Color(0xFF6B6560),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
