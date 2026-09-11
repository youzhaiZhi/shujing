import 'dart:convert';

import '../data/models.dart';

/// 净化引擎：按启用顺序逐行应用替换规则，清洗正文广告/水印
class Replacer {
  Replacer._();
  static final Replacer instance = Replacer._();

  List<RegExp> _patterns = const [];
  List<String> _replacements = const [];

  void update(List<ReplaceRule> rules) {
    final pats = <RegExp>[];
    final reps = <String>[];
    for (final r in rules) {
      if (!r.enabled || r.pattern.isEmpty) continue;
      for (final p in _patternsOf(r)) {
        pats.add(p);
        reps.add(r.replacement);
      }
    }
    _patterns = pats;
    _replacements = reps;
  }

  bool get hasRules => _patterns.isNotEmpty;

  String clean(String text) {
    if (_patterns.isEmpty || text.isEmpty) return text;
    final out = <String>[];
    for (var line in text.split('\n')) {
      for (var i = 0; i < _patterns.length; i++) {
        line = line.replaceAllMapped(
            _patterns[i], (m) => _expand(m, _replacements[i]));
      }
      out.add(line);
    }
    var s = out.join('\n');
    s = s.replaceAll(RegExp(r'\n{3,}'), '\n\n');
    return s.trim();
  }

  static String _expand(Match m, String template) {
    var r = template;
    for (var g = m.groupCount; g >= 1; g--) {
      r = r.replaceAll('\$$g', m.group(g) ?? '');
    }
    return r;
  }

  /// 单条规则可含多个 pattern（阅读格式：`正则1##正则2` 或换行分隔）
  static List<RegExp> _patternsOf(ReplaceRule r) {
    final raw = r.pattern
        .split(RegExp(r'##|\r?\n'))
        .where((p) => p.trim().isNotEmpty)
        .toList();
    final out = <RegExp>[];
    for (final p in raw) {
      if (r.isRegex) {
        try {
          out.add(RegExp(p, multiLine: true));
        } catch (_) {
          out.add(RegExp(RegExp.escape(p)));
        }
      } else {
        out.add(RegExp(RegExp.escape(p)));
      }
    }
    return out;
  }

  /// 导出为阅读3.0 兼容 JSON（字段名对齐）
  static String exportJson(List<ReplaceRule> rules) => jsonEncode([
        for (final r in rules)
          {
            'id': r.id,
            'name': r.name,
            'rule': r.pattern,
            'replacement': r.replacement,
            'isRegex': r.isRegex,
            'isEnabled': r.enabled,
            'scope': '',
          }
      ]);

  /// 导入：兼容阅读3.0（rule 字段）与书径格式（pattern 字段）
  static List<ReplaceRule> parseImport(String content) {
    final decoded = jsonDecode(content);
    final list = decoded is List ? decoded : [decoded];
    return list.whereType<Map<String, dynamic>>().map((j) {
      final pattern =
          (j['pattern'] ?? j['rule'] ?? j['regex'] ?? '').toString();
      return ReplaceRule(
        name: (j['name'] ?? '未命名').toString(),
        pattern: pattern,
        replacement: (j['replacement'] ?? '').toString(),
        isRegex: j['isRegex'] != false,
        enabled: j['isEnabled'] != false && j['enabled'] != false,
      );
    }).where((r) => r.pattern.isNotEmpty).toList();
  }

  /// 预置规则（参考阅读社区常见净化正则）
  static const presets = <ReplaceRule>[
    ReplaceRule(
      name: '清理"请收藏本站"类引导',
      pattern:
          r'^.*?(请收藏本站|最新章节！|天才一秒记住|笔趣阁|手机版阅读网址|地址[：:].{6,}).*$',
    ),
    ReplaceRule(
      name: '清理"本章完"',
      pattern:
          r'^\s*[(（][^()（）]*(本章完|内容未完|未完待续)[^()（）]*[)）]\s*$',
    ),
    ReplaceRule(
      name: '清理含网址的广告行',
      pattern: r'^.*?(https?://|www\.|\.com|\.net|\.cc)\S*.*$',
    ),
    ReplaceRule(
      name: '清理"求收藏/求月票"',
      pattern:
          r'^\s*(各位书友要是觉得|如果觉得.*不错|请.*支持.*收藏|求月票|求推荐票|求打赏|记住本站).*$',
    ),
    ReplaceRule(
      name: '去除行尾空白',
      pattern: r'[ \t]+$',
      isRegex: true,
    ),
  ];
}
