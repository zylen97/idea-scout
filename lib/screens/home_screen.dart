import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../data/journals.dart';
import '../models/paper.dart';
import '../widgets/paper_card.dart';
import 'paper_detail_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<Paper> _papers = [];
  List<Paper> _filteredPapers = [];
  bool _isLoading = true;
  String _statusText = '';
  bool _showChinese = true;
  String _scanDate = '';
  bool _showSelectedOnly = false;

  String _searchQuery = '';
  String? _selectedJournalId;
  int? _selectedTier;
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _statusText = '';
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      final savedSelections = prefs.getStringList('selected_ids') ?? [];

      final resp = await http.get(Uri.parse('data/latest.json'));
      if (resp.statusCode != 200) {
        throw Exception('HTTP ${resp.statusCode}');
      }

      final list = jsonDecode(resp.body) as List;
      final papers = list.map((j) => Paper.fromJson(j)).toList();

      // Fill in tier from journal registry if missing in data
      final jMap = journalMap;
      for (final p in papers) {
        if (p.tier == 3 && jMap.containsKey(p.journalId)) {
          p.tier = jMap[p.journalId]!.tier;
        }
        if (savedSelections.contains(p.doi)) {
          p.isSelected = true;
        }
      }

      if (papers.isNotEmpty) {
        final dates =
            papers.map((p) => p.date).where((d) => d.isNotEmpty).toList();
        if (dates.isNotEmpty) {
          dates.sort();
          _scanDate = '${dates.first} ~ ${dates.last}';
        }
      }

      setState(() {
        _papers = papers;
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

  Future<void> _saveSelections() async {
    final prefs = await SharedPreferences.getInstance();
    final selectedIds =
        _papers.where((p) => p.isSelected).map((p) => p.doi).toList();
    await prefs.setStringList('selected_ids', selectedIds);
  }

  void _applyFilters() {
    _filteredPapers = _papers.where((p) {
      if (_showSelectedOnly && !p.isSelected) return false;
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

  void _exportSelected() {
    final selected = _papers.where((p) => p.isSelected).toList();
    if (selected.isEmpty) {
      _showMessage('No papers selected');
      return;
    }

    final exportData = selected
        .map((p) => {
              'journal_id': p.journalId,
              'journal_name': p.journalName,
              'title': p.title,
              'title_cn': p.titleCn,
              'doi': p.doi,
              'date': p.date,
              'abstract': p.abstract_,
              'abstract_cn': p.abstractCn,
              'topics': p.topics,
              'tier': p.tier,
              'cited_by': p.citedBy,
              'oa': p.isOa,
              'pdf_url': p.pdfUrl,
            })
        .toList();

    final jsonStr = const JsonEncoder.withIndent('  ').convert(exportData);

    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: const Color(0xFFEEF2FF),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.file_copy_outlined,
                        size: 18, color: Color(0xFF6366F1)),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    '${selected.length} papers',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF1E293B),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              const Text(
                'Copy JSON → save as selected.json\nin idea_scout folder',
                style: TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
              ),
              const SizedBox(height: 16),
              Container(
                height: 320,
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                padding: const EdgeInsets.all(14),
                child: SingleChildScrollView(
                  child: SelectableText(
                    jsonStr,
                    style: const TextStyle(
                      fontSize: 12,
                      fontFamily: 'monospace',
                      height: 1.5,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(ctx),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF6366F1),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('Close'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showMessage(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final selectedCount = _papers.where((p) => p.isSelected).length;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),

            if (!_isLoading && _papers.isNotEmpty)
              Container(
                width: double.infinity,
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                color: const Color(0xFFF0FDF4),
                child: Row(
                  children: [
                    const Icon(Icons.check_circle_outline,
                        size: 14, color: Color(0xFF16A34A)),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        '${_papers.length} papers  ·  $_scanDate',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF166534),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.7),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '${_filteredPapers.length}/${_papers.length}',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey[600],
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

            if (_statusText.isNotEmpty)
              Container(
                width: double.infinity,
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                color: const Color(0xFFFEF2F2),
                child: Text(
                  _statusText,
                  style: const TextStyle(fontSize: 12, color: Color(0xFF991B1B)),
                ),
              ),

            if (!_isLoading) _buildFilterBar(),

            Expanded(
              child: _isLoading
                  ? const Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          CircularProgressIndicator(color: Color(0xFF6366F1)),
                          SizedBox(height: 16),
                          Text('Loading papers...',
                              style: TextStyle(color: Color(0xFF94A3B8))),
                        ],
                      ),
                    )
                  : _filteredPapers.isEmpty
                      ? _buildEmptyState()
                      : ListView.builder(
                          padding:
                              const EdgeInsets.only(top: 4, bottom: 100),
                          itemCount: _filteredPapers.length,
                          itemBuilder: (ctx, i) {
                            final paper = _filteredPapers[i];
                            return PaperCard(
                              paper: paper,
                              showChinese: _showChinese,
                              onToggleSelect: () {
                                setState(() =>
                                    paper.isSelected = !paper.isSelected);
                                _saveSelections();
                              },
                              onTap: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => PaperDetailScreen(
                                    paper: paper,
                                    showChinese: _showChinese,
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: _buildBottomBar(selectedCount),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 12, 8),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
              ),
              borderRadius: BorderRadius.circular(10),
            ),
            child:
                const Icon(Icons.explore, color: Colors.white, size: 20),
          ),
          const SizedBox(width: 12),
          const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Idea Scout',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF1E293B),
                  letterSpacing: -0.5,
                ),
              ),
              Text(
                'FT50 / UTD24 Journal Scanner',
                style: TextStyle(
                  fontSize: 11,
                  color: Color(0xFF94A3B8),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const Spacer(),
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
                  color: const Color(0xFF64748B),
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
          TextField(
            controller: _searchController,
            style: const TextStyle(fontSize: 14),
            decoration: InputDecoration(
              hintText: 'Search titles, abstracts, journals...',
              hintStyle:
                  const TextStyle(color: Color(0xFF94A3B8), fontSize: 14),
              prefixIcon: const Icon(Icons.search,
                  size: 20, color: Color(0xFF94A3B8)),
              suffixIcon: _searchQuery.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear,
                          size: 18, color: Color(0xFF94A3B8)),
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
          const SizedBox(height: 10),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                ...[1, 2, 3].map((tier) => _buildTierChip(tier)),
                const SizedBox(width: 8),
                _buildJournalDropdown(),
                if (_papers.any((p) => p.isSelected)) ...[
                  const SizedBox(width: 8),
                  _buildToggleChip(
                    label: 'Selected',
                    icon: Icons.star,
                    isActive: _showSelectedOnly,
                    activeColor: const Color(0xFF6366F1),
                    onTap: () {
                      setState(() {
                        _showSelectedOnly = !_showSelectedOnly;
                        _applyFilters();
                      });
                    },
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTierChip(int tier) {
    final isSelected = _selectedTier == tier;
    final colors = {
      1: const Color(0xFFEF4444),
      2: const Color(0xFFF59E0B),
      3: const Color(0xFF10B981),
    };
    final color = colors[tier]!;
    final count = _papers.where((p) => p.tier == tier).length;

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
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            color: isSelected ? color : Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isSelected ? color : const Color(0xFFE2E8F0),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'T$tier',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color:
                      isSelected ? Colors.white : const Color(0xFF475569),
                ),
              ),
              if (count > 0) ...[
                const SizedBox(width: 5),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? Colors.white.withValues(alpha: 0.25)
                        : const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(5),
                  ),
                  child: Text(
                    '$count',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color:
                          isSelected ? Colors.white : const Color(0xFF94A3B8),
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

  Widget _buildJournalDropdown() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: _selectedJournalId != null
            ? const Color(0xFFEEF2FF)
            : Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: _selectedJournalId != null
              ? const Color(0xFF6366F1).withValues(alpha: 0.3)
              : const Color(0xFFE2E8F0),
        ),
      ),
      child: DropdownButton<String?>(
        value: _selectedJournalId,
        hint: const Text('All',
            style: TextStyle(fontSize: 13, color: Color(0xFF94A3B8))),
        underline: const SizedBox(),
        isDense: true,
        icon: const Icon(Icons.keyboard_arrow_down,
            size: 18, color: Color(0xFF94A3B8)),
        items: [
          const DropdownMenuItem(value: null, child: Text('All')),
          ...journals.map(
            (j) => DropdownMenuItem(
              value: j.id,
              child: Text('${j.id}',
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

  Widget _buildToggleChip({
    required String label,
    required IconData icon,
    required bool isActive,
    required Color activeColor,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: isActive ? activeColor : Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isActive ? activeColor : const Color(0xFFE2E8F0),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon,
                size: 14,
                color: isActive ? Colors.white : const Color(0xFFF59E0B)),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: isActive ? Colors.white : const Color(0xFF475569),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    if (_papers.isEmpty) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.cloud_off, size: 56, color: Color(0xFFCBD5E1)),
            SizedBox(height: 20),
            Text(
              'No data available',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: Color(0xFF1E293B),
              ),
            ),
            SizedBox(height: 8),
            Text(
              'Run /idea-scout in Claude Code\nto generate data',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: Color(0xFF94A3B8),
                height: 1.5,
              ),
            ),
          ],
        ),
      );
    }
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.search_off, size: 48, color: Color(0xFFCBD5E1)),
          SizedBox(height: 12),
          Text('No matching results',
              style: TextStyle(color: Color(0xFF94A3B8), fontSize: 15)),
        ],
      ),
    );
  }

  Widget _buildBottomBar(int selectedCount) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Color(0xFFE2E8F0))),
      ),
      child: SafeArea(
        child: Row(
          children: [
            if (selectedCount > 0) ...[
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFFEEF2FF),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.check_circle,
                        size: 16, color: Color(0xFF6366F1)),
                    const SizedBox(width: 6),
                    Text(
                      '$selectedCount',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF6366F1),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: () {
                  setState(() {
                    for (final p in _papers) {
                      p.isSelected = false;
                    }
                    _showSelectedOnly = false;
                    _applyFilters();
                  });
                  _saveSelections();
                },
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.clear_all,
                      size: 20, color: Color(0xFF94A3B8)),
                ),
              ),
            ],
            const Spacer(),
            GestureDetector(
              onTap: selectedCount > 0 ? _exportSelected : null,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 11),
                decoration: BoxDecoration(
                  color: selectedCount > 0
                      ? const Color(0xFF6366F1)
                      : const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Icon(Icons.file_download_outlined,
                        size: 18,
                        color: selectedCount > 0
                            ? Colors.white
                            : const Color(0xFFCBD5E1)),
                    const SizedBox(width: 6),
                    Text(
                      'Export',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: selectedCount > 0
                            ? Colors.white
                            : const Color(0xFFCBD5E1),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
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
