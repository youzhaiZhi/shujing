import 'dart:convert';

import 'package:html/dom.dart' as dom;
import 'package:html/parser.dart' as html_parser;

import '../platform/js.dart' as js_platform;

/// 阅读3.0 规则引擎（子集，覆盖绝大多数书源）
/// 支持：
///   `//xpath`, `@@regex`, `$.json`, `@css:`, `text.`, `class.`, `id.`, `tag.`
///   拼接规则 `{{}}`, `<js>` 与 `@js:` 脚本
///   默认值 `##默认`, 过滤 `##正则##替换`
class RuleEngine {
  static final dynamic _js =
      js_platform.jsSupported ? js_platform.createJsRuntime() : null;

  /// 执行规则，返回字符串（第一个结果）
  static String optString(dynamic resp, String rule) {
    final r = optList(resp, rule);
    return r.isEmpty ? '' : r.first;
  }

  /// 执行规则，返回字符串列表
  static List<String> optList(dynamic resp, String rule) {
    if (rule.isEmpty) return [];
    final results = <String>[];
    for (final part in _splitRule(rule)) {
      final v = _evalOne(resp, part);
      results.addAll(v);
    }
    return results.where((e) => e.isNotEmpty).toList();
  }

  /// 执行规则，返回元素列表（用于 bookList/chapterList）
  static List<dynamic> optElements(dynamic resp, String rule) {
    if (rule.isEmpty) return [];
    var current = <dynamic>[resp];
    for (final part in _splitRule(rule)) {
      final next = <dynamic>[];
      for (final item in current) {
        next.addAll(_evalElements(item, part));
      }
      current = next;
    }
    return current;
  }

  /// 拆分规则：按 || 或 && 分段（简化：支持 || 多规则回退）
  static List<String> _splitRule(String rule) {
    // 先处理 JS 段，避免被 || 切断
    final parts = <String>[];
    var buf = StringBuffer();
    var depth = 0;
    for (var i = 0; i < rule.length; i++) {
      final c = rule[i];
      if (c == '{') depth++;
      if (c == '}') depth--;
      if (depth == 0 &&
          i + 1 < rule.length &&
          rule[i] == '|' &&
          rule[i + 1] == '|') {
        parts.add(buf.toString());
        buf = StringBuffer();
        i++;
        continue;
      }
      buf.write(c);
    }
    if (buf.isNotEmpty) parts.add(buf.toString());
    return parts.where((p) => p.isNotEmpty).toList();
  }

  static List<String> _evalOne(dynamic resp, String rule) {
    final els = _evalElements(resp, rule);
    return els.map((e) => e is dom.Element ? _textOf(e) : e.toString()).toList();
  }

  static String _textOf(dom.Element e) {
    final t = e.text.trim();
    if (t.isNotEmpty) return t;
    final attrs = ['content', 'href', 'src', 'data-url', 'value'];
    for (final a in attrs) {
      final v = e.attributes[a];
      if (v != null && v.isNotEmpty) return v;
    }
    return '';
  }

  static List<dynamic> _evalElements(dynamic resp, String rule) {
    rule = rule.trim();
    if (rule.isEmpty) return [resp];

    // <js>...</js> 或 @js:
    if (rule.startsWith('<js>') && rule.endsWith('</js>')) {
      final out = _runJs(rule.substring(4, rule.length - 5), resp);
      return out;
    }
    if (rule.startsWith('@js:')) {
      final out = _runJs(rule.substring(4), resp);
      return out;
    }

    // 默认值/替换： xxx##default 或 xxx##regex##replace
    var defaultVal = '';
    var replaceRegex = '';
    var replaceTo = '';
    final dd = _splitDoubleHash(rule);
    if (dd != null) {
      rule = dd.$1;
      if (dd.$2.isNotEmpty) {
        final rr = _splitDoubleHash(dd.$2);
        if (rr != null) {
          replaceRegex = rr.$1;
          replaceTo = rr.$2;
        } else {
          defaultVal = dd.$2;
        }
      }
    }

    var results = _applyRule(resp, rule);

    if (replaceRegex.isNotEmpty) {
      results = results
          .map((e) => e is dom.Element
              ? _textOf(e).replaceAll(RegExp(replaceRegex), replaceTo)
              : e.toString().replaceAll(RegExp(replaceRegex), replaceTo))
          .toList();
    }
    if (results.isEmpty && defaultVal.isNotEmpty) {
      results = [defaultVal];
    }
    return results;
  }

  static (String, String)? _splitDoubleHash(String s) {
    final i = s.indexOf('##');
    if (i < 0) return null;
    // 不处理规则开头的 ##
    if (i == 0) return null;
    return (s.substring(0, i), s.substring(i + 2));
  }

  static List<dynamic> _applyRule(dynamic resp, String rule) {
    // 拼接 {{}}
    if (rule.contains('{{')) {
      return [_interpolate(resp, rule)];
    }
    // 纯字符串字面量
    if (resp is! dom.Document &&
        resp is! dom.Element &&
        !rule.startsWith('@') &&
        !rule.startsWith(r'$') &&
        !rule.startsWith('//') &&
        !rule.contains('.')) {
      return [rule];
    }

    if (rule.startsWith('//')) {
      return _xpath(resp, rule);
    }
    if (rule.startsWith(r'$')) {
      return _jsonPath(resp, rule);
    }
    if (rule.startsWith('@css:')) {
      return _css(resp, rule.substring(5));
    }
    if (rule.startsWith(r'$.') || rule.startsWith(r'$[')) {
      return _jsonPath(resp, rule);
    }
    // text. / class. / id. / tag.
    if (rule.startsWith('text.')) {
      return _css(resp, rule.substring(5));
    }
    if (rule.startsWith('class.')) {
      return _css(resp, '.${rule.substring(6)}');
    }
    if (rule.startsWith('id.')) {
      return _css(resp, '#${rule.substring(3)}');
    }
    if (rule.startsWith('tag.')) {
      return _css(resp, rule.substring(4));
    }
    // @regex: 对 resp 文本做正则
    if (rule.startsWith('@regex:')) {
      final text = resp is String ? resp : (resp is dom.Node ? (resp.text ?? '') : '');
      final m = RegExp(rule.substring(7)).firstMatch(text);
      if (m == null) return [];
      if (m.groupCount >= 1) return [m.group(1) ?? ''];
      return [m.group(0) ?? ''];
    }
    return [];
  }

