import 'dart:convert';

import 'package:html/dom.dart' as dom;
import 'package:html/parser.dart' as html_parser;

import '../platform/js.dart' as js_platform;

/// 阅读3.0 规则引擎
/// 支持：
///   `||` 回退多规则、`&&` 链式规则
///   选择器：`//xpath`、`$.json`、`@css:`、`class.x`、`id.x`、`tag.x`、`text.x`（可带 `.N` 下标）
///   `@` 属性/字段链：`class.x@tag.li`、`tag.a@text`、`tag.a@href`、`id.content@textNodes`
///   拼接 `{{}}`、`##默认值`、`##正则##替换`、`<js>` / `@js:`
class RuleEngine {
  static final dynamic _js =
      js_platform.jsSupported ? js_platform.createJsRuntime() : null;

  // ---------- 对外入口 ----------

  /// 执行规则，返回第一个非空字符串
  static String optString(dynamic resp, String rule) {
    for (final alt in _splitTop(rule, '||')) {
      for (final v in _evalChain(resp, alt)) {
        final s = _toText(v);
        if (s.isNotEmpty) return s;
      }
    }
    return '';
  }

  /// 执行规则，返回字符串列表
  static List<String> optList(dynamic resp, String rule) {
    for (final alt in _splitTop(rule, '||')) {
      final out = <String>[];
      for (final v in _evalChain(resp, alt)) {
        final s = _toText(v);
        if (s.isNotEmpty) out.add(s);
      }
      if (out.isNotEmpty) return out;
    }
    return [];
  }

  /// 执行规则，返回元素列表（用于 bookList / chapterList）
  static List<dynamic> optElements(dynamic resp, String rule) {
    for (final alt in _splitTop(rule, '||')) {
      final r = _evalChain(resp, alt);
      if (r.isNotEmpty) return r;
    }
    return [];
  }

  /// 解析响应体为文档 / JSON
  static dynamic parseBody(String body, String contentType) {
    if (contentType.contains('json')) {
      try {
        return jsonDecode(body);
      } catch (_) {
        return body;
      }
    }
    final trimmed = body.trimLeft();
    if (trimmed.startsWith('{') || trimmed.startsWith('[')) {
      try {
        return jsonDecode(body);
      } catch (_) {}
    }
    return html_parser.parse(body);
  }

  // ---------- 规则拆分 ----------

  /// 按 sep 在顶层（不在 {{}}、[]、引号内）拆分
  static List<String> _splitTop(String rule, String sep) {
    final parts = <String>[];
    final buf = StringBuffer();
    var brace = 0, bracket = 0;
    String? quote;
    for (var i = 0; i < rule.length; i++) {
      final c = rule[i];
      if (quote != null) {
        buf.write(c);
        if (c == quote) quote = null;
        continue;
      }
      if (c == '"' || c == "'") {
        quote = c;
        buf.write(c);
        continue;
      }
      if (c == '{') brace++;
      if (c == '}') brace--;
      if (c == '[') bracket++;
      if (c == ']') bracket--;
      if (brace == 0 && bracket == 0 &&
          i + sep.length <= rule.length &&
          rule.substring(i, i + sep.length) == sep) {
        parts.add(buf.toString());
        buf.clear();
        i += sep.length - 1;
        continue;
      }
      buf.write(c);
    }
    parts.add(buf.toString());
    return parts.where((p) => p.trim().isNotEmpty).toList();
  }

  /// 执行一条 `&&` 链
  static List<dynamic> _evalChain(dynamic resp, String chain) {
    var current = <dynamic>[resp];
    for (final step in _splitTop(chain, '&&')) {
      final next = <dynamic>[];
      for (final item in current) {
        next.addAll(_evalStep(item, step.trim()));
      }
      current = next;
      if (current.isEmpty) return [];
    }
    return current;
  }

  // ---------- 单步求值 ----------

  static List<dynamic> _evalStep(dynamic resp, String step) {
    if (step.isEmpty) return [resp];

    // JS
    if (step.startsWith('<js>') && step.endsWith('</js>')) {
      return _runJs(step.substring(4, step.length - 5), resp);
    }
    if (step.startsWith('@js:')) {
      return _runJs(step.substring(4), resp);
    }

    // ## 默认值 / 正则替换
    var defaultVal = '';
    var replaceRegex = '';
    var replaceTo = '';
    final dd = _splitDoubleHash(step);
    if (dd != null) {
      step = dd.$1;
      final rest = dd.$2;
      final rr = _splitDoubleHash(rest);
      if (rr != null) {
        replaceRegex = rr.$1;
        replaceTo = rr.$2;
      } else {
        defaultVal = rest;
      }
    }

    var results = _evalSelectorChain(resp, step);

    if (replaceRegex.isNotEmpty) {
      results = results
          .map((e) => _toText(e).replaceAll(RegExp(replaceRegex), replaceTo))
          .toList();
    }
    if (results.isEmpty && defaultVal.isNotEmpty) {
      results = [defaultVal];
    }
    return results;
  }

