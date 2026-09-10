import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../state/providers.dart';
import '../widgets/glass.dart';

class ProfilePage extends ConsumerWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final settings = ref.watch(settingsProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('我的')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
        children: [
          GlassContainer(
            borderRadius: BorderRadius.circular(24),
            padding: const EdgeInsets.all(24),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 28,
                  backgroundColor: scheme.primary.withOpacity(0.15),
                  child: Icon(Icons.auto_stories_rounded,
                      size: 30, color: scheme.primary),
                ),
                const SizedBox(width: 16),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('书径',
                        style: TextStyle(
                            fontSize: 20, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 2),
                    Text('v0.1.0 · 本地阅读',
                        style: TextStyle(
                            fontSize: 12,
                            color: scheme.onSurface.withOpacity(0.5))),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          _SectionLabel('外观'),
          GlassContainer(
            borderRadius: BorderRadius.circular(20),
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.dark_mode_outlined),
                  title: const Text('深色模式'),
                  trailing: DropdownButton<ThemeMode>(
                    value: settings.themeMode,
                    underline: const SizedBox(),
                    onChanged: (m) => m == null
                        ? null
                        : ref
                            .read(settingsProvider.notifier)
                            .save(settings.copyWith(themeMode: m)),
                    items: const [
                      DropdownMenuItem(
                          value: ThemeMode.system, child: Text('跟随系统')),
                      DropdownMenuItem(
                          value: ThemeMode.light, child: Text('浅色')),
                      DropdownMenuItem(
                          value: ThemeMode.dark, child: Text('深色')),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _SectionLabel('阅读'),
          GlassContainer(
            borderRadius: BorderRadius.circular(20),
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.text_fields_rounded),
                  title: const Text('字号'),
                  trailing: Text('${settings.fontSize.round()}',
                      style: TextStyle(color: scheme.primary)),
                  onTap: () => _fontSizeDialog(context, ref, settings),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.record_voice_over_outlined),
                  title: const Text('TTS 语速'),
                  trailing: Text('${settings.ttsRate.toStringAsFixed(1)}x',
                      style: TextStyle(color: scheme.primary)),
                  onTap: () => _ttsDialog(context, ref, settings),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _SectionLabel('AI 快读（即将上线）'),
          GlassContainer(
            borderRadius: BorderRadius.circular(20),
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.smart_toy_outlined),
                  title: const Text('API 地址'),
                  subtitle: Text(settings.aiBaseUrl,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontSize: 12,
                          color: scheme.onSurface.withOpacity(0.5))),
                  onTap: () => _editText(context, 'API 地址 (OpenAI 兼容)',
                          settings.aiBaseUrl, (v) {
                    ref.read(settingsProvider.notifier)
                        .save(settings.copyWith(aiBaseUrl: v));
                  }),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.key_outlined),
                  title: const Text('API Key'),
                  subtitle: Text(
                      settings.aiKey.isEmpty
                          ? '未设置'
                          : '${settings.aiKey.substring(0, 4)}••••',
                      style: TextStyle(
                          fontSize: 12,
                          color: scheme.onSurface.withOpacity(0.5))),
                  onTap: () => _editText(context, 'API Key', settings.aiKey,
                          (v) {
                    ref.read(settingsProvider.notifier)
                        .save(settings.copyWith(aiKey: v));
                  }, obscure: true),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.model_training_outlined),
                  title: const Text('模型名称'),
                  subtitle: Text(settings.aiModel,
                      style: TextStyle(
                          fontSize: 12,
                          color: scheme.onSurface.withOpacity(0.5))),
                  onTap: () =>
                      _editText(context, '模型', settings.aiModel, (v) {
                    ref.read(settingsProvider.notifier)
                        .save(settings.copyWith(aiModel: v));
                  }),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _SectionLabel('数据'),
          GlassContainer(
            borderRadius: BorderRadius.circular(20),
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.backup_outlined),
                  title: const Text('备份数据'),
                  subtitle: const Text('导出书架与书源',
                      style: TextStyle(fontSize: 12)),
                  onTap: () async {
                    final p = await SharedPreferences.getInstance();
                    await p.setBool('backup_hint', true);
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('备份功能开发中')));
                    }
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _fontSizeDialog(BuildContext context, WidgetRef ref, Settings s) {
    double v = s.fontSize;
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSt) => AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          title: const Text('字号'),
          content: Slider(
              value: v,
              min: 14,
              max: 30,
              label: '${v.round()}',
              onChanged: (nv) => setSt(() => v = nv)),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('取消')),
            FilledButton(
                onPressed: () {
                  ref
                      .read(settingsProvider.notifier)
                      .save(s.copyWith(fontSize: v));
                  Navigator.pop(ctx);
                },
                child: const Text('确定')),
          ],
        ),
      ),
    );
  }

  void _ttsDialog(BuildContext context, WidgetRef ref, Settings s) {
    double rate = s.ttsRate;
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSt) => AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          title: const Text('TTS 语速'),
          content: Slider(
              value: rate,
              min: 0.5,
              max: 2.0,
              label: '${rate.toStringAsFixed(1)}x',
              onChanged: (nv) => setSt(() => rate = nv)),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('取消')),
            FilledButton(
                onPressed: () {
                  ref
                      .read(settingsProvider.notifier)
                      .save(s.copyWith(ttsRate: rate));
                  Navigator.pop(ctx);
                },
                child: const Text('确定')),
          ],
        ),
      ),
    );
  }

  void _editText(BuildContext context, String title, String initial,
      ValueChanged<String> onSave,
      {bool obscure = false}) {
    final c = TextEditingController(text: initial);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Text(title),
        content: TextField(
          controller: c,
          obscureText: obscure,
          decoration: const InputDecoration(border: OutlineInputBorder()),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('取消')),
          FilledButton(
              onPressed: () {
                onSave(c.text.trim());
                Navigator.pop(ctx);
              },
              child: const Text('保存')),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 4, 8, 8),
      child: Text(text,
          style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color:
                  Theme.of(context).colorScheme.onSurface.withOpacity(0.45))),
    );
  }
}
