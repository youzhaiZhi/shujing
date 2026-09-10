import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/db.dart';
import '../data/models.dart';

// ---------- 数据库 ----------
final dbProvider = Provider<AppDb>((_) => AppDb.instance);

// ---------- 书架 ----------
class ShelfNotifier extends AsyncNotifier<List<Book>> {
  @override
  Future<List<Book>> build() => AppDb.instance.shelfBooks();

  Future<void> refresh() async {
    state = AsyncValue.data(await AppDb.instance.shelfBooks());
  }

  Future<void> remove(int bookId) async {
    await AppDb.instance.setInShelf(bookId, false);
    await refresh();
  }
}

final shelfProvider =
    AsyncNotifierProvider<ShelfNotifier, List<Book>>(ShelfNotifier.new);

// ---------- 书源 ----------
class SourcesNotifier extends AsyncNotifier<List<BookSource>> {
  @override
  Future<List<BookSource>> build() => AppDb.instance.sources();

  Future<void> refresh() async {
    state = AsyncValue.data(await AppDb.instance.sources());
  }

  Future<int> importJson(String content) async {
    final decoded = jsonDecode(content);
    final list = decoded is List ? decoded : [decoded];
    final sources = list
        .whereType<Map<String, dynamic>>()
        .map((j) => BookSource.fromJson(j))
        .toList();
    if (sources.isEmpty) return 0;
    await AppDb.instance.importSources(sources);
    await refresh();
    return sources.length;
  }

  Future<void> setEnabled(int id, bool enabled) async {
    await AppDb.instance.setSourceEnabled(id, enabled);
    await refresh();
  }

  Future<void> delete(int id) async {
    await AppDb.instance.deleteSource(id);
    await refresh();
  }
}

final sourcesProvider =
    AsyncNotifierProvider<SourcesNotifier, List<BookSource>>(SourcesNotifier.new);

// ---------- 设置 ----------
class Settings {
  final ThemeMode themeMode;
  final double fontSize;
  final double lineHeight;
  final int readerBg; // 0白 1米黄 2羊皮纸 3绿豆 4黑
  final bool turnWithVolume;
  final double ttsRate;
  final double ttsPitch;
  final String aiBaseUrl;
  final String aiKey;
  final String aiModel;

  const Settings({
    this.themeMode = ThemeMode.system,
    this.fontSize = 20,
    this.lineHeight = 1.7,
    this.readerBg = 1,
    this.turnWithVolume = false,
    this.ttsRate = 1.0,
    this.ttsPitch = 1.0,
    this.aiBaseUrl = 'https://api.openai.com/v1',
    this.aiKey = '',
    this.aiModel = 'gpt-4o-mini',
  });

  Settings copyWith({
    ThemeMode? themeMode,
    double? fontSize,
    double? lineHeight,
    int? readerBg,
    bool? turnWithVolume,
    double? ttsRate,
    double? ttsPitch,
    String? aiBaseUrl,
    String? aiKey,
    String? aiModel,
  }) =>
      Settings(
        themeMode: themeMode ?? this.themeMode,
        fontSize: fontSize ?? this.fontSize,
        lineHeight: lineHeight ?? this.lineHeight,
        readerBg: readerBg ?? this.readerBg,
        turnWithVolume: turnWithVolume ?? this.turnWithVolume,
        ttsRate: ttsRate ?? this.ttsRate,
        ttsPitch: ttsPitch ?? this.ttsPitch,
        aiBaseUrl: aiBaseUrl ?? this.aiBaseUrl,
        aiKey: aiKey ?? this.aiKey,
        aiModel: aiModel ?? this.aiModel,
      );
}

class SettingsNotifier extends Notifier<Settings> {
  static const _prefsKey = 'settings';

  @override
  Settings build() {
    // 同步读取占位，实际通过 load()
    return const Settings();
  }

  Future<void> load() async {
    final p = await SharedPreferences.getInstance();
    final raw = p.getString(_prefsKey);
    if (raw == null) return;
    try {
      final j = jsonDecode(raw) as Map<String, dynamic>;
      state = Settings(
        themeMode: ThemeMode.values[j['themeMode'] as int? ?? 0],
        fontSize: (j['fontSize'] as num?)?.toDouble() ?? 20,
        lineHeight: (j['lineHeight'] as num?)?.toDouble() ?? 1.7,
        readerBg: j['readerBg'] as int? ?? 1,
        turnWithVolume: j['turnWithVolume'] as bool? ?? false,
        ttsRate: (j['ttsRate'] as num?)?.toDouble() ?? 1.0,
        ttsPitch: (j['ttsPitch'] as num?)?.toDouble() ?? 1.0,
        aiBaseUrl: j['aiBaseUrl'] as String? ?? 'https://api.openai.com/v1',
        aiKey: j['aiKey'] as String? ?? '',
        aiModel: j['aiModel'] as String? ?? 'gpt-4o-mini',
      );
    } catch (_) {}
  }

  Future<void> save(Settings s) async {
    state = s;
    final p = await SharedPreferences.getInstance();
    await p.setString(_prefsKey, jsonEncode({
      'themeMode': s.themeMode.index,
      'fontSize': s.fontSize,
      'lineHeight': s.lineHeight,
      'readerBg': s.readerBg,
      'turnWithVolume': s.turnWithVolume,
      'ttsRate': s.ttsRate,
      'ttsPitch': s.ttsPitch,
      'aiBaseUrl': s.aiBaseUrl,
      'aiKey': s.aiKey,
      'aiModel': s.aiModel,
    }));
  }
}

final settingsProvider = NotifierProvider<SettingsNotifier, Settings>(SettingsNotifier.new);

/// 阅读器背景色板
const readerBgs = <Color>[
  Color(0xFFFFFFFF),
  Color(0xFFF7F2DF),
  Color(0xFFEADFC8),
  Color(0xFFCCDFD4),
  Color(0xFF161816),
];
const readerBgNames = ['默认', '米黄', '羊皮纸', '绿豆', '夜间'];
