import 'dart:convert';
import 'dart:html' as html;
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../data/journals.dart';
import '../data/cepm_journals.dart';
import '../data/source_config.dart';
import '../models/paper.dart';
import '../widgets/paper_card.dart';
import 'paper_detail_screen.dart';

// ──────────────────────────────────────────
// Date range filter options
// ──────────────────────────────────────────
enum DateRangeFilter { today, week, month, threeMonths, all }

// ──────────────────────────────────────────
// View mode
// ──────────────────────────────────────────
enum ViewMode { list, journalGroup }

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  // Source switcher
  DataSource _currentSource = DataSource.ft50;

  // Per-source state
  final Map<DataSource, List<Paper>> _papersBySource = {};
  final Map<DataSource, List<Paper>> _filteredBySource = {};
  final Map<DataSource, Set<String>> _deletedDoisBySource = {};
  final Map<DataSource, List<Map<String, dynamic>>> _ideaPapersBySource = {};
  final Map<DataSource, Set<String>> _readDoisBySource = {};

  // Convenience getters for current source
  List<Paper> get _papers => _papersBySource[_currentSource] ?? [];
  List<Paper> get _filteredPapers => _filteredBySource[_currentSource] ?? [];
  Set<String> get _deletedDois => _deletedDoisBySource[_currentSource] ?? {};
  List<Map<String, dynamic>> get _ideaPapers => _ideaPapersBySource[_currentSource] ?? [];
  Set<String> get _readDois => _readDoisBySource[_currentSource] ?? {};
  Set<String> get _ideaDois => _ideaPapers.map((p) => p['doi'] as String).toSet();

  bool _isLoading = true;
  String _statusText = '';
  bool _showChinese = true;
  String _scanDate = '';

  // Scan history
  List<Map<String, dynamic>> _scanHistory = [];

  String _searchQuery = '';
  String? _selectedJournalId;
  int? _selectedTier;
  final _searchController = TextEditingController();

  // Filters
  DateRangeFilter _dateRangeFilter = DateRangeFilter.all;
  ViewMode _viewMode = ViewMode.list;

  // GitHub sync
  String? _githubToken;
  String? _userStateSha; // SHA for GitHub API updates

  // Scan date grouping: which groups are expanded
  final Map<String, bool> _scanGroupExpanded = {};

  // Journal group view: which groups are expanded
  final Map<String, bool> _journalGroupExpanded = {};

  // Tab controller
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _statusText = '';
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      _githubToken = prefs.getString('github_token');

      // Load per-source local state
      for (final source in DataSource.values) {
        final prefix = source.stateKey;
        // Migrate old keys (no prefix) to ft50_ prefix
        if (source == DataSource.ft50) {
          final oldRead = prefs.getStringList('read_dois');
          if (oldRead != null && prefs.getStringList('ft50_read_dois') == null) {
            await prefs.setStringList('ft50_read_dois', oldRead);
            await prefs.remove('read_dois');
          }
          final oldDeleted = prefs.getStringList('deleted_dois');
          if (oldDeleted != null && prefs.getStringList('ft50_deleted_dois') == null) {
            await prefs.setStringList('ft50_deleted_dois', oldDeleted);
            await prefs.remove('deleted_dois');
          }
          final oldIdea = prefs.getString('idea_papers');
          if (oldIdea != null && prefs.getString('ft50_idea_papers') == null) {
            await prefs.setString('ft50_idea_papers', oldIdea);
            await prefs.remove('idea_papers');
          }
        }

        _readDoisBySource[source] = (prefs.getStringList('${prefix}_read_dois') ?? []).toSet();
        _deletedDoisBySource[source] = (prefs.getStringList('${prefix}_deleted_dois') ?? []).toSet();
        final ideaJson = prefs.getString('${prefix}_idea_papers');
        if (ideaJson != null) {
          _ideaPapersBySource[source] = List<Map<String, dynamic>>.from(
              jsonDecode(ideaJson) as List);
        } else {
          _ideaPapersBySource[source] = [];
        }
      }

      // Try to sync from GitHub (source of truth)
      await _syncFromGitHub();

      // Load papers for each source
      for (final source in DataSource.values) {
        List<dynamic> list;
        try {
          final resp = await http.get(Uri.parse(source.papersFile));
          if (resp.statusCode == 200) {
            list = jsonDecode(resp.body) as List;
          } else {
            throw Exception('${source.papersFile} not found');
          }
        } catch (_) {
          try {
            final resp = await http.get(Uri.parse(source.latestFile));
            if (resp.statusCode == 200) {
              list = jsonDecode(resp.body) as List;
            } else {
              list = [];
            }
          } catch (_) {
            list = [];
          }
        }

        final papers = list.map((j) => Paper.fromJson(j as Map<String, dynamic>)).toList();

        // Fill tier from journal registry
        final jMap = source == DataSource.ft50 ? journalMap : source == DataSource.cepm ? cepmJournalMap : <String, dynamic>{};
        for (final p in papers) {
          if (jMap.containsKey(p.journalId)) {
            p.tier = jMap[p.journalId]!.tier;
          }
        }

        _papersBySource[source] = papers;
      }

      // Load scan history (graceful fail)
      try {
        final histResp = await http.get(Uri.parse('data/scan_history.json'));
        if (histResp.statusCode == 200) {
          final histData =
              jsonDecode(histResp.body) as Map<String, dynamic>;
          _scanHistory = List<Map<String, dynamic>>.from(
              histData['scans'] as List? ?? []);
        }
      } catch (_) {}

      // Compute scan date for current source
      _updateScanDate();

      setState(() {
        _applyFilters();
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _statusText = 'Load failed: $e';
      });
    }
  }

  void _updateScanDate() {
    final papers = _papers;
    if (papers.isNotEmpty) {
      final dates = papers.map((p) => p.date).where((d) => d.isNotEmpty).toList();
      if (dates.isNotEmpty) {
        dates.sort();
        _scanDate = '${dates.first} ~ ${dates.last}';
        return;
      }
    }
    _scanDate = '';
  }

  // ──────────────────────────────────────────
  // GitHub API Sync
  // ──────────────────────────────────────────
  Future<void> _syncFromGitHub() async {
    if (_githubToken == null || _githubToken!.isEmpty) return;
    try {
      final resp = await http.get(
        Uri.parse(
            'https://api.github.com/repos/zylen97/idea-scout/contents/data/user_state.json'),
        headers: {
          'Authorization': 'Bearer $_githubToken',
          'Accept': 'application/vnd.github.v3+json',
        },
      );
      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body) as Map<String, dynamic>;
        _userStateSha = data['sha'] as String?;
        final content = utf8.decode(base64Decode(
            (data['content'] as String).replaceAll('\n', '')));
        final state = jsonDecode(content) as Map<String, dynamic>;

        // Detect format: nested (new) vs flat (old)
        if (state.containsKey('ft50')) {
          // New nested format
          for (final source in DataSource.values) {
            final key = source.stateKey;
            final sourceState = state[key] as Map<String, dynamic>? ?? {};
            _deletedDoisBySource[source] = Set<String>.from(
                (sourceState['deleted_dois'] as List?)?.cast<String>() ?? []);
            _ideaPapersBySource[source] = List<Map<String, dynamic>>.from(
                sourceState['idea_papers'] as List? ?? []);
          }
        } else {
          // Legacy flat format -> migrate to ft50
          _deletedDoisBySource[DataSource.ft50] = Set<String>.from(
              (state['deleted_dois'] as List?)?.cast<String>() ?? []);
          _ideaPapersBySource[DataSource.ft50] = List<Map<String, dynamic>>.from(
              state['idea_papers'] as List? ?? []);
          _deletedDoisBySource[DataSource.cepm] = {};
          _ideaPapersBySource[DataSource.cepm] = [];
        }

        // Save merged state locally
        await _saveLocalState();
      }
    } catch (e) {
      debugPrint('GitHub sync failed: $e');
    }
  }

  Future<void> _pushToGitHub() async {
    if (_githubToken == null || _githubToken!.isEmpty) return;
    try {
      final stateJson = jsonEncode({
        for (final source in DataSource.values)
          source.stateKey: {
            'deleted_dois': (_deletedDoisBySource[source] ?? {}).toList(),
            'idea_papers': _ideaPapersBySource[source] ?? [],
          },
      });
      final encoded = base64Encode(utf8.encode(stateJson));

      final body = {
        'message': 'sync user_state',
        'content': encoded,
        if (_userStateSha != null) 'sha': _userStateSha,
      };

      final resp = await http.put(
        Uri.parse(
            'https://api.github.com/repos/zylen97/idea-scout/contents/data/user_state.json'),
        headers: {
          'Authorization': 'Bearer $_githubToken',
          'Accept': 'application/vnd.github.v3+json',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(body),
      );

      if (resp.statusCode == 200 || resp.statusCode == 201) {
        final data = jsonDecode(resp.body) as Map<String, dynamic>;
        _userStateSha =
            (data['content'] as Map<String, dynamic>?)?['sha'] as String?;
      } else {
        debugPrint('GitHub push failed: ${resp.statusCode} ${resp.body}');
      }
    } catch (e) {
      debugPrint('GitHub push error: $e');
    }
  }

  Future<void> _saveLocalState() async {
    final prefs = await SharedPreferences.getInstance();
    for (final source in DataSource.values) {
      final prefix = source.stateKey;
      await prefs.setStringList('${prefix}_deleted_dois',
          (_deletedDoisBySource[source] ?? {}).toList());
      await prefs.setString('${prefix}_idea_papers',
          jsonEncode(_ideaPapersBySource[source] ?? []));
    }
  }

  Future<void> _markAsRead(String doi) async {
    final readSet = _readDoisBySource[_currentSource] ?? {};
    if (readSet.contains(doi)) return;
    readSet.add(doi);
    _readDoisBySource[_currentSource] = readSet;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('${_currentSource.stateKey}_read_dois', readSet.toList());
  }

  // ──────────────────────────────────────────
  // Actions: delete and idea
  // ──────────────────────────────────────────
  void _deletePaper(Paper paper) {
    setState(() {
      (_deletedDoisBySource[_currentSource] ??= {}).add(paper.doi);
      (_ideaPapersBySource[_currentSource] ?? []).removeWhere((p) => p['doi'] == paper.doi);
      _applyFilters();
    });
    _saveLocalState();
    _pushToGitHub();
  }

  void _addToIdea(Paper paper) {
    if (_ideaDois.contains(paper.doi)) return;
    final today = DateTime.now();
    final addedDate =
        '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';
    setState(() {
      (_ideaPapersBySource[_currentSource] ??= []).add(paper.toIdeaJson(addedDate));
    });
    _saveLocalState();
    _pushToGitHub();
  }

  void _removeFromIdea(String doi) {
    setState(() {
      (_ideaPapersBySource[_currentSource] ?? []).removeWhere((p) => p['doi'] == doi);
    });
    _saveLocalState();
    _pushToGitHub();
  }

  // ──────────────────────────────────────────
  // RIS Export
  // ──────────────────────────────────────────
  void _exportRis() {
    if (_ideaPapers.isEmpty) {
      _showMessage(_showChinese ? '暂无 Idea 论文' : 'No idea papers to export');
      return;
    }

    final buffer = StringBuffer();
    for (final p in _ideaPapers) {
      buffer.writeln('TY  - JOUR');
      buffer.writeln('TI  - ${p['title'] ?? ''}');
      final authors = p['authors'] as List? ?? [];
      for (final a in authors) {
        buffer.writeln('AU  - $a');
      }
      buffer.writeln('T2  - ${p['journal_name'] ?? ''}');
      final date = p['date'] as String? ?? '';
      if (date.isNotEmpty) {
        final parts = date.split('-');
        buffer.writeln('PY  - ${parts[0]}');
        buffer.writeln('DA  - ${date.replaceAll('-', '/')}');
      }
      final doi = p['doi'] as String? ?? '';
      if (doi.isNotEmpty) {
        final doiClean = doi.replaceFirst('https://doi.org/', '');
        buffer.writeln('DO  - $doiClean');
      }
      final abstract_ = p['abstract'] as String? ?? '';
      if (abstract_.isNotEmpty) {
        buffer.writeln('AB  - $abstract_');
      }
      buffer.writeln('ER  - ');
      buffer.writeln();
    }

    final content = buffer.toString();
    final bytes = utf8.encode(content);
    final blob = html.Blob([bytes], 'application/x-research-info-systems');
    final url = html.Url.createObjectUrlFromBlob(blob);
    final filename = _currentSource == DataSource.cepm ? 'cepm_idea_papers.ris' : 'idea_papers.ris';
    final anchor = html.AnchorElement(href: url)
      ..setAttribute('download', filename)
      ..click();
    html.Url.revokeObjectUrl(url);
  }

  // ──────────────────────────────────────────
  // Token settings dialog
  // ──────────────────────────────────────────
  void _showTokenDialog() {
    final controller = TextEditingController(text: _githubToken ?? '');
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        backgroundColor: const Color(0xFFF5F3ED),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.settings, size: 20, color: Color(0xFF8B7355)),
                  SizedBox(width: 8),
                  Text(
                    'GitHub Token',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF2D2A26),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              const Text(
                'Set a GitHub personal access token to enable cross-device sync.',
                style: TextStyle(fontSize: 12, color: Color(0xFF9B9488)),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: controller,
                decoration: const InputDecoration(
                  hintText: 'ghp_...',
                  hintStyle: TextStyle(color: Color(0xFFB5AFA6)),
                ),
                style: const TextStyle(fontSize: 13, fontFamily: 'monospace'),
                obscureText: true,
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text('Cancel',
                        style: TextStyle(color: Color(0xFF9B9488))),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: () async {
                      final token = controller.text.trim();
                      final prefs = await SharedPreferences.getInstance();
                      if (token.isEmpty) {
                        await prefs.remove('github_token');
                        setState(() => _githubToken = null);
                      } else {
                        await prefs.setString('github_token', token);
                        setState(() => _githubToken = token);
                        // Trigger sync
                        _syncFromGitHub().then((_) {
                          if (mounted) {
                            setState(() => _applyFilters());
                            _showMessage('GitHub sync complete');
                          }
                        });
                      }
                      if (ctx.mounted) Navigator.pop(ctx);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF8B7355),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                    child: const Text('Save'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _applyFilters() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final deletedDois = _deletedDoisBySource[_currentSource] ?? {};
    final ideaDois = _ideaDois;

    _filteredBySource[_currentSource] = (_papersBySource[_currentSource] ?? []).where((p) {
      // Hide deleted and idea papers from pending
      if (deletedDois.contains(p.doi)) return false;
      if (ideaDois.contains(p.doi)) return false;

      if (_selectedTier != null && p.tier != _selectedTier) return false;
      if (_selectedJournalId != null && p.journalId != _selectedJournalId) {
        return false;
      }

      // Date range filter (based on publication date)
      if (_dateRangeFilter != DateRangeFilter.all && p.date.isNotEmpty) {
        final paperDate = DateTime.tryParse(p.date);
        if (paperDate != null) {
          switch (_dateRangeFilter) {
            case DateRangeFilter.today:
              if (paperDate.isBefore(today)) return false;
              break;
            case DateRangeFilter.week:
              if (paperDate
                  .isBefore(today.subtract(const Duration(days: 7)))) {
                return false;
              }
              break;
            case DateRangeFilter.month:
              if (paperDate
                  .isBefore(today.subtract(const Duration(days: 30)))) {
                return false;
              }
              break;
            case DateRangeFilter.threeMonths:
              if (paperDate
                  .isBefore(today.subtract(const Duration(days: 90)))) {
                return false;
              }
              break;
            case DateRangeFilter.all:
              break;
          }
        }
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

  // ──────────────────────────────────────────
  // Scan date grouping helpers
  // ──────────────────────────────────────────
  String _scanDateGroupLabel(String scanDate) {
    if (scanDate.isEmpty) return _showChinese ? '未分类' : 'Uncategorized';
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final parsed = DateTime.tryParse(scanDate);
    if (parsed == null) return scanDate;
    final sd = DateTime(parsed.year, parsed.month, parsed.day);
    final diff = today.difference(sd).inDays;
    if (diff == 0) return _showChinese ? '今日新增' : 'Today';
    if (diff == 1) return _showChinese ? '昨日' : 'Yesterday';
    if (diff <= 7) return _showChinese ? '本周' : 'This Week';
    return _showChinese ? '更早' : 'Earlier';
  }

  int _scanGroupOrder(String label) {
    if (label.contains('今日') || label == 'Today') return 0;
    if (label.contains('昨日') || label == 'Yesterday') return 1;
    if (label.contains('本周') || label == 'This Week') return 2;
    if (label.contains('更早') || label == 'Earlier') return 3;
    return 4;
  }

  /// Build scan-date grouped list items
  List<_ListItem> _buildScanDateGroupedItems() {
    final groups = <String, List<Paper>>{};
    for (final p in _filteredPapers) {
      final label = _scanDateGroupLabel(p.scanDate);
      groups.putIfAbsent(label, () => []).add(p);
    }

    final sortedKeys = groups.keys.toList()
      ..sort((a, b) => _scanGroupOrder(a).compareTo(_scanGroupOrder(b)));

    // Default: only "today" expanded
    for (final key in sortedKeys) {
      _scanGroupExpanded.putIfAbsent(
          key, () => key.contains('今日') || key == 'Today');
    }

    final items = <_ListItem>[];
    for (final key in sortedKeys) {
      final papers = groups[key]!;
      final unreadCount =
          papers.where((p) => !_readDois.contains(p.doi)).length;
      final isExpanded = _scanGroupExpanded[key] ?? false;
      items.add(_ListItem.header(
        label: key,
        count: papers.length,
        unreadCount: unreadCount,
        isExpanded: isExpanded,
      ));
      if (isExpanded) {
        for (final p in papers) {
          items.add(_ListItem.paper(p));
        }
      }
    }
    return items;
  }

  /// Build journal-grouped list items
  List<_ListItem> _buildJournalGroupedItems() {
    final tierGroups = <int, Map<String, List<Paper>>>{};
    for (final p in _filteredPapers) {
      tierGroups.putIfAbsent(p.tier, () => {});
      tierGroups[p.tier]!.putIfAbsent(p.journalName, () => []).add(p);
    }

    final sortedTiers = tierGroups.keys.toList()..sort();
    final items = <_ListItem>[];

    for (final tier in sortedTiers) {
      final journalMap_ = tierGroups[tier]!;
      final tierTotal =
          journalMap_.values.fold<int>(0, (s, l) => s + l.length);
      final tierKey = 'tier_$tier';
      _journalGroupExpanded.putIfAbsent(tierKey, () => true);
      final tierExpanded = _journalGroupExpanded[tierKey] ?? true;

      items.add(_ListItem.tierHeader(
          tier: tier, count: tierTotal, isExpanded: tierExpanded));

      if (tierExpanded) {
        final sortedJournals = journalMap_.keys.toList()..sort();
        for (final jName in sortedJournals) {
          final papers = journalMap_[jName]!;
          final jKey = 'journal_${tier}_$jName';
          _journalGroupExpanded.putIfAbsent(jKey, () => false);
          final jExpanded = _journalGroupExpanded[jKey] ?? false;

          items.add(_ListItem.journalHeader(
            journalName: jName,
            count: papers.length,
            isExpanded: jExpanded,
            groupKey: jKey,
          ));

          if (jExpanded) {
            for (final p in papers) {
              items.add(_ListItem.paper(p));
            }
          }
        }
      }
    }
    return items;
  }

  void _showMessage(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        behavior: SnackBarBehavior.floating,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  String _formatScanSummary(Map<String, dynamic> scan) {
    final fromDate = scan['from_date'] as String? ?? '';
    final toDate = scan['to_date'] as String? ?? '';
    final tiers = (scan['tiers'] as List?)
            ?.map((e) => _tierLabels[e] ?? '$e')
            .join('+') ??
        '';
    final count = scan['paper_count'] as int? ?? 0;

    String shortMonth(String dateStr) {
      if (dateStr.length < 7) return dateStr;
      final parts = dateStr.split('-');
      if (parts.length < 2) return dateStr;
      const months = [
        '', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
        'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
      ];
      final m = int.tryParse(parts[1]) ?? 0;
      final y = parts[0];
      return '${m > 0 && m <= 12 ? months[m] : parts[1]} $y';
    }

    return '${shortMonth(fromDate)}\u2013${shortMonth(toDate)} ($tiers, $count papers)';
  }

  @override
  Widget build(BuildContext context) {
    final ideaCount = _ideaPapers.length;

    return Scaffold(
      backgroundColor: const Color(0xFFE8E6DC),
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),

            // Source switcher
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: const BoxDecoration(
                color: Color(0xFFF0EEE6),
                border: Border(bottom: BorderSide(color: Color(0xFFD8D4CA))),
              ),
              child: Row(
                children: DataSource.values.map((source) {
                  final isActive = _currentSource == source;
                  final color = source == DataSource.cepm
                      ? const Color(0xFF2E7D6F)
                      : const Color(0xFF8B7355);
                  return Expanded(
                    child: GestureDetector(
                      onTap: () {
                        if (_currentSource == source) return;
                        setState(() {
                          _currentSource = source;
                          _selectedJournalId = null;
                          _selectedTier = null;
                          _updateScanDate();
                          _applyFilters();
                        });
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        decoration: BoxDecoration(
                          color: isActive ? color : Colors.transparent,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: isActive ? color : const Color(0xFFD8D4CA),
                          ),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          source.label,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: isActive ? Colors.white : const Color(0xFF6B6560),
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),

            // GitHub sync banner
            if (_githubToken == null || _githubToken!.isEmpty)
              GestureDetector(
                onTap: _showTokenDialog,
                child: Container(
                  width: double.infinity,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  decoration: const BoxDecoration(
                    color: Color(0xFFFAF6ED),
                    border: Border(
                      bottom: BorderSide(color: Color(0xFFD8D4CA)),
                    ),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.sync_disabled,
                          size: 14, color: Color(0xFFB8963E)),
                      SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          'Set GitHub token for cross-device sync',
                          style: TextStyle(
                            fontSize: 12,
                            color: Color(0xFFB8963E),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      Icon(Icons.arrow_forward_ios,
                          size: 12, color: Color(0xFFB8963E)),
                    ],
                  ),
                ),
              ),

            // Scan history bar
            if (!_isLoading && _scanHistory.isNotEmpty)
              Container(
                width: double.infinity,
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                decoration: const BoxDecoration(
                  color: Color(0xFFECE9E1),
                  border: Border(
                    bottom: BorderSide(color: Color(0xFFD8D4CA)),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.radar,
                        size: 14, color: Color(0xFF8B7355)),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'Scanned: ${_scanHistory.map(_formatScanSummary).join(' | ')}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF6B6560),
                          fontWeight: FontWeight.w500,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),

            // Tab bar
            if (!_isLoading)
              Container(
                decoration: const BoxDecoration(
                  color: Color(0xFFF0EEE6),
                  border: Border(
                    bottom: BorderSide(color: Color(0xFFD8D4CA)),
                  ),
                ),
                child: TabBar(
                  controller: _tabController,
                  labelColor: const Color(0xFF2D2A26),
                  unselectedLabelColor: const Color(0xFF9B9488),
                  labelStyle: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                  unselectedLabelStyle: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                  indicatorColor: const Color(0xFF8B7355),
                  indicatorWeight: 3,
                  tabs: [
                    Tab(
                      text: _showChinese
                          ? '待处理 (${_filteredPapers.length})'
                          : 'Pending (${_filteredPapers.length})',
                    ),
                    Tab(
                      text: _showChinese
                          ? 'Idea ($ideaCount)'
                          : 'Idea ($ideaCount)',
                    ),
                  ],
                ),
              ),

            if (_statusText.isNotEmpty)
              Container(
                width: double.infinity,
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                color: const Color(0xFFFAF0ED),
                child: Text(
                  _statusText,
                  style: const TextStyle(
                      fontSize: 12, color: Color(0xFFC25B3F)),
                ),
              ),

            Expanded(
              child: _isLoading
                  ? const Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          CircularProgressIndicator(
                              color: Color(0xFF8B7355)),
                          SizedBox(height: 16),
                          Text('Loading papers...',
                              style: TextStyle(color: Color(0xFF9B9488))),
                        ],
                      ),
                    )
                  : TabBarView(
                      controller: _tabController,
                      children: [
                        _buildPendingTab(),
                        _buildIdeaTab(),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }

  // ──────────────────────────────────────────
  // Pending Tab
  // ──────────────────────────────────────────
  Widget _buildPendingTab() {
    return Column(
      children: [
        // Paper count status bar
        if (_papers.isNotEmpty)
          Container(
            width: double.infinity,
            padding:
                const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            decoration: const BoxDecoration(
              border: Border(
                bottom: BorderSide(color: Color(0xFFD8D4CA)),
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 6,
                  height: 6,
                  decoration: const BoxDecoration(
                    color: Color(0xFF5A8A6A),
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '${_papers.length} papers  \u00b7  $_scanDate',
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF6B6560),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE8E6DC),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '${_filteredPapers.length}/${_papers.length}',
                    style: const TextStyle(
                      fontSize: 11,
                      color: Color(0xFF9B9488),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        _buildFilterBar(),
        Expanded(
          child: _filteredPapers.isEmpty
              ? _buildEmptyState()
              : _viewMode == ViewMode.journalGroup
                  ? _buildJournalGroupView()
                  : _buildFlatList(),
        ),
      ],
    );
  }

  // ──────────────────────────────────────────
  // Idea Tab
  // ──────────────────────────────────────────
  Widget _buildIdeaTab() {
    if (_ideaPapers.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.lightbulb_outline,
                size: 56, color: Color(0xFFC5BFB5)),
            const SizedBox(height: 20),
            Text(
              _showChinese ? '暂无 Idea 论文' : 'No idea papers yet',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: Color(0xFF2D2A26),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _showChinese
                  ? '在待处理列表中点击灯泡按钮\n将感兴趣的论文加入此处'
                  : 'Tap the lightbulb button on papers\nto add them here',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 14,
                color: Color(0xFF9B9488),
                height: 1.5,
              ),
            ),
          ],
        ),
      );
    }

    // Build Paper objects from idea data for display
    final ideaPaperObjects = _ideaPapers.map((p) {
      return Paper(
        id: '',
        title: p['title'] as String? ?? '',
        titleCn: p['title_cn'] as String? ?? '',
        abstract_: p['abstract'] as String? ?? '',
        abstractCn: p['abstract_cn'] as String? ?? '',
        doi: p['doi'] as String? ?? '',
        date: p['date'] as String? ?? '',
        journalId: p['journal_id'] as String? ?? '',
        journalName: p['journal_name'] as String? ?? '',
        tier: 3,
        topics: [],
        citedBy: 0,
        isOa: false,
        authors: (p['authors'] as List?)?.cast<String>() ?? [],
      );
    }).toList();

    // Fix tiers from journal registry
    final jMap = _currentSource == DataSource.ft50 ? journalMap : _currentSource == DataSource.cepm ? cepmJournalMap : <String, dynamic>{};
    for (final p in ideaPaperObjects) {
      if (jMap.containsKey(p.journalId)) {
        p.tier = jMap[p.journalId]!.tier;
      }
    }

    return Column(
      children: [
        // Export RIS button bar
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: const BoxDecoration(
            border: Border(
              bottom: BorderSide(color: Color(0xFFD8D4CA)),
            ),
          ),
          child: Row(
            children: [
              const Icon(Icons.lightbulb,
                  size: 16, color: Color(0xFFB8963E)),
              const SizedBox(width: 8),
              Text(
                '${_ideaPapers.length} ${_showChinese ? "篇" : "papers"}',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF2D2A26),
                ),
              ),
              const Spacer(),
              GestureDetector(
                onTap: _exportRis,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF8B7355),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.file_download_outlined,
                          size: 16, color: Colors.white),
                      const SizedBox(width: 6),
                      Text(
                        _showChinese ? '导出 RIS' : 'Export RIS',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.only(top: 4, bottom: 100),
            itemCount: ideaPaperObjects.length,
            itemBuilder: (ctx, i) {
              final paper = ideaPaperObjects[i];
              return PaperCard(
                paper: paper,
                showChinese: _showChinese,
                isRead: _readDois.contains(paper.doi),
                isIdeaZone: true,
                showTier: _currentSource.hasTiers,
                onRemoveFromIdea: () => _removeFromIdea(paper.doi),
                onTap: () async {
                  await _markAsRead(paper.doi);
                  if (!mounted) return;
                  setState(() {});
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => PaperDetailScreen(
                        paper: paper,
                        showChinese: _showChinese,
                        showTier: _currentSource.hasTiers,
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildJournalGroupView() {
    final items = _buildJournalGroupedItems();
    return ListView.builder(
      padding: const EdgeInsets.only(top: 4, bottom: 100),
      itemCount: items.length,
      itemBuilder: (ctx, i) {
        final item = items[i];
        if (item.type == _ItemType.tierHeader) {
          return _buildTierGroupHeader(item);
        }
        if (item.type == _ItemType.journalHeader) {
          return _buildJournalGroupHeader(item);
        }
        return _buildPaperItem(item.paper!);
      },
    );
  }

  Widget _buildFlatList() {
    return ListView.builder(
      padding: const EdgeInsets.only(top: 4, bottom: 100),
      itemCount: _filteredPapers.length,
      itemBuilder: (ctx, i) => _buildPaperItem(_filteredPapers[i]),
    );
  }

  Widget _buildPaperItem(Paper paper) {
    return PaperCard(
      paper: paper,
      showChinese: _showChinese,
      isRead: _readDois.contains(paper.doi),
      isInIdea: _ideaDois.contains(paper.doi),
      showTier: _currentSource.hasTiers,
      onDelete: () => _deletePaper(paper),
      onIdea: () => _addToIdea(paper),
      onTap: () async {
        await _markAsRead(paper.doi);
        if (!mounted) return;
        setState(() {});
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => PaperDetailScreen(
              paper: paper,
              showChinese: _showChinese,
              showTier: _currentSource.hasTiers,
            ),
          ),
        );
      },
    );
  }

  Widget _buildScanGroupHeader(_ListItem item) {
    final unreadStr = item.unreadCount > 0
        ? ', ${item.unreadCount}${_showChinese ? "未读" : " unread"}'
        : '';
    return GestureDetector(
      onTap: () {
        setState(() {
          _scanGroupExpanded[item.label] = !item.isExpanded;
        });
      },
      child: Container(
        margin: const EdgeInsets.fromLTRB(16, 12, 16, 4),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: const Color(0xFFECE9E1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFD8D4CA)),
        ),
        child: Row(
          children: [
            Icon(
              item.isExpanded
                  ? Icons.keyboard_arrow_down
                  : Icons.keyboard_arrow_right,
              size: 20,
              color: const Color(0xFF8B7355),
            ),
            const SizedBox(width: 8),
            Text(
              item.label,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: Color(0xFF2D2A26),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              '(${item.count}${_showChinese ? "篇" : ""}$unreadStr)',
              style: const TextStyle(
                fontSize: 12,
                color: Color(0xFF9B9488),
                fontWeight: FontWeight.w500,
              ),
            ),
            if (item.unreadCount > 0) ...[
              const Spacer(),
              Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  color: Color(0xFFC25B3F),
                  shape: BoxShape.circle,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildTierGroupHeader(_ListItem item) {
    const tierColors = {
      1: Color(0xFFC25B3F),
      2: Color(0xFFB8963E),
      3: Color(0xFF5A8A6A),
    };
    final color = tierColors[item.tier] ?? tierColors[3]!;
    final tierKey = 'tier_${item.tier}';

    return GestureDetector(
      onTap: () {
        setState(() {
          _journalGroupExpanded[tierKey] = !item.isExpanded;
        });
      },
      child: Container(
        margin: const EdgeInsets.fromLTRB(16, 12, 16, 4),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.25)),
        ),
        child: Row(
          children: [
            Icon(
              item.isExpanded
                  ? Icons.keyboard_arrow_down
                  : Icons.keyboard_arrow_right,
              size: 20,
              color: color,
            ),
            const SizedBox(width: 8),
            Text(
              '${_tierLabels[item.tier] ?? "C"} \u00b7 ${_tierFieldNames[item.tier] ?? ""}',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              '(${item.count}${_showChinese ? "篇" : ""})',
              style: TextStyle(
                fontSize: 12,
                color: color.withValues(alpha: 0.7),
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildJournalGroupHeader(_ListItem item) {
    return GestureDetector(
      onTap: () {
        setState(() {
          _journalGroupExpanded[item.groupKey!] = !item.isExpanded;
        });
      },
      child: Container(
        margin: const EdgeInsets.fromLTRB(32, 4, 16, 4),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: const Color(0xFFF5F3ED),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFFD8D4CA)),
        ),
        child: Row(
          children: [
            Icon(
              item.isExpanded
                  ? Icons.keyboard_arrow_down
                  : Icons.keyboard_arrow_right,
              size: 18,
              color: const Color(0xFF6B6560),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                item.journalName ?? '',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF2D2A26),
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 6),
            Text(
              '(${item.count}${_showChinese ? "篇" : ""})',
              style: const TextStyle(
                fontSize: 11,
                color: Color(0xFF9B9488),
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 12, 8),
      decoration: const BoxDecoration(
        color: Color(0xFFF0EEE6),
        border: Border(bottom: BorderSide(color: Color(0xFFD8D4CA))),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: const Color(0xFF8B7355),
              borderRadius: BorderRadius.circular(10),
            ),
            child:
                const Icon(Icons.explore, color: Colors.white, size: 20),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Idea Scout',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF2D2A26),
                  letterSpacing: -0.5,
                ),
              ),
              Text(
                _currentSource.subtitle,
                style: const TextStyle(
                  fontSize: 11,
                  color: Color(0xFF9B9488),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const Spacer(),
          // Settings (GitHub token)
          Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(10),
              onTap: _showTokenDialog,
              child: Container(
                width: 40,
                height: 40,
                alignment: Alignment.center,
                child: Icon(
                  Icons.settings_outlined,
                  size: 22,
                  color: _githubToken != null && _githubToken!.isNotEmpty
                      ? const Color(0xFF5A8A6A)
                      : const Color(0xFF6B6560),
                ),
              ),
            ),
          ),
          // Language toggle
          Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(10),
              onTap: () => setState(() => _showChinese = !_showChinese),
              child: Container(
                width: 40,
                height: 40,
                alignment: Alignment.center,
                child: Icon(
                  _showChinese ? Icons.translate : Icons.abc,
                  size: 22,
                  color: const Color(0xFF6B6560),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
      child: Column(
        children: [
          // Date range filter chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildDateChip(DateRangeFilter.today,
                    _showChinese ? '今日' : 'Today'),
                _buildDateChip(DateRangeFilter.week,
                    _showChinese ? '最近7天' : '7 Days'),
                _buildDateChip(DateRangeFilter.month,
                    _showChinese ? '本月' : 'Month'),
                _buildDateChip(DateRangeFilter.threeMonths,
                    _showChinese ? '近3月' : '3 Months'),
                _buildDateChip(
                    DateRangeFilter.all, _showChinese ? '全部' : 'All'),
              ],
            ),
          ),
          const SizedBox(height: 6),

          // Tier / journal / view toggle row
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                if (_currentSource.hasTiers)
                  ...[1, 2, 3].map((tier) => _buildTierChip(tier)),
                if (_currentSource.hasTiers)
                  const SizedBox(width: 8),
                _buildJournalDropdown(),
                const SizedBox(width: 8),
                _buildViewModeToggle(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDateChip(DateRangeFilter filter, String label) {
    final isActive = _dateRangeFilter == filter;
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: GestureDetector(
        onTap: () {
          setState(() {
            _dateRangeFilter = filter;
            _applyFilters();
          });
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: isActive
                ? const Color(0xFF8B7355)
                : const Color(0xFFF5F3ED),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isActive
                  ? const Color(0xFF8B7355)
                  : const Color(0xFFD8D4CA),
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: isActive ? Colors.white : const Color(0xFF6B6560),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildViewModeToggle() {
    final isGrouped = _viewMode == ViewMode.journalGroup;
    return GestureDetector(
      onTap: () {
        setState(() {
          _viewMode =
              isGrouped ? ViewMode.list : ViewMode.journalGroup;
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding:
            const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          color: isGrouped
              ? const Color(0xFF8B7355)
              : const Color(0xFFF5F3ED),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isGrouped
                ? const Color(0xFF8B7355)
                : const Color(0xFFD8D4CA),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isGrouped ? Icons.account_tree : Icons.view_list,
              size: 14,
              color: isGrouped ? Colors.white : const Color(0xFF6B6560),
            ),
            const SizedBox(width: 4),
            Text(
              isGrouped
                  ? (_showChinese ? '期刊' : 'Journal')
                  : (_showChinese ? '列表' : 'List'),
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color:
                    isGrouped ? Colors.white : const Color(0xFF6B6560),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static const _tierLabels = {1: 'A', 2: 'B', 3: 'C'};
  static const _ft50TierFieldNames = {
    1: 'Ops & IS',
    2: 'Econ & Strategy',
    3: 'Org & Mgmt',
  };
  static const _cnkiTierFieldNames = {
    1: '管理A',
    2: '管理B1',
    3: 'B2/工程',
  };
  Map<int, String> get _tierFieldNames =>
      _currentSource.isCnki ? _cnkiTierFieldNames : _ft50TierFieldNames;

  Widget _buildTierChip(int tier) {
    final isSelected = _selectedTier == tier;
    final colors = {
      1: const Color(0xFFC25B3F),
      2: const Color(0xFFB8963E),
      3: const Color(0xFF5A8A6A),
    };
    final color = colors[tier]!;
    final currentPapers = _papersBySource[_currentSource] ?? [];
    final deletedDois = _deletedDoisBySource[_currentSource] ?? {};
    final count = currentPapers
        .where((p) =>
            p.tier == tier &&
            !deletedDois.contains(p.doi) &&
            !_ideaDois.contains(p.doi))
        .length;
    final label = _tierLabels[tier] ?? 'C';

    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: GestureDetector(
        onTap: () {
          setState(() {
            _selectedTier = isSelected ? null : tier;
            _applyFilters();
          });
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding:
              const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: isSelected ? color : const Color(0xFFF5F3ED),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isSelected ? color : const Color(0xFFD8D4CA),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: isSelected
                      ? Colors.white
                      : const Color(0xFF6B6560),
                ),
              ),
              if (count > 0) ...[
                const SizedBox(width: 4),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 4, vertical: 1),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? Colors.white.withValues(alpha: 0.25)
                        : const Color(0xFFECE9E1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    '$count',
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                      color: isSelected
                          ? Colors.white
                          : const Color(0xFF9B9488),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  List<DropdownMenuItem<String>> _cnkiJournalItems() {
    final papers = _papersBySource[DataSource.cnki] ?? [];
    final journalMap_ = <String, String>{};
    for (final p in papers) {
      journalMap_.putIfAbsent(p.journalId, () => p.journalName);
    }
    final sorted = journalMap_.entries.toList()..sort((a, b) => a.value.compareTo(b.value));
    return sorted.map((e) => DropdownMenuItem(
      value: e.key,
      child: Text(e.value, style: const TextStyle(fontSize: 13)),
    )).toList();
  }

  Widget _buildJournalDropdown() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: _selectedJournalId != null
            ? const Color(0xFFECE9E1)
            : const Color(0xFFF5F3ED),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: _selectedJournalId != null
              ? const Color(0xFF8B7355).withValues(alpha: 0.4)
              : const Color(0xFFD8D4CA),
        ),
      ),
      child: DropdownButton<String?>(
        value: _selectedJournalId,
        hint: Text(_showChinese ? '全部' : 'All',
            style: const TextStyle(
                fontSize: 13, color: Color(0xFF9B9488))),
        underline: const SizedBox(),
        isDense: true,
        icon: const Icon(Icons.keyboard_arrow_down,
            size: 18, color: Color(0xFF9B9488)),
        items: [
          DropdownMenuItem(
              value: null,
              child: Text(_showChinese ? '全部' : 'All')),
          if (_currentSource.isCnki)
            ..._cnkiJournalItems()
          else
            ...(_currentSource == DataSource.cepm ? cepmJournals : journals).map(
              (j) => DropdownMenuItem(
                value: j.id,
                child: Text('${j.id} - ${j.name}',
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
    );
  }

  Widget _buildEmptyState() {
    if (_papers.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off,
                size: 56, color: Color(0xFFC5BFB5)),
            const SizedBox(height: 20),
            Text(
              _showChinese ? '暂无数据' : 'No data available',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: Color(0xFF2D2A26),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _showChinese
                  ? '在 Claude Code 中运行 /idea-scout\n来生成数据'
                  : 'Run /idea-scout in Claude Code\nto generate data',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 14,
                color: Color(0xFF9B9488),
                height: 1.5,
              ),
            ),
          ],
        ),
      );
    }
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.search_off,
              size: 48, color: Color(0xFFC5BFB5)),
          const SizedBox(height: 12),
          Text(
            _showChinese ? '无匹配结果' : 'No matching results',
            style: const TextStyle(
                color: Color(0xFF9B9488), fontSize: 15),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    _tabController.dispose();
    super.dispose();
  }
}

// ──────────────────────────────────────────
// List item types for grouped views
// ──────────────────────────────────────────
enum _ItemType { paper, scanHeader, tierHeader, journalHeader }

class _ListItem {
  final _ItemType type;
  final Paper? paper;
  final String label;
  final int count;
  final int unreadCount;
  final bool isExpanded;
  final int tier;
  final String? journalName;
  final String? groupKey;

  const _ListItem._({
    required this.type,
    this.paper,
    this.label = '',
    this.count = 0,
    this.unreadCount = 0,
    this.isExpanded = false,
    this.tier = 0,
    this.journalName,
    this.groupKey,
  });

  factory _ListItem.paper(Paper p) =>
      _ListItem._(type: _ItemType.paper, paper: p);

  factory _ListItem.header({
    required String label,
    required int count,
    required int unreadCount,
    required bool isExpanded,
  }) =>
      _ListItem._(
        type: _ItemType.scanHeader,
        label: label,
        count: count,
        unreadCount: unreadCount,
        isExpanded: isExpanded,
      );

  factory _ListItem.tierHeader({
    required int tier,
    required int count,
    required bool isExpanded,
  }) =>
      _ListItem._(
        type: _ItemType.tierHeader,
        tier: tier,
        count: count,
        isExpanded: isExpanded,
      );

  factory _ListItem.journalHeader({
    required String journalName,
    required int count,
    required bool isExpanded,
    required String groupKey,
  }) =>
      _ListItem._(
        type: _ItemType.journalHeader,
        journalName: journalName,
        count: count,
        isExpanded: isExpanded,
        groupKey: groupKey,
      );
}
