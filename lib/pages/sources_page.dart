import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';

import '../source/http_client.dart';
import '../state/providers.dart';
import '../widgets/glass.dart';

class SourcesPage extends ConsumerWidget {
  const SourcesPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sources = ref.watch(sourcesProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('书源'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_rounded),
            tooltip: '导入书源',
            onPressed: () => _showImportMenu(context, ref),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: sources.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('加载失败: $e')),
        data: (list) {
          if (list.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.cloud_off_rounded,
                      size: 72,
                      color: Theme.of(context).colorScheme.outlineVariant),
                  const SizedBox(height: 16),
                  const Text('还没有书源，点右上角 + 导入'),
                  const SizedBox(height: 24),
                  FilledButton(
                    onPressed: () => _showImportMenu(context, ref),
                    child: const Text('导入书源'),
                  ),
                ],
              ),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
            itemCount: list.length,
            itemBuilder: (context, i) {
              final s = list[i];
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: SoftCard(
                  borderRadius: BorderRadius.circular(20),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 6),
                  child: Dismissible(
                    key: ValueKey(s.id),
                    direction: DismissDirection.endToStart,
                    background: Container(
                      alignment: Alignment.centerRight,
                      padding: const EdgeInsets.only(right: 20),
                      decoration: BoxDecoration(
                        color: Colors.red.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Icon(Icons.delete_outline_rounded,
                          color: Colors.red),
                    ),
                    onDismissed: (_) =>
                        ref.read(sourcesProvider.notifier).delete(s.id!),
                    child: ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(s.bookSourceName,
                          maxLines: 1, overflow: TextOverflow.ellipsis),
                      subtitle: Text(
                          Uri.tryParse(s.bookSourceUrl)?.host ??
                              s.bookSourceUrl,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              fontSize: 12,
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurface
                                  .withOpacity(0.45))),
                      trailing: Switch(
                        value: s.isEnabled,
                        onChanged: (v) => ref
                            .read(sourcesProvider.notifier)
                            .setEnabled(s.id!, v),
                      ),
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  void _showImportMenu(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (sheetCtx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.paste_rounded),
              title: const Text('粘贴 JSON 书源'),
              onTap: () {
                Navigator.pop(sheetCtx);
                _importFromClipboard(context, ref);
              },
            ),
            ListTile(
              leading: const Icon(Icons.folder_open_rounded),
              title: const Text('从本地文件导入'),
              onTap: () {
                Navigator.pop(sheetCtx);
                _importFromFile(context, ref);
              },
            ),
            ListTile(
              leading: const Icon(Icons.link_rounded),
              title: const Text('从 URL 导入'),
              onTap: () {
                Navigator.pop(sheetCtx);
                _importFromUrl(context, ref);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _importFromClipboard(BuildContext context, WidgetRef ref) async {
    final text = await _showPasteDialog(context);
    if (text == null || text.trim().isEmpty) return;
    if (!context.mounted) return;
    await _doImport(context, ref, text);
  }

  Future<void> _importFromFile(BuildContext context, WidgetRef ref) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['json', 'txt'],
      withData: true,
    );
    if (result == null || result.files.isEmpty) return;
    final bytes = result.files.first.bytes;
    if (bytes == null) return;
    if (!context.mounted) return;
    await _doImport(context, ref, utf8.decode(bytes, allowMalformed: true));
  }

  Future<void> _importFromUrl(BuildContext context, WidgetRef ref) async {
    final url = await _showUrlDialog(context);
    if (url == null || url.isEmpty) return;
    try {
      final body = await Http.instance.get(url);
      if (!context.mounted) return;
      await _doImport(context, ref, body);
    } catch (e) {
      if (context.mounted) _toast(context, '下载失败: $e');
    }
  }

  Future<void> _doImport(BuildContext context, WidgetRef ref, String content) async {
    try {
      final n = await ref.read(sourcesProvider.notifier).importJson(content);
      if (context.mounted) {
        _toast(context, n > 0 ? '成功导入 $n 个书源' : '未识别到有效书源');
      }
    } catch (e) {
      if (context.mounted) _toast(context, '导入失败: 格式错误');
    }
  }

  void _toast(BuildContext context, String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<String?> _showPasteDialog(BuildContext context) {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text('粘贴书源 JSON'),
        content: SizedBox(
          height: 220,
          child: TextField(
            controller: controller,
            maxLines: null,
            expands: true,
            textAlignVertical: TextAlignVertical.top,
            decoration: const InputDecoration(
              hintText: '[{"bookSourceUrl":...}]',
              border: OutlineInputBorder(),
            ),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, controller.text),
            child: const Text('导入'),
          ),
        ],
      ),
    );
  }

  Future<String?> _showUrlDialog(BuildContext context) {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text('书源 URL'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.url,
          decoration: const InputDecoration(
              hintText: 'https://...', border: OutlineInputBorder()),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: const Text('导入'),
          ),
        ],
      ),
    );
  }
}
