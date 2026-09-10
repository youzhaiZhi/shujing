import 'dart:convert';

/// 书源（阅读3.0 格式子集）
class BookSource {
  final int? id;
  final String bookSourceUrl;
  final String bookSourceName;
  final String bookSourceGroup;
  final bool enabled;
  final int sortOrder;
  final String? searchUrl;
  final String? bookUrlPattern;
  final String? headers;
  final RuleSearch ruleSearch;
  final RuleBook ruleBook;
  final RuleToc ruleToc;
  final RuleContent ruleContent;
  final String raw;

  BookSource({
    this.id,
    required this.bookSourceUrl,
    required this.bookSourceName,
    this.bookSourceGroup = '',
    this.enabled = true,
    this.sortOrder = 0,
    this.searchUrl,
    this.bookUrlPattern,
    this.headers,
    this.ruleSearch = const RuleSearch(),
    this.ruleBook = const RuleBook(),
    this.ruleToc = const RuleToc(),
    this.ruleContent = const RuleContent(),
    this.raw = '',
  });

  factory BookSource.fromJson(Map<String, dynamic> j, {int? id}) {
    return BookSource(
      id: id,
      bookSourceUrl: (j['bookSourceUrl'] ?? '').toString(),
      bookSourceName: (j['bookSourceName'] ?? j['bookSourceUrl'] ?? '未命名').toString(),
      bookSourceGroup: (j['bookSourceGroup'] ?? '').toString(),
      enabled: j['enabled'] != false,
      bookUrlPattern: j['bookUrlPattern']?.toString(),
      searchUrl: j['searchUrl']?.toString(),
      headers: j['headers'] is String ? j['headers'] : jsonEncode(j['headers'] ?? {}),
      ruleSearch: RuleSearch.fromMap(j['ruleSearch']),
      ruleBook: RuleBook.fromMap(j['ruleBook']),
      ruleToc: RuleToc.fromMap(j['ruleToc']),
      ruleContent: RuleContent.fromMap(j['ruleContent']),
      raw: jsonEncode(j),
    );
  }

  Map<String, dynamic> toRow() => {
        if (id != null) 'id': id,
        'name': bookSourceName,
        'url': bookSourceUrl,
        'group_name': bookSourceGroup,
        'enabled': enabled ? 1 : 0,
        'sort_order': sortOrder,
        'raw': raw,
      };

  factory BookSource.fromRow(Map<String, dynamic> row) {
    final j = jsonDecode(row['raw'] as String) as Map<String, dynamic>;
    return BookSource.fromJson(j, id: row['id'] as int)
      .._enabledOverride = (row['enabled'] as int) == 1
      .._sortOverride = row['sort_order'] as int? ?? 0;
  }

  bool get isEnabled => _enabledOverride ?? enabled;
  bool? _enabledOverride;
  int _sortOverride = 0;
  int get sort => _sortOverride;
}

class RuleSearch {
  final String bookList;
  final String name;
  final String author;
  final String kind;
  final String wordCount;
  final String lastChapter;
  final String coverUrl;
  final String intro;
  final String bookUrl;
  final String checkKeyWord;
  const RuleSearch({
    this.bookList = '',
    this.name = '',
    this.author = '',
    this.kind = '',
    this.wordCount = '',
    this.lastChapter = '',
    this.coverUrl = '',
    this.intro = '',
    this.bookUrl = '',
    this.checkKeyWord = '',
  });

  factory RuleSearch.fromMap(dynamic m) {
    if (m is! Map) return const RuleSearch();
    return RuleSearch(
      bookList: (m['bookList'] ?? '').toString(),
      name: (m['name'] ?? '').toString(),
      author: (m['author'] ?? '').toString(),
      kind: (m['kind'] ?? '').toString(),
      wordCount: (m['wordCount'] ?? '').toString(),
      lastChapter: (m['lastChapter'] ?? '').toString(),
      coverUrl: (m['coverUrl'] ?? '').toString(),
      intro: (m['intro'] ?? '').toString(),
      bookUrl: (m['bookUrl'] ?? '').toString(),
      checkKeyWord: (m['checkKeyWord'] ?? '').toString(),
    );
  }
}

class RuleBook {
  final String name;
  final String author;
  final String intro;
  final String kind;
  final String coverUrl;
  final String tocUrl;
  final String wordCount;
  final String lastChapter;
  const RuleBook({
    this.name = '',
    this.author = '',
    this.intro = '',
    this.kind = '',
    this.coverUrl = '',
    this.tocUrl = '',
    this.wordCount = '',
    this.lastChapter = '',
  });

