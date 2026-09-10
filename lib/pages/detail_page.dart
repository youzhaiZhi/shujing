import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/db.dart';
import '../data/models.dart';
import '../source/source_service.dart';
import '../state/providers.dart';
import '../widgets/book_cover.dart';
import '../widgets/glass.dart';
import 'reader_page.dart';

class DetailPage extends ConsumerStatefulWidget {
  final Book book;
  final BookSource? source;
  const DetailPage({super.key, required this.book, this.source});

  @override
  ConsumerState<DetailPage> createState() => _DetailPageState();
}

class _DetailPageState extends ConsumerState<DetailPage> {
  late Book _book;
  BookSource? _source;
  List<Chapter> _chapters = [];
  bool _loadingToc = false;
  bool _introExpanded = false;
  String? _error;
  int? _bookId;

  @override
  void initState() {
    super.initState();
    _book = widget.book;
    WidgetsBinding.instance.addPostFrameCallback((_) => _init());
  }

  Future<void> _init() async {
    // 解析书源
    if (_source == null) {
      final list = await ref.read(sourcesProvider.notifier).future;
      final matches = list.where((s) => s.id == _book.sourceId).toList();
      if (matches.isEmpty) {
        setState(() => _error = '书源不存在，请先导入对应书源');
        return;
      }
      _source = matches.first;
    }
    // 入库获取 id
    _bookId = await AppDb.instance.upsertBook(_book);
    // 补全详情
    final info = await SourceService.bookInfo(_source!, _book);
    _bookId = await AppDb.instance.upsertBook(info);
    if (!mounted) return;
    setState(() => _book = _copyWithId(info));
    await _loadToc();
  }

  Book _copyWithId(Book b) => Book(
      id: _bookId,
      sourceId: b.sourceId,
      bookUrl: b.bookUrl,
      name: b.name,
      author: b.author,
      coverUrl: b.coverUrl,
      intro: b.intro,
      kind: b.kind,
      wordCount: b.wordCount,
      lastChapter: b.lastChapter,
      tocUrl: b.tocUrl,
      inShelf: b.inShelf,
      lastRead: b.lastRead,
      chapterCount: b.chapterCount);

  Future<void> _loadToc() async {
    setState(() {
      _loadingToc = true;
      _error = null;
    });
    try {
      final chapters =
          await SourceService.toc(_source!, _book.tocUrl.isEmpty ? _book.bookUrl : _book.tocUrl);
      if (chapters.isEmpty) {
        setState(() {
          _error = '目录为空';
          _loadingToc = false;
        });
        return;
      }
      await AppDb.instance.saveChapters(_bookId!, chapters);
      if (!mounted) return;
      setState(() {
        _chapters = chapters;
        _loadingToc = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = '目录加载失败: $e';
        _loadingToc = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('书籍详情')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              BookCover(imageUrl: _book.coverUrl, title: _book.name, width: 110),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(_book.name,
                        style: const TextStyle(
                            fontSize: 19, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 6),
                    Text(_book.author.isEmpty ? '佚名' : _book.author,
                        style: TextStyle(
                            fontSize: 14,
                            color: scheme.onSurface.withOpacity(0.6))),
                    const SizedBox(height: 6),
                    if (_book.kind.isNotEmpty)
                      Text(_book.kind,
                          style: TextStyle(
                              fontSize: 12, color: scheme.primary)),
                    const SizedBox(height: 6),
                    if (_book.lastChapter.isNotEmpty)
                      Text('最新：${_book.lastChapter}',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              fontSize: 12,
                              color: scheme.onSurface.withOpacity(0.5))),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          if (_book.intro.isNotEmpty)
            GestureDetector(
              onTap: () => setState(() => _introExpanded = !_introExpanded),
              child: AnimatedSize(
                duration: const Duration(milliseconds: 200),
                alignment: Alignment.topCenter,
                child: Text(
                  _introExpanded
                      ? _book.intro
                      : (_book.intro.length > 80
                          ? '${_book.intro.substring(0, 80)}…'
                          : _book.intro),
                  style: TextStyle(
                      fontSize: 13,
                      height: 1.6,
                      color: scheme.onSurface.withOpacity(0.7)),
                ),
              ),
            ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14)),
                  icon: const Icon(Icons.menu_book_rounded),
                  label: const Text('开始阅读'),
                  onPressed: _chapters.isEmpty ? null : _openReader,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14)),
                  icon: Icon(_book.inShelf
                      ? Icons.check_rounded
                      : Icons.add_rounded),
                  label: Text(_book.inShelf ? '已在书架' : '加入书架'),
                  onPressed: () async {
                    await AppDb.instance
                        .setInShelf(_bookId!, !_book.inShelf);
                    ref.read(shelfProvider.notifier).refresh();
                    if (!mounted) return;
                    setState(() => _book = Book(
                        id: _book.id,
                        sourceId: _book.sourceId,
                        bookUrl: _book.bookUrl,
                        name: _book.name,
                        author: _book.author,
                        coverUrl: _book.coverUrl,
                        intro: _book.intro,
                        kind: _book.kind,
                        wordCount: _book.wordCount,
                        lastChapter: _book.lastChapter,
                        tocUrl: _book.tocUrl,
                        inShelf: !_book.inShelf,
                        lastRead: _book.lastRead,
                        chapterCount: _book.chapterCount));
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 28),
          Row(
            children: [
              const Text('目录',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
              const Spacer(),
              if (_loadingToc)
                const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2)),
              if (!_loadingToc)
                IconButton(
                    icon: const Icon(Icons.refresh_rounded, size: 20),
                    onPressed: _loadToc),
            ],
          ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(_error!,
                  style: TextStyle(color: Colors.red.shade400, fontSize: 13)),
            ),
          if (_chapters.isNotEmpty)
            ..._chapters.asMap().entries.map((e) => ListTile(
                  dense: true,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                  title: Text(e.value.title,
                      maxLines: 1, overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 14)),
                  onTap: () => _openReader(startIdx: e.key),
                )),
        ],
      ),
    );
  }

  void _openReader({int startIdx = 0}) {
    Navigator.push(
      context,
      MaterialPageRoute(
          builder: (_) => ReaderPage(
              book: _book, source: _source!, chapters: _chapters, startIdx: startIdx)),
    );
  }
}
