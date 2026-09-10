import 'package:html/dom.dart' as dom;

import '../data/models.dart';
import 'http_client.dart';
import 'rule_engine.dart';

/// 书源抓取服务：搜索 / 详情 / 目录 / 正文
class SourceService {
  /// 搜索
  static Future<List<SearchBook>> search(
      BookSource source, String keyword,
      {int page = 1}) async {
    final url = _buildSearchUrl(source, keyword, page);
    if (url.isEmpty) return [];
    final body = await Http.instance
        .get(url, headers: Http.parseHeaders(source.headers));
    final doc = _parse(body, url);
    final listRule = source.ruleSearch.bookList;
    final elements = RuleEngine.optElements(doc, listRule);
    final results = <SearchBook>[];
    for (final el in elements) {
      final rs = source.ruleSearch;
      String field(String rule) =>
          rule.isEmpty ? '' : RuleEngine.optString(el, rule);
      final name = field(rs.name);
      if (name.isEmpty) continue;
      final bookUrl = field(rs.bookUrl).isNotEmpty
          ? _abs(field(rs.bookUrl), url)
          : (el is dom.Element ? _href(el, url) : '');
      results.add(SearchBook(
        source,
        Book(
          sourceId: source.id!,
          bookUrl: bookUrl,
          name: name,
          author: field(rs.author),
          kind: field(rs.kind),
          wordCount: field(rs.wordCount),
          lastChapter: field(rs.lastChapter),
          coverUrl: _abs(field(rs.coverUrl), url),
          intro: field(rs.intro),
          tocUrl: bookUrl,
        ),
      ));
    }
    return results;
  }

  /// 书籍详情（补全信息）
  static Future<Book> bookInfo(BookSource source, Book book) async {
    if (book.bookUrl.isEmpty) return book;
    try {
      final body = await Http.instance.get(book.bookUrl,
          headers: Http.parseHeaders(source.headers));
      final doc = _parse(body, book.bookUrl);
      final rb = source.ruleBook;
      String field(String rule, String fallback) =>
          rule.isEmpty ? fallback : (RuleEngine.optString(doc, rule).ifEmpty(fallback));
      final cover = _abs(field(rb.coverUrl, book.coverUrl), book.bookUrl);
      final toc = field(rb.tocUrl, book.bookUrl);
      return Book(
        id: book.id,
        sourceId: book.sourceId,
        bookUrl: book.bookUrl,
        name: field(rb.name, book.name),
        author: field(rb.author, book.author),
        intro: field(rb.intro, book.intro),
        kind: field(rb.kind, book.kind),
        coverUrl: cover,
        wordCount: field(rb.wordCount, book.wordCount),
        lastChapter: field(rb.lastChapter, book.lastChapter),
        tocUrl: _abs(toc, book.bookUrl),
        inShelf: book.inShelf,
        lastRead: book.lastRead,
        chapterCount: book.chapterCount,
      );
    } catch (_) {
      return book;
    }
  }

  /// 目录
  static Future<List<Chapter>> toc(BookSource source, String tocUrl) async {
    final body = await Http.instance
        .get(tocUrl, headers: Http.parseHeaders(source.headers));
    final doc = _parse(body, tocUrl);
    final rt = source.ruleToc;
    final elements = RuleEngine.optElements(doc, rt.chapterList);
    final chapters = <Chapter>[];
    var idx = 0;
    for (final el in elements) {
      final title = rt.chapterName.isEmpty
          ? (el is dom.Element ? el.text.trim() : el.toString())
          : RuleEngine.optString(el, rt.chapterName);
      if (title.isEmpty) continue;
      var url = '';
      if (rt.chapterUrl.isNotEmpty) {
        url = RuleEngine.optString(el, rt.chapterUrl);
      } else if (el is dom.Element) {
        url = _href(el, tocUrl);
      }
      chapters.add(Chapter(idx: idx++, title: title, url: _abs(url, tocUrl)));
    }
    return chapters;
  }

