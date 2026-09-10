import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/models.dart';
import '../state/providers.dart';
import '../widgets/book_cover.dart';
import 'detail_page.dart';
import 'reader_page.dart';
import 'search_page.dart';
import 'sources_page.dart';

class HomePage extends ConsumerWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final shelf = ref.watch(shelfProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('书架'),
        actions: [
          IconButton(
            icon: const Icon(Icons.search_rounded),
            tooltip: '搜索书籍',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const SearchPage())),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: shelf.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('加载失败: $e')),
        data: (books) {
          if (books.isEmpty) {
            return const _EmptyShelf();
          }
          return RefreshIndicator(
            onRefresh: () => ref.read(shelfProvider.notifier).refresh(),
            child: GridView.builder(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                childAspectRatio: 0.62,
                crossAxisSpacing: 16,
                mainAxisSpacing: 20,
              ),
              itemCount: books.length,
              itemBuilder: (context, i) => _ShelfItem(book: books[i]),
            ),
          );
        },
      ),
    );
  }
}

class _EmptyShelf extends ConsumerWidget {
  const _EmptyShelf();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.auto_stories_outlined,
              size: 72, color: Theme.of(context).colorScheme.outlineVariant),
          const SizedBox(height: 16),
          Text('书架空空如也',
              style: TextStyle(
                  fontSize: 16, color: Theme.of(context).colorScheme.outline)),
          const SizedBox(height: 24),
          FilledButton.icon(
            icon: const Icon(Icons.add_rounded),
            label: const Text('去导入书源'),
            onPressed: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => const SourcesPage())),
          ),
        ],
      ),
    );
  }
}

class _ShelfItem extends ConsumerWidget {
  final Book book;
  const _ShelfItem({required this.book});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: () => _open(context, ref),
      onLongPress: () => _showMenu(context, ref),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Stack(
              children: [
                SizedBox.expand(
                    child: BookCover(imageUrl: book.coverUrl, title: book.name)),
                if (book.chapterCount > 0)
                  Positioned(
                    right: 6,
                    bottom: 6,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.4),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text('${book.chapterCount}章',
                          style: const TextStyle(
                              color: Colors.white, fontSize: 10)),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Text(book.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
          Text(book.author.isEmpty ? ' ' : book.author,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                  fontSize: 12, color: scheme.onSurface.withOpacity(0.5))),
        ],
      ),
    );
  }

  Future<void> _open(BuildContext context, WidgetRef ref) async {
    final list = await ref.read(sourcesProvider.notifier).future;
    final matches = list.where((s) => s.id == book.sourceId).toList();
    if (matches.isEmpty || !context.mounted) return;
    final source = matches.first;
    Navigator.push(
      context,
      MaterialPageRoute(
          builder: (_) => ReaderPage(book: book, source: source)),
    );
  }

  void _showMenu(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.info_outline_rounded),
              title: const Text('书籍详情'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(context,
                    MaterialPageRoute(builder: (_) => DetailPage(book: book)));
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline_rounded),
              title: const Text('移出书架'),
              onTap: () {
                Navigator.pop(context);
                ref.read(shelfProvider.notifier).remove(book.id!);
              },
            ),
          ],
        ),
      ),
    );
  }
}

extension<T> on List<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
