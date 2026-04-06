import 'dart:convert';
import 'dart:async';
import 'package:http/http.dart' as http;

class TranslationService {
  String _apiKey;
  String _baseUrl;
  String _model;

  TranslationService({
    String apiKey = '',
    String baseUrl = 'https://api.chatanywhere.tech/v1',
    String model = 'gpt-4o-mini',
  })  : _apiKey = apiKey,
        _baseUrl = baseUrl,
        _model = model;

  bool get isConfigured => _apiKey.isNotEmpty;

  void updateConfig({String? apiKey, String? baseUrl, String? model}) {
    if (apiKey != null) _apiKey = apiKey;
    if (baseUrl != null) _baseUrl = baseUrl;
    if (model != null) _model = model;
  }

  /// Translate a batch of texts to Chinese
  /// Returns a list of translated texts in the same order
  Future<List<String>> translateBatch(
    List<String> texts, {
    int concurrency = 20,
    Function(int done, int total)? onProgress,
  }) async {
    if (!isConfigured) throw Exception('API key not configured');

    final results = List<String>.filled(texts.length, '');
    int done = 0;

    // Process in chunks with concurrency limit
    final futures = <Future>[];
    final semaphore = _Semaphore(concurrency);

    for (int i = 0; i < texts.length; i++) {
      final index = i;
      final text = texts[i];
      if (text.isEmpty) {
        results[index] = '';
        done++;
        onProgress?.call(done, texts.length);
        continue;
      }

      final future = semaphore.acquire().then((_) async {
        try {
          results[index] = await _translate(text);
        } catch (e) {
          results[index] = '[翻译失败]';
        } finally {
          semaphore.release();
          done++;
          onProgress?.call(done, texts.length);
        }
      });
      futures.add(future);
    }

    await Future.wait(futures);
    return results;
  }

  Future<String> _translate(String text) async {
    final url = Uri.parse('$_baseUrl/chat/completions');
    final resp = await http.post(
      url,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $_apiKey',
      },
      body: jsonEncode({
        'model': _model,
        'messages': [
          {
            'role': 'system',
            'content': '你是学术翻译助手。将以下英文学术文本翻译为中文，保持学术术语准确，语言流畅自然。只返回翻译结果，不加任何解释。',
          },
          {'role': 'user', 'content': text},
        ],
        'temperature': 0.3,
      }),
    );

    if (resp.statusCode != 200) {
      throw Exception('Translation API error: ${resp.statusCode}');
    }

    final data = jsonDecode(resp.body);
    return data['choices'][0]['message']['content'] as String;
  }
}

/// Simple semaphore for concurrency control
class _Semaphore {
  final int maxCount;
  int _currentCount = 0;
  final _waitQueue = <Completer<void>>[];

  _Semaphore(this.maxCount);

  Future<void> acquire() {
    if (_currentCount < maxCount) {
      _currentCount++;
      return Future.value();
    }
    final completer = Completer<void>();
    _waitQueue.add(completer);
    return completer.future;
  }

  void release() {
    if (_waitQueue.isNotEmpty) {
      final next = _waitQueue.removeAt(0);
      next.complete();
    } else {
      _currentCount--;
    }
  }
}