  static (String, String)? _splitDoubleHash(String s) {
    final i = s.indexOf('##');
    if (i <= 0) return null;
    return (s.substring(0, i), s.substring(i + 2));
  }

  /// `selector@attr@attr...`（`@` 仅在作为链式分隔符时拆分：
  /// 不在引号/括号内、不在开头、不紧跟 `/`（xpath 的 /@attr））
  static List<dynamic> _evalSelectorChain(dynamic resp, String step) {
    final segs = _splitAt(step);
    var current = <dynamic>[resp];
    for (var i = 0; i < segs.length; i++) {
      final seg = segs[i];
      final next = <dynamic>[];
      for (final item in current) {
        if (i == 0) {
          next.addAll(_resolveSelector(item, seg));
        } else {
          next.addAll(_applySegment(item, seg));
        }
      }
      current = next;
      if (current.isEmpty) return [];
    }
    return current;
  }

  static List<String> _splitAt(String step) {
    final parts = <String>[];
    final buf = StringBuffer();
    var brace = 0, bracket = 0;
    String? quote;
    for (var i = 0; i < step.length; i++) {
      final c = step[i];
      if (quote != null) {
        buf.write(c);
        if (c == quote) quote = null;
        continue;
      }
      if (c == '"' || c == "'") {
        quote = c;
        buf.write(c);
        continue;
      }
      if (c == '{') brace++;
      if (c == '}') brace--;
      if (c == '[') bracket++;
      if (c == ']') bracket--;
      if (c == '@' &&
          brace == 0 &&
          bracket == 0 &&
          i > 0 &&
          step[i - 1] != '/') {
        parts.add(buf.toString());
        buf.clear();
        continue;
      }
      buf.write(c);
    }
    parts.add(buf.toString());
    return parts;
  }

  // ---------- 选择器 ----------

  static List<dynamic> _resolveSelector(dynamic resp, String sel) {
    sel = sel.trim();
    if (sel.isEmpty) return [resp];

    // {{拼接}}
    if (sel.contains('{{')) {
      return [_interpolate(resp, sel)];
    }

    if (sel.startsWith('@css:')) {
      return _css(resp, sel.substring(5));
    }
    if (sel.startsWith('@regex:')) {
      final text = _toText(resp);
      final m = RegExp(sel.substring(7)).firstMatch(text);
      if (m == null) return [];
      return [m.groupCount >= 1 ? (m.group(1) ?? '') : (m.group(0) ?? '')];
    }
    if (sel.startsWith('//')) return _xpath(resp, sel);
    if (sel.startsWith(r'$')) return _jsonPath(resp, sel);

    // class.x / id.x / tag.x / text.x（支持 .N 下标）
    final m = RegExp(r'^(class|id|tag|text)\.(.+?)(?:\.(\d+))?$').firstMatch(sel);
    if (m != null) {
      final kind = m.group(1)!;
      final arg = m.group(2)!;
      final idx = m.group(3) != null ? int.parse(m.group(3)!) : null;
      List<dynamic> els;
      switch (kind) {
        case 'class':
          els = _css(resp, '.${_cssEscape(arg)}');
        case 'id':
          els = _css(resp, '#${_cssEscape(arg)}');
        case 'tag':
          els = _css(resp, arg);
        default: // text.
          els = _containsText(resp, arg);
      }
      if (idx != null) {
        return idx < els.length ? [els[idx]] : [];
      }
      return els;
    }

    // 裸键名：resp 是 Map/List 时按 JSON 字段取
    if (resp is Map || resp is List) {
      return _jsonPath(resp, '\$.$sel');
    }
    if (resp is String) {
      // 字符串响应：尝试 JSON 字段，否则原样返回
      try {
        final j = jsonDecode(resp);
        if (j is Map || j is List) return _jsonPath(j, '\$.$sel');
      } catch (_) {}
      return [resp];
    }
    // 元素上的裸段：属性关键字走属性，否则取文本
    if (resp is dom.Element) {
      if (_attrKeys.contains(sel)) return _applySegment(resp, sel);
      final t = resp.text.trim();
      return t.isEmpty ? [] : [t];
    }
    return [];
  }

  static const _attrKeys = {
    'text', 'textNodes', 'html', 'innerHtml', 'outerHtml', 'tag',
    'class', 'className', 'id', 'href', 'src', 'content', 'value',
  };

  static String _cssEscape(String s) =>
      s.replaceAll(RegExp(r'([^\w-])'), r'\1');

  static List<dynamic> _containsText(dynamic resp, String text) {
    final root = resp is dom.Document
        ? resp.body
        : resp is dom.Element
            ? resp
            : null;
    if (root == null) return [];
    return root
        .querySelectorAll('*')
        .where((e) => e.children.isEmpty && e.text.contains(text))
        .toList();
  }