  /// 正文（自动跟随 nextContentUrl 拼接）
  static Future<String> content(BookSource source, String chapterUrl) async {
    var url = chapterUrl;
    final buf = StringBuffer();
    final visited = <String>{};
    var guard = 0;
    while (url.isNotEmpty && !visited.contains(url) && guard++ < 20) {
      visited.add(url);
      final body = await Http.instance
          .get(url, headers: Http.parseHeaders(source.headers));
      final doc = _parse(body, url);
      final rc = source.ruleContent;
      String text;
      if (rc.content.isEmpty) {
        text = _defaultContent(doc);
      } else {
        final els = RuleEngine.optElements(doc, rc.content);
        text = els.map((e) => e is dom.Element ? _contentText(e) : e.toString()).join('\n');
      }
      if (rc.replaceRegex.isNotEmpty) {
        for (final seg in rc.replaceRegex.split(RegExp(r'##'))) {
          final parts = seg.split(RegExp(r'::|##'));
          if (parts.length == 2) {
            try {
              text = text.replaceAll(RegExp(parts[0]), parts[1]);
            } catch (_) {}
          }
        }
      }
      buf.writeln(text);
      if (rc.nextContentUrl.isEmpty) break;
      final next = RuleEngine.optString(doc, rc.nextContentUrl);
      if (next.isEmpty || next == url) break;
      url = _abs(next, url);
      buf.writeln();
    }
    return buf.toString().trim();
  }

  static String _defaultContent(dom.Document doc) {
    for (final sel in ['#content', '#chaptercontent', '.content', '#booktxt', '#txt', 'article']) {
      final el = doc.querySelector(sel);
      if (el != null && el.text.trim().length > 100) return _contentText(el);
    }
    return _contentText(doc.body);
  }

  static String _contentText(dom.Element? el) {
    if (el == null) return '';
    final sb = StringBuffer();
    for (final node in el.nodes) {
      if (node is dom.Text) {
        sb.write(node.text);
      } else if (node is dom.Element) {
        if (node.localName == 'br') {
          sb.write('\n');
        } else {
          sb.write(_contentText(node));
        }
      }
    }
    return sb
        .toString()
        .split('\n')
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        .join('\n');
  }

  static dynamic _parse(String body, String url) {
    final ct = _guessType(body, url);
    return RuleEngine.parseBody(body, ct);
  }

  static String _guessType(String body, String url) {
    final t = body.trimLeft();
    if (t.startsWith('{') || t.startsWith('[')) return 'json';
    return 'html';
  }

  static String _buildSearchUrl(BookSource source, String keyword, int page) {
    var su = source.searchUrl ?? '';
    if (su.isEmpty) return '';
    // 去掉配置后缀（如 ",{...}" POST/charset 配置），仅支持 GET
    final comma = su.indexOf(',{');
    if (comma > 0) su = su.substring(0, comma);
    final enc = Uri.encodeComponent(keyword);
    su = su
        .replaceAll('{key}', enc)
        .replaceAll('{coverUrl}', '')
        .replaceAll('{page}', '$page');
    if (su.contains('%{') || su.contains('<js>')) {
      // 复杂编码暂不支持，回退为直接替换
      su = su.replaceAll(RegExp(r'%\{[^}]*\}'), enc);
    }
    // 相对路径基于书源地址解析
    if (su.isNotEmpty && !su.startsWith('http')) {
      su = _abs(su, source.bookSourceUrl);
    }
    return su;
  }

  static String _href(dom.Element el, String base) {
    final a = el.attributes['href'] ??
        el.attributes['data-url'] ??
        el.querySelector('a')?.attributes['href'] ??
        '';
    return _abs(a, base);
  }

  static String _abs(String url, String base) {
    if (url.isEmpty) return '';
    if (url.startsWith('http')) return url;
    try {
      final b = Uri.parse(base);
      if (url.startsWith('/')) {
        return '${b.scheme}://${b.authority}$url';
      }
      final pathSegments = b.pathSegments.toList()..removeLast();
      pathSegments.addAll(url.split('/'));
      return b.replace(pathSegments: pathSegments).toString();
    } catch (_) {
      return url;
    }
  }
}

extension on String {
  String ifEmpty(String fallback) => isEmpty ? fallback : this;
}
