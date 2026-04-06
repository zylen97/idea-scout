import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../data/journals.dart';
import '../models/journal.dart';
import '../models/paper.dart';
import '../services/openalex_service.dart';
import '../services/translation_service.dart';
import '../widgets/paper_card.dart';
import 'settings_screen.dart';
import 'paper_detail_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<Paper> _papers = [];
  List<Paper> _filteredPapers = [];
  bool _isLoading = false;
  bool _isTranslating = false;
  String _statusText = '';
  bool _showChinese = true;
  int _translateProgress = 0;
  int _translateTotal = 0;

  // Filters
  String _searchQuery = '';
  String? _selectedJournalId;
  int? _selectedTier;
  final _searchController = TextEditingController();

  late TranslationService _translationService;

  @override
  void initState() {
    super.initState();
    _translationService = TranslationService();
    _loadSavedData();
  }

  Future<void> _loadSavedData() async {
    final prefs = await SharedPreferences.getInstance();

    // Load API config
    final apiKey = prefs.getString('api_key') ?? '';
    final baseUrl =
        prefs.getString('api_base_url') ?? 'https://api.chatanywhere.tech/v1';
    final model = prefs.getString('api_model') ?? 'gpt-4o-mini';
    _translationService.updateConfig(
        apiKey: apiKey, baseUrl: baseUrl, model: model);

    // Load cached papers
    final cached = prefs.getString('cached_papers');
    if (cached != null) {
      try {
        final list = jsonDecode(cached) as List;
        setState(() {
          _papers = list.map((j) => Paper.fromJson(j)).toList();
          _applyFilters();
          _statusText = '已加载 ${_papers.length} 篇论文（缓存）';
        });
      } catch (_) {}
    }
  }

  Future<void> _savePapers() async {
    final prefs = await SharedPreferences.getInstance();
    final json = _papers.map((p) => p.toJson()).toList();
    await prefs.setString('cached_papers', jsonEncode(json));
  }

  void _applyFilters() {
    _filteredPapers = _papers.where((p) {
      if (_selectedTier != null && p.tier != _selectedTier) return false;
      if (_selectedJournalId != null && p.journalId != _selectedJournalId) {
        return false;
      }
      if (_searchQuery.isNotEmpty) {
        final q = _searchQuery.toLowerCase();
        return p.title.toLowerCase().contains(q) ||
            p.titleCn.toLowerCase().contains(q) ||
            p.abstract_.toLowerCase().contains(q) ||
            p.abstractCn.toLowerCase().contains(q) ||
            p.journalId.toLowerCase().contains(q);
      }
      return true;
    }).toList();
  }

  Future<void> _fetchPapers({List<Journal>? targetJournals}) async {
    setState(() {
      _isLoading = true;
      _statusText = '正在从 OpenAlex 获取论文...';
    });

    try {
      final targets = targetJournals ?? journals;
      final papers = await OpenAlexService.fetchMultipleJournals(
        targets,
        months: 3,
        onProgress: (id, count) {
          setState(() {
            if (count >= 0) {
              _statusText = '已获取 $id: $count 篇';
            } else {
              _statusText = '$id 获取失败';
            }
          });
        },
      );

      // Filter out papers without abstracts
      final withAbstract = papers.where((p) => p.abstract_.isNotEmpty).toList();

      setState(() {
        _papers = withAbstract;
        _applyFilters();
        _statusText = '获取完成：${withAbstract.length} 篇论文（${papers.length - withAbstract.length} 篇无摘要已过滤）';
      });

      await _savePapers();
    } catch (e) {
      setState(() {
        _statusText = '获取失败: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _translatePapers() async {
    if (!_translationService.isConfigured) {
      _showMessage('请先在设置中配置 API Key');
      return;
    }

    // Find papers that need translation
    final needTranslation =
        _papers.where((p) => p.titleCn.isEmpty && p.title.isNotEmpty).toList();

    if (needTranslation.isEmpty) {
      _showMessage('所有论文已翻译');
      return;
    }

    setState(() {
      _isTranslating = true;
      _translateProgress = 0;
      _translateTotal = needTranslation.length;
      _statusText = '正在翻译 0/$_translateTotal...';
    });

    try {
      // Translate titles
      final titles = needTranslation.map((p) => p.title).toList();
      final translatedTitles = await _translationService.translateBatch(
        titles,
        concurrency: 30,
        onProgress: (done, total) {
          setState(() {
            _translateProgress = done;
            _statusText = '翻译标题 $done/$total...';
          });
        },
      );

      for (int i = 0; i < needTranslation.length; i++) {
        needTranslation[i].titleCn = translatedTitles[i];
      }

      // Translate abstracts
      setState(() {
        _translateProgress = 0;
        _statusText = '翻译摘要 0/$_translateTotal...';
      });

      final abstracts = needTranslation.map((p) => p.abstract_).toList();
      final translatedAbstracts = await _translationService.translateBatch(
        abstracts,
        concurrency: 30,
        onProgress: (done, total) {
          setState(() {
            _translateProgress = done;
            _statusText = '翻译摘要 $done/$total...';
          });
        },
      );

      for (int i = 0; i < needTranslation.length; i++) {
        needTranslation[i].abstractCn = translatedAbstracts[i];
      }

      setState(() {
        _statusText = '翻译完成：${needTranslation.length} 篇';
        _applyFilters();
      });

      await _savePapers();
    } catch (e) {
      setState(() {
        _statusText = '翻译出错: $e';
      });
    } finally {
      setState(() {
        _isTranslating = false;
      });
    }
  }

  void _showMessage(String msg) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(msg)));
  }

  void _exportSelected() {
    final selected = _papers.where((p) => p.isSelected).toList();
    if (selected.isEmpty) {
      _showMessage('未选择任何论文');
      return;
    }

    final buffer = StringBuffer();
    for (final p in selected) {
      buffer.writeln('## ${p.titleCn.isNotEmpty ? p.titleCn : p.title}');
      buffer.writeln('**${p.title}**');
      buffer.writeln('${p.journalId} (T${p.tier}) | ${p.date}');
      if (p.doi.isNotEmpty) buffer.writeln(p.doi);
      buffer.writeln();
      if (p.abstractCn.isNotEmpty) {
        buffer.writeln(p.abstractCn);
      } else {
        buffer.writeln(p.abstract_);
      }
      buffer.writeln();
      buffer.writeln('---');
      buffer.writeln();
    }

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('已选 ${selected.length} 篇'),
        content: SizedBox(
          width: double.maxFinite,
          height: 400,
          child: SingleChildScrollView(
            child: SelectableText(
              buffer.toString(),
              style: const TextStyle(fontSize: 13),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('关闭'),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Column(
        children: [
          // Search bar
          TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: '搜索标题、摘要、期刊...',
              prefixIcon: const Icon(Icons.search, size: 20),
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(vertical: 10),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(24),
              ),
              suffixIcon: _searchQuery.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear, size: 18),
                      onPressed: () {
                        _searchController.clear();
                        setState(() {
                          _searchQuery = '';
                          _applyFilters();
                        });
                      },
                    )
                  : null,
            ),
            onChanged: (v) {
              setState(() {
                _searchQuery = v;
                _applyFilters();
              });
            },
          ),
          const SizedBox(height: 8),
          // Filter chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                // Tier filter
                ...[1, 2, 3].map(
                  (tier) => Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: FilterChip(
                      label: Text('T$tier'),
                      selected: _selectedTier == tier,
                      onSelected: (selected) {
                        setState(() {
                          _selectedTier = selected ? tier : null;
                          _applyFilters();
                        });
                      },
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                // Journal dropdown
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey[400]!),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: DropdownButton<String?>(
                    value: _selectedJournalId,
                    hint: const Text('期刊', style: TextStyle(fontSize: 13)),
                    underline: const SizedBox(),
                    isDense: true,
                    items: [
                      const DropdownMenuItem(
                          value: null, child: Text('全部期刊')),
                      ...journals.map(
                        (j) => DropdownMenuItem(
                          value: j.id,
                          child: Text('${j.id} (T${j.tier})',
                              style: const TextStyle(fontSize: 13)),
                        ),
                      ),
                    ],
                    onChanged: (v) {
                      setState(() {
                        _selectedJournalId = v;
                        _applyFilters();
                      });
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final selectedCount = _papers.where((p) => p.isSelected).length;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Idea Scout'),
        centerTitle: true,
        actions: [
          // Language toggle
          IconButton(
            icon: Icon(_showChinese ? Icons.translate : Icons.abc),
            tooltip: _showChinese ? '显示英文' : '显示中文',
            onPressed: () => setState(() => _showChinese = !_showChinese),
          ),
          // Settings
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => const SettingsScreen()),
              );
              // Reload config after settings change
              _loadSavedData();
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Status bar
          if (_statusText.isNotEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              color: Colors.grey[100],
              child: Row(
                children: [
                  if (_isLoading || _isTranslating)
                    const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  if (_isLoading || _isTranslating) const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _statusText,
                      style: TextStyle(fontSize: 12, color: Colors.grey[700]),
                    ),
                  ),
                  Text(
                    '${_filteredPapers.length}/${_papers.length}',
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
                ],
              ),
            ),
          if (_isTranslating && _translateTotal > 0)
            LinearProgressIndicator(
              value: _translateProgress / _translateTotal,
            ),

          // Filters
          _buildFilterBar(),

          // Paper list
          Expanded(
            child: _filteredPapers.isEmpty
                ? Center(
                    child: _papers.isEmpty
                        ? Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.article_outlined,
                                  size: 64, color: Colors.grey[400]),
                              const SizedBox(height: 16),
                              Text(
                                '点击下方按钮获取最新论文',
                                style: TextStyle(color: Colors.grey[600]),
                              ),
                            ],
                          )
                        : Text(
                            '无匹配结果',
                            style: TextStyle(color: Colors.grey[600]),
                          ),
                  )
                : ListView.builder(
                    itemCount: _filteredPapers.length,
                    itemBuilder: (ctx, i) {
                      final paper = _filteredPapers[i];
                      return PaperCard(
                        paper: paper,
                        showChinese: _showChinese,
                        onToggleSelect: () {
                          setState(() {
                            paper.isSelected = !paper.isSelected;
                          });
                          _savePapers();
                        },
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => PaperDetailScreen(
                                paper: paper,
                                showChinese: _showChinese,
                              ),
                            ),
                          );
                        },
                      );
                    },
                  ),
          ),
        ],
      ),

      // Bottom action bar
      bottomNavigationBar: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withValues(alpha: 0.3),
              blurRadius: 4,
              offset: const Offset(0, -1),
            ),
          ],
        ),
        child: SafeArea(
          child: Row(
            children: [
              // Fetch button
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _isLoading ? null : () => _fetchPapers(),
                  icon: const Icon(Icons.download, size: 18),
                  label: const Text('获取'),
                ),
              ),
              const SizedBox(width: 8),
              // Translate button
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _isTranslating || _papers.isEmpty
                      ? null
                      : _translatePapers,
                  icon: const Icon(Icons.translate, size: 18),
                  label: const Text('翻译'),
                ),
              ),
              const SizedBox(width: 8),
              // Export button
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: selectedCount > 0 ? _exportSelected : null,
                  icon: const Icon(Icons.file_copy_outlined, size: 18),
                  label: Text('导出($selectedCount)'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }
}