  /// `@` 之后的段：属性 / 子选择器 / JSON 键
  static List<dynamic> _applySegment(dynamic el, String seg) {
    seg = seg.trim();
    if (seg.isEmpty) return [el];

    if (el is dom.Element) {
      switch (seg) {
        case 'text':
          final t = el.text.trim();
          return t.isEmpty ? [] : [t];
        case 'textNodes':
          return [
            el.nodes
                .whereType<dom.Text>()
                .map((t) => t.text.trim())
                .where((t) => t.isNotEmpty)
                .join('\n')
          ];
        case 'html':
          return [el.innerHtml];
        case 'tag':
          return [el.localName ?? ''];
        case 'class':
          return [el.className];
        case 'id':
          return [el.id];
        case 'href':
        case 'src':
        case 'content':
        case 'value':
          return [el.attributes[seg] ?? ''];
      }
      // 子选择器
      if (seg.startsWith('//') ||
          seg.startsWith(r'$') ||
          seg.startsWith('@css:') ||
          RegExp(r'^(class|id|tag|text)\.').hasMatch(seg)) {
        return _resolveSelector(el, seg);
      }
      return [];
    }

    if (el is Map) {
      final v = el[seg];
      if (v == null) return [];
      return v is List ? v : [v];
    }
    if (el is List) {
      if (seg == '*') return el;
      final i = int.tryParse(seg);
      if (i != null && i >= 0 && i < el.length) return [el[i]];
      // 列表元素各自取键
      final out = <dynamic>[];
      for (final e in el) {
        out.addAll(_applySegment(e, seg));
      }
      return out;
    }
    if (el is String) {
      try {
        final j = jsonDecode(el);
        if (j is Map || j is List) return _applySegment(j, seg);
      } catch (_) {}
      return [el];
    }
    if (el is num || el is bool) {
      final s = el.toString();
      return s.isEmpty ? [] : [s];
    }
    return [];
  }

  // ---------- xpath 子集 ----------

  static List<dynamic> _xpath(dynamic resp, String path) {
    dom.Element? root;
    if (resp is dom.Document) {
      root = resp.body;
    } else if (resp is dom.Element) {
      root = resp;
    } else if (resp is String) {
      root = html_parser.parse(resp).body;
    }
    if (root == null) return [];
    if (path == '//text()') return [root.text.trim()];
    final sel = path.replaceFirst('//', '');
    final parts = sel.split('/').where((p) => p.isNotEmpty).toList();
    var nodes = <dynamic>[root];
    for (final p in parts) {
      final next = <dynamic>[];
      for (final n in nodes) {
        if (n is! dom.Element) continue;
        if (p == 'text()') {
          next.addAll(n.nodes
              .whereType<dom.Text>()
              .map((t) => t.text.trim())
              .where((t) => t.isNotEmpty));
        } else if (p.startsWith('@')) {
          final v = n.attributes[p.substring(1)];
          if (v != null && v.isNotEmpty) next.add(v);
        } else {
          next.addAll(_matchStep(n, p));
        }
      }
      nodes = next;
      if (nodes.isEmpty) return [];
    }
    return nodes;
  }

  static List<dom.Element> _matchStep(dom.Element parent, String step) {
    final m = RegExp(
            r'''^([^\[]+)(?:\[@([^\]=]+)=["']([^"']*)["']\])?(?:\[(\d+)\])?''')
        .firstMatch(step);
    if (m == null) return [];
    final tag = m.group(1)!;
    final attr = m.group(2);
    final val = m.group(3);
    final index = m.group(4);
    var candidates =
        tag == '*' ? parent.children : parent.querySelectorAll(tag);
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

  // ---------- css / json ----------

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
    return cur;
  }

  // ---------- 其他 ----------

  static String _interpolate(dynamic resp, String rule) {
    final re = RegExp(r'\{\{(.*?)\}\}');
    var result = '';
    var last = 0;
    for (final m in re.allMatches(rule)) {
      result += rule.substring(last, m.start);
      result += optString(resp, m.group(1)!);
      last = m.end;
    }
    result += rule.substring(last);
    return result;
  }

  static List<dynamic> _runJs(String script, dynamic resp) {
    if (_js == null) return [];
    try {
      final resultStr = resp is String
          ? resp
          : resp is dom.Element
              ? resp.innerHtml
              : resp is dom.Document
                  ? resp.body?.innerHtml ?? ''
                  : jsonEncode(resp);
      final jsResp = _js.evaluate('''
        var result = ${jsonEncode(resultStr)};
        (function(){
          var r = $script;
          return typeof r === 'string' ? r : JSON.stringify(r);
        })()
      ''');
      final out = jsResp.stringResult;
      if (out == 'undefined' || out.isEmpty) return [];
      return [out];
    } catch (_) {
      return [];
    }
  }

  static String _toText(dynamic v) {
    if (v is String) return v.trim();
    if (v is dom.Element) {
      final t = v.text.trim();
      if (t.isNotEmpty) return t;
      for (final a in ['content', 'href', 'src', 'data-url', 'value']) {
        final av = v.attributes[a];
        if (av != null && av.isNotEmpty) return av;
      }
      return '';
    }
    if (v is num || v is bool) return v.toString();
    if (v is Map || v is List) return jsonEncode(v);
    return '';
  }
}