  factory RuleBook.fromMap(dynamic m) {
    if (m is! Map) return const RuleBook();
    return RuleBook(
      name: (m['name'] ?? '').toString(),
      author: (m['author'] ?? '').toString(),
      intro: (m['intro'] ?? '').toString(),
      kind: (m['kind'] ?? '').toString(),
      coverUrl: (m['coverUrl'] ?? '').toString(),
      tocUrl: (m['tocUrl'] ?? '').toString(),
      wordCount: (m['wordCount'] ?? '').toString(),
      lastChapter: (m['lastChapter'] ?? '').toString(),
    );
  }
}

class RuleToc {
  final String chapterList;
  final String chapterName;
  final String chapterUrl;
  const RuleToc({this.chapterList = '', this.chapterName = '', this.chapterUrl = ''});

  factory RuleToc.fromMap(dynamic m) {
    if (m is! Map) return const RuleToc();
    return RuleToc(
      chapterList: (m['chapterList'] ?? '').toString(),
      chapterName: (m['chapterName'] ?? '').toString(),
      chapterUrl: (m['chapterUrl'] ?? '').toString(),
    );
  }
}

class RuleContent {
  final String content;
  final String nextContentUrl;
  final String replaceRegex;
  const RuleContent({this.content = '', this.nextContentUrl = '', this.replaceRegex = ''});

  factory RuleContent.fromMap(dynamic m) {
    if (m is! Map) return const RuleContent();
    return RuleContent(
      content: (m['content'] ?? '').toString(),
      nextContentUrl: (m['nextContentUrl'] ?? '').toString(),
      replaceRegex: (m['replaceRegex'] ?? '').toString(),
    );
  }
}

/// 书籍
class Book {
  final int? id;
  final int sourceId;
  final String bookUrl;
  final String name;
  final String author;
  final String coverUrl;
  final String intro;
  final String kind;
  final String wordCount;
  final String lastChapter;
  final String tocUrl;
  final bool inShelf;
  final int lastRead;
  final int chapterCount;

  Book({
    this.id,
    required this.sourceId,
    required this.bookUrl,
    required this.name,
    this.author = '',
    this.coverUrl = '',
    this.intro = '',
    this.kind = '',
    this.wordCount = '',
    this.lastChapter = '',
    this.tocUrl = '',
    this.inShelf = false,
    this.lastRead = 0,
    this.chapterCount = 0,
  });

  Map<String, dynamic> toRow() => {
        if (id != null) 'id': id,
        'source_id': sourceId,
        'book_url': bookUrl,
        'name': name,
        'author': author,
        'cover_url': coverUrl,
        'intro': intro,
        'kind': kind,
        'word_count': wordCount,
        'last_chapter': lastChapter,
        'toc_url': tocUrl,
        'in_shelf': inShelf ? 1 : 0,
        'last_read': lastRead,
        'chapter_count': chapterCount,
      };

  factory Book.fromRow(Map<String, dynamic> r) => Book(
        id: r['id'] as int,
        sourceId: r['source_id'] as int,
        bookUrl: r['book_url'] as String,
        name: r['name'] as String,
        author: (r['author'] ?? '') as String,
        coverUrl: (r['cover_url'] ?? '') as String,
        intro: (r['intro'] ?? '') as String,
        kind: (r['kind'] ?? '') as String,
        wordCount: (r['word_count'] ?? '') as String,
        lastChapter: (r['last_chapter'] ?? '') as String,
        tocUrl: (r['toc_url'] ?? '') as String,
        inShelf: (r['in_shelf'] ?? 0) == 1,
        lastRead: (r['last_read'] ?? 0) as int,
        chapterCount: (r['chapter_count'] ?? 0) as int,
      );
}

/// 章节
class Chapter {
  final int idx;
  final String title;
  final String url;
  Chapter({required this.idx, required this.title, required this.url});

  Map<String, dynamic> toRow(int bookId) =>
      {'book_id': bookId, 'idx': idx, 'title': title, 'url': url};

  factory Chapter.fromRow(Map<String, dynamic> r) => Chapter(
        idx: r['idx'] as int,
        title: r['title'] as String,
        url: (r['url'] ?? '') as String,
      );
}

/// 搜索结果条目
class SearchBook {
  final BookSource source;
  final Book book;
  SearchBook(this.source, this.book);
}
