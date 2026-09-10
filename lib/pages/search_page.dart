import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/models.dart';
import '../source/source_service.dart';
import '../state/providers.dart';
import '../widgets/book_cover.dart';
import '../widgets/glass.dart';
import 'detail_page.dart';

class SearchPage extends ConsumerStatefulWidget {
  const SearchPage({super.key});

  @override
  ConsumerState<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends ConsumerState<SearchPage> {
  final _controller = TextEditingController();
  List<BookSource> _sources = [];
  int _selectedSource = -1; // -1 = 全部
  final Map<String, List<SearchBook>> _results = {};
  final Set<String> _loading = {};
  final Set<String> _errors = {};
  bool _searched = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final list = await ref.read(sourcesProvider.notifier).future;
      setState(() => _sources = list.where((s) => s.isEnabled).toList());
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _search() {
    final kw = _controller.text.trim();
    if (kw.isEmpty) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _results.clear();
      _errors.clear();
      _searched = true;
    });
    final targets = _selectedSource == -1
        ? _sources
        : (_selectedSource < _sources.length ? [_sources[_selectedSource]] : _sources);
    for (final s in targets) {
      _loadSource(s, kw);
    }
  }

  Future<void> _loadSource(BookSource s, String kw) async {
    setState(() {
      _loading.add(s.bookSourceUrl);
      _errors.remove(s.bookSourceUrl);
    });
    try {
      final results = await SourceService.search(s, kw);
      if (!mounted) return;
      setState(() => _results[s.bookSourceUrl] = results);
    } catch (e) {
      if (!mounted) return;
      setState(() => _errors.add(s.bookSourceUrl));
    } finally {
      if (mounted) setState(() => _loading.remove(s.bookSourceUrl));
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 4,
        title: GlassContainer(
          borderRadius: BorderRadius.circular(22),
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            children: [
              Icon(Icons.search_rounded, size: 20, color: scheme.outline),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: _controller,
                  onSubmitted: (_) => _search(),
                  decoration: const InputDecoration(
                    hintText: '搜索书名 / 作者',
                    border: InputBorder.none,
                  ),
                ),
              ),
              if (_controller.text.isNotEmpty)
                GestureDetector(
                  onTap: () => setState(() => _controller.clear()),
                  child: Icon(Icons.close_rounded, size: 18, color: scheme.outline),
                ),
            ],
          ),
        ),
        actions: [
          IconButton(
              icon: const Icon(Icons.search_rounded), onPressed: _search),
          const SizedBox(width: 4),
        ],
      ),
      body: Column(
        children: [
          if (_sources.isNotEmpty)
            SizedBox(
              height: 44,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                children: [
                  _SourceChip(
                    label: '全部',
                    selected: _selectedSource == -1,
                    onTap: () => setState(() => _selectedSource = -1),
                  ),
                  ...List.generate(_sources.length, (i) {
                    final s = _sources[i];
                    return _SourceChip(
                      label: s.bookSourceName,
                      selected: _selectedSource == i,
                      onTap: () => setState(() => _selectedSource = i),
                      onLongPress: () {
                        _loadSource(s, _controller.text.trim());
                      },
                    );
                  }),
                ],
              ),
            ),
          const SizedBox(height: 4),
          Expanded(
            child: !_searched
                ? Center(
                    child: Text('输入关键词开始搜索',
                        style: TextStyle(color: scheme.outline)))
                : _resultsView(),
          ),
        ],
      ),
    );
  }

  Widget _resultsView() {
    final sourcesToShow = _selectedSource == -1
        ? _sources
        : (_sources.length > _selectedSource && _selectedSource >= 0
            ? [_sources[_selectedSource]]
            : _sources);
    if (sourcesToShow.isEmpty) {
      return const Center(child: Text('请先在「书源」页导入书源'));
    }
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
      children: [
        for (final s in sourcesToShow) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 12, 4, 8),
            child: Row(
              children: [
                Text(s.bookSourceName,
                    style: const TextStyle(
                        fontSize: 14, fontWeight: FontWeight.w600)),
                const SizedBox(width: 8),
                if (_loading.contains(s.bookSourceUrl))
                  const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2)),
                if (_errors.contains(s.bookSourceUrl))
                  Icon(Icons.error_outline_rounded,
                      size: 14, color: Colors.red.shade300),
              ],
            ),
          ),
          ...(_results[s.bookSourceUrl] ?? [])
              .take(20)
              .map((r) => _ResultTile(result: r)),
        ],
      ],
    );
  }
}

class _SourceChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  const _SourceChip(
      {required this.label,
      required this.selected,
      required this.onTap,
      this.onLongPress});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: GestureDetector(
        onLongPress: onLongPress,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
          decoration: BoxDecoration(
            color: selected
                ? scheme.primary.withOpacity(0.14)
                : scheme.onSurface.withOpacity(0.05),
            borderRadius: BorderRadius.circular(18),
          ),
          child: Text(label,
              style: TextStyle(
                fontSize: 13,
                color: selected ? scheme.primary : scheme.onSurface,
                fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
              )),
        ),
      ),
    );
  }
}

class _ResultTile extends StatelessWidget {
  final SearchBook result;
  const _ResultTile({required this.result});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final book = result.book;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: GlassContainer(
        borderRadius: BorderRadius.circular(18),
        padding: const EdgeInsets.all(10),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (_) =>
                      DetailPage(book: book, source: result.source))),
          child: Row(
            children: [
              BookCover(imageUrl: book.coverUrl, title: book.name, width: 52),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(book.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 15, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 3),
                    Text(
                      [
                        book.author,
                        if (book.lastChapter.isNotEmpty) book.lastChapter
                      ].join(' · '),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontSize: 12,
                          color: scheme.onSurface.withOpacity(0.5)),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
