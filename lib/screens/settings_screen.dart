import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _apiKeyController = TextEditingController();
  final _baseUrlController = TextEditingController();
  final _modelController = TextEditingController();
  bool _obscureKey = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    _apiKeyController.text = prefs.getString('api_key') ?? '';
    _baseUrlController.text =
        prefs.getString('api_base_url') ?? 'https://api.chatanywhere.tech/v1';
    _modelController.text = prefs.getString('api_model') ?? 'gpt-4o-mini';
    setState(() {});
  }

  Future<void> _saveSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('api_key', _apiKeyController.text.trim());
    await prefs.setString('api_base_url', _baseUrlController.text.trim());
    await prefs.setString('api_model', _modelController.text.trim());

    if (mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('设置已保存')));
    }
  }

  Future<void> _clearCache() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('cached_papers');
    if (mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('缓存已清除')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('设置'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            '翻译 API 配置',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            '使用 OpenAI 兼容接口翻译摘要为中文',
            style: TextStyle(color: Colors.grey[600], fontSize: 13),
          ),
          const SizedBox(height: 16),

          // API Key
          TextField(
            controller: _apiKeyController,
            obscureText: _obscureKey,
            decoration: InputDecoration(
              labelText: 'API Key',
              border: const OutlineInputBorder(),
              suffixIcon: IconButton(
                icon: Icon(
                    _obscureKey ? Icons.visibility_off : Icons.visibility),
                onPressed: () =>
                    setState(() => _obscureKey = !_obscureKey),
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Base URL
          TextField(
            controller: _baseUrlController,
            decoration: const InputDecoration(
              labelText: 'Base URL',
              border: OutlineInputBorder(),
              hintText: 'https://api.chatanywhere.tech/v1',
            ),
          ),
          const SizedBox(height: 12),

          // Model
          TextField(
            controller: _modelController,
            decoration: const InputDecoration(
              labelText: 'Model',
              border: OutlineInputBorder(),
              hintText: 'gpt-4o-mini',
            ),
          ),
          const SizedBox(height: 20),

          ElevatedButton(
            onPressed: _saveSettings,
            child: const Text('保存设置'),
          ),

          const Divider(height: 40),

          const Text(
            '数据管理',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),

          OutlinedButton.icon(
            onPressed: _clearCache,
            icon: const Icon(Icons.delete_outline),
            label: const Text('清除论文缓存'),
            style: OutlinedButton.styleFrom(foregroundColor: Colors.red),
          ),

          const SizedBox(height: 24),

          // About
          const Text(
            '关于',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            'Idea Scout v1.0.0\n'
            '扫描 28 本 FT50/UTD24 顶级期刊最新论文\n'
            '发现可迁移到工程管理领域的研究思路\n\n'
            '数据来源: OpenAlex API (免费开放)\n'
            '翻译: OpenAI 兼容接口 (需自行配置)',
            style: TextStyle(color: Colors.grey[600], fontSize: 13, height: 1.6),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _apiKeyController.dispose();
    _baseUrlController.dispose();
    _modelController.dispose();
    super.dispose();
  }
}