  static List<dynamic> _xpath(dynamic resp, String path) {
    dom.Document? doc;
    dom.Element? root;
    if (resp is dom.Document) {
      doc = resp;
    } else if (resp is dom.Element) {
      root = resp;
    } else if (resp is String) {
      doc = html_parser.parse(resp);
    } else {
      return [];
    }
    // 简化 xpath：支持 //tag, //tag[@attr='v'], //tag/class, //text(), //@attr
    final body = doc != null ? doc.body : root;
    if (body == null) return [];
    if (path == '//text()') return [body.text.trim()];
    final sel = path.replaceFirst('//', '');
    return _simpleXPath(body, sel);
  }

  static List<dynamic> _simpleXPath(dom.Element root, String sel) {
    final parts = sel.split('/').where((p) => p.isNotEmpty).toList();
    var nodes = <dom.Element>[root];
    for (var i = 0; i < parts.length; i++) {
      final p = parts[i];
      if (p == 'text()') {
        return nodes.map((e) => e.text.trim()).toList();
      }
      final next = <dom.Element>[];
      for (final n in nodes) {
        next.addAll(_matchStep(n, p));
      }
      nodes = next;
      if (nodes.isEmpty) return [];
    }
    return nodes;
  }

  static List<dom.Element> _matchStep(dom.Element parent, String step) {
    // step: tag | tag[@attr='v'] | tag[n] | *
    final m = RegExp(r'''^([^\[]+)(?:\[@([^\]=]+)=["']([^"']*)["']\])?(?:\[(\d+)\])?''')
        .firstMatch(step);
    if (m == null) return [];
    final tag = m.group(1)!;
    final attr = m.group(2);
    final val = m.group(3);
    final index = m.group(4);
    var candidates = <dom.Element>[];
    if (tag == '*') {
      candidates = parent.children;
    } else {
      candidates = parent.querySelectorAll(tag);
    }
    if (attr != null) {
      candidates = candidates.where((e) => e.attributes[attr] == val).toList();
    }
    if (index != null) {
      final i = int.parse(index) - 1;
      if (i >= 0 && i < candidates.length) return [candidates[i]];
      return [];
    }
    return candidates;
  }

  static List<dynamic> _css(dynamic resp, String selector) {
    if (resp is dom.Document) return resp.querySelectorAll(selector);
    if (resp is dom.Element) return resp.querySelectorAll(selector);
    return [];
  }

  static List<dynamic> _jsonPath(dynamic resp, String path) {
    dynamic data;
    if (resp is String) {
      try {
        data = jsonDecode(resp);
      } catch (_) {
        return [];
      }
    } else if (resp is dom.Document) {
      try {
        data = jsonDecode(resp.body!.text);
      } catch (_) {
        return [];
      }
    } else {
      data = resp;
    }
    // 支持 a.b[0].c 和 a.b[*].c
    final tokens = path
        .replaceFirst(r'$', '')
        .replaceAll(RegExp(r'\[(\d+)\]'), '.\$1')
        .replaceAll('[*]', '.*')
        .split('.')
        .where((t) => t.isNotEmpty)
        .toList();
    var cur = <dynamic>[data];
    for (final t in tokens) {
      final next = <dynamic>[];
      for (final item in cur) {
        if (t == '*') {
          if (item is List) next.addAll(item);
        } else if (item is Map) {
          if (item.containsKey(t)) next.add(item[t]);
        } else if (item is List) {
          final i = int.tryParse(t);
          if (i != null && i >= 0 && i < item.length) next.add(item[i]);
        }
      }
      cur = next;
    }
    return cur.map((e) => e is String ? e : jsonEncode(e)).toList();
  }

  static String _interpolate(dynamic resp, String rule) {
    // {{a}}{{b}} 拼接，每段递归求值
    final re = RegExp(r'\{\{(.*?)\}\}');
    var result = '';
    var last = 0;
    for (final m in re.allMatches(rule)) {
      result += rule.substring(last, m.start);
      final inner = m.group(1)!;
      final v = optString(resp, inner);
      result += v;
      last = m.end;
    }
    result += rule.substring(last);
    return result;
  }

  static List<dynamic> _runJs(String script, dynamic resp) {
    if (_js == null) return [];
    try {
      final jsResp = _js.evaluate('''
        (function(){
          var result = $script;
          return typeof result === 'string' ? result : JSON.stringify(result);
        })()
      ''');
      final out = jsResp.stringResult;
      if (out == 'undefined' || out.isEmpty) return [];
      return [out];
    } catch (_) {
      return [];
    }
  }

  /// 解析响应体为文档
  static dynamic parseBody(String body, String contentType) {
    if (contentType.contains('json')) {
      try {
        return jsonDecode(body);
      } catch (_) {
        return body;
      }
    }
    return html_parser.parse(body);
  }
}
