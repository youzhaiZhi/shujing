import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/models.dart';
import '../source/replacer.dart';
import '../state/providers.dart';
import '../widgets/glass.dart';

/// 净化规则管理（参考阅读3.0「替换规则」）
class ReplaceRulesPage extends ConsumerWidget {
  const ReplaceRulesPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rules = ref.watch(replaceRulesProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('净化规则'),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_horiz_rounded),
            onSelected: (v) => _onMenu(context, ref, v),
            itemBuilder: (_) => [
              const PopupMenuItem(value: 'preset', child: Text('添加预置规则')),
              const PopupMenuItem(value: 'import', child: Text('导入 JSON')),
              const PopupMenuItem(value: 'export', child: Text('导出全部')),
            ],
          ),
          IconButton(
            icon: const Icon(Icons.add_rounded),
            tooltip: '新建规则',
            onPressed: () => _edit(context, ref, null),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: rules.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('加载失败: $e')),
        data: (list) {
          if (list.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.auto_fix_high_rounded,
                      size: 72,
                      color: Theme.of(context).colorScheme.outlineVariant),
                  const SizedBox(height: 16),
                  const Text('还没有净化规则'),
                  const SizedBox(height: 6),
                  Text('用正则清除正文里的广告、水印、"本章完"等杂质',
                      style: TextStyle(
                          fontSize: 12,
                          color: Theme.of(context)
                              .colorScheme
                              .onSurface
                              .withOpacity(0.45))),
                  const SizedBox(height: 24),
                  FilledButton.icon(
                    onPressed: () => _onMenu(context, ref, 'preset'),
                    icon: const Icon(Icons.bolt_rounded),
                    label: const Text('一键添加预置规则'),
                  ),
                ],
              ),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
            itemCount: list.length,
            itemBuilder: (context, i) {
              final r = list[i];
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: SoftCard(
                  borderRadius: BorderRadius.circular(20),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 6),
                  child: ListTile(
                    contentPadding: EdgeInsets.zero,
                    onTap: () => _edit(context, ref, r),
                    title: Text(r.name,
                        maxLines: 1, overflow: TextOverflow.ellipsis),
                    subtitle: Text(
                      r.isRegex ? r.pattern : '文本：${r.pattern}',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 12, fontFamily: 'monospace'),
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Switch(
                          value: r.enabled,
                          onChanged: (v) => ref
                              .read(replaceRulesProvider.notifier)
                              .setEnabled(r.id!, v),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete_outline_rounded, size: 20),
                          onPressed: () => _confirmDelete(context, ref, r),
                        ),
                      ],
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

  void _onMenu(BuildContext context, WidgetRef ref, String v) {
    switch (v) {
      case 'preset':
        ref.read(replaceRulesProvider.notifier).addPresets().then((n) {
          if (context.mounted) {
            _toast(context, n > 0 ? '已添加 $n 条预置规则' : '预置规则已全部存在');
          }
        });
      case 'import':
        _importDialog(context, ref);
      case 'export':
        final list = ref.read(replaceRulesProvider).value ?? [];
        final json = Replacer.exportJson(list);
        Clipboard.setData(ClipboardData(text: json));
        _toast(context, '已复制 ${list.length} 条规则到剪贴板');
    }
  }

  Future<void> _importDialog(BuildContext context, WidgetRef ref) async {
    final controller = TextEditingController();
    final text = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text('导入净化规则'),
        content: SizedBox(
          height: 220,
          child: TextField(
            controller: controller,
            maxLines: null,
            expands: true,
            textAlignVertical: TextAlignVertical.top,
            decoration: const InputDecoration(
              hintText: '[{"name":"...","rule":"正则","replacement":""}]',
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
    if (text == null || text.trim().isEmpty) return;
    try {
      final n = await ref.read(replaceRulesProvider.notifier).importJson(text);
      if (context.mounted) {
        _toast(context, n > 0 ? '成功导入 $n 条规则' : '未识别到有效规则（或已存在）');
      }
    } catch (e) {
      if (context.mounted) _toast(context, '导入失败：格式错误');
    }
  }

  void _confirmDelete(BuildContext context, WidgetRef ref, ReplaceRule r) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text('删除规则'),
        content: Text('确定删除「${r.name}」？'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              ref.read(replaceRulesProvider.notifier).delete(r.id!);
            },
            child: const Text('删除'),
          ),
        ],
      ),
    );
  }

  Future<void> _edit(BuildContext context, WidgetRef ref, ReplaceRule? r) async {
    final result = await showModalBottomSheet<ReplaceRule>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => _RuleEditor(rule: r),
    );
    if (result == null) return;
    final notifier = ref.read(replaceRulesProvider.notifier);
    if (r == null) {
      await notifier.add(result);
    } else {
      await notifier.saveRule(result.copyWith(id: r.id));
    }
  }

  void _toast(BuildContext context, String msg) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(msg)));
  }
}

class _RuleEditor extends StatefulWidget {
  final ReplaceRule? rule;
  const _RuleEditor({this.rule});

  @override
  State<_RuleEditor> createState() => _RuleEditorState();
}

class _RuleEditorState extends State<_RuleEditor> {
  late final TextEditingController _name;
  late final TextEditingController _pattern;
  late final TextEditingController _replacement;
  late bool _isRegex;
  late bool _enabled;

  @override
  void initState() {
    super.initState();
    final r = widget.rule;
    _name = TextEditingController(text: r?.name ?? '');
    _pattern = TextEditingController(text: r?.pattern ?? '');
    _replacement = TextEditingController(text: r?.replacement ?? '');
    _isRegex = r?.isRegex ?? true;
    _enabled = r?.enabled ?? true;
  }

  @override
  void dispose() {
    _name.dispose();
    _pattern.dispose();
    _replacement.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: EdgeInsets.fromLTRB(
          20, 16, 20, MediaQuery.of(context).viewInsets.bottom + 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(widget.rule == null ? '新建规则' : '编辑规则',
                  style: const TextStyle(
                      fontSize: 17, fontWeight: FontWeight.w700)),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.close_rounded),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const SizedBox(height: 4),
          TextField(
            controller: _name,
            decoration: const InputDecoration(labelText: '名称'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _pattern,
            maxLines: 3,
            style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
            decoration: InputDecoration(
              labelText: _isRegex ? '正则表达式（可用 ## 分隔多条）' : '要删除的文本',
              border: const OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _replacement,
            decoration: const InputDecoration(
                labelText: '替换为（留空即删除）', border: OutlineInputBorder()),
          ),
          const SizedBox(height: 8),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('正则模式'),
            subtitle: Text('关闭则按纯文本匹配删除',
                style: TextStyle(
                    fontSize: 12, color: scheme.onSurface.withOpacity(0.45))),
            value: _isRegex,
            onChanged: (v) => setState(() => _isRegex = v),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('启用'),
            value: _enabled,
            onChanged: (v) => setState(() => _enabled = v),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: () {
                if (_pattern.text.trim().isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('规则内容不能为空')));
                  return;
                }
                Navigator.pop(
                  context,
                  ReplaceRule(
                    name: _name.text.trim().isEmpty
                        ? '未命名规则'
                        : _name.text.trim(),
                    pattern: _pattern.text.trim(),
                    replacement: _replacement.text,
                    isRegex: _isRegex,
                    enabled: _enabled,
                  ),
                );
              },
              child: Text(widget.rule == null ? '创建' : '保存'),
            ),
          ),
        ],
      ),
    );
  }
}
