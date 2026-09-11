import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_tts/flutter_tts.dart';

import '../data/db.dart';
import '../data/models.dart';
import '../source/replacer.dart';
import '../source/source_service.dart';
import '../state/providers.dart';
import '../widgets/glass.dart';

class ReaderPage extends ConsumerStatefulWidget {
  final Book book;
  final BookSource source;
  final List<Chapter>? chapters;
  final int startIdx;
  const ReaderPage(
      {super.key,
      required this.book,
      required this.source,
      this.chapters,
      this.startIdx = 0});

  @override
  ConsumerState<ReaderPage> createState() => _ReaderPageState();
}

class _ReaderPageState extends ConsumerState<ReaderPage>
    with WidgetsBindingObserver {
  final _scroll = ScrollController();
  List<Chapter> _chapters = [];
  int _idx = 0;
  String? _body;
  bool _loading = true;
  bool _menuVisible = false;
  bool _tocVisible = false;
  bool _bookmarkVisible = false;
  int _scrollOffset = 0;
  Timer? _statTimer;
  int _sessionSeconds = 0;
  final FlutterTts _tts = FlutterTts();
  bool _ttsPlaying = false;
  bool _ttsPanel = false;

  /// 应用净化规则后的正文（不污染缓存，改规则即时生效）
  String? get _cleanBody =>
      _body == null ? null : Replacer.instance.clean(_body!);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _idx = widget.startIdx;
    _initTts();
    WidgetsBinding.instance.addPostFrameCallback((_) => _boot());
  }

  Future<void> _initTts() async {
    try {
      await _tts.setLanguage('zh-CN');
      await _tts.awaitSpeakCompletion(true);
      _tts.setCompletionHandler(() {
        if (_ttsPlaying) _nextChapterForTts();
      });
    } catch (_) {}
  }

  Future<void> _boot() async {
    final bookId = widget.book.id!;
    var chapters = widget.chapters ?? await AppDb.instance.chapters(bookId);
    if (chapters.isEmpty) {
      chapters = await SourceService.toc(
          widget.source,
          widget.book.tocUrl.isEmpty ? widget.book.bookUrl : widget.book.tocUrl);
      await AppDb.instance.saveChapters(bookId, chapters);
    }
    final progress = await AppDb.instance.progress(bookId);
    if (mounted) {
      setState(() {
        _chapters = chapters;
        _idx = progress?.$1 ?? widget.startIdx;
        _scrollOffset = progress?.$2 ?? 0;
      });
      _loadChapter();
      _startStats();
    }
  }

  void _startStats() {
    _statTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      _sessionSeconds += 30;
      AppDb.instance.addReadTime(widget.book.id!, 30);
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      _saveProgress();
      _stopTts();
    }
  }

  Future<void> _loadChapter() async {
    if (_idx < 0 || _idx >= _chapters.length) return;
    setState(() {
      _loading = true;
      _body = null;
    });
    final cached = await AppDb.instance.content(widget.book.id!, _idx);
    if (cached != null) {
      if (!mounted) return;
      setState(() {
        _body = cached;
        _loading = false;
      });
      _restoreScroll();
      return;
    }
    try {
      final body = await SourceService.content(
          widget.source, _chapters[_idx].url);
      await AppDb.instance.saveContent(widget.book.id!, _idx, body);
      if (!mounted) return;
      setState(() {
        _body = body.isEmpty ? '（该章节内容为空，可能源站规则不兼容）' : body;
        _loading = false;
      });
      _restoreScroll();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _body = null;
        _loading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('加载失败: $e'), duration: const Duration(seconds: 2)));
    }
  }

  void _restoreScroll() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients && _scrollOffset > 0) {
        _scroll.jumpTo(_scrollOffset.toDouble());
      }
    });
  }

  void _saveProgress() {
    if (!_scroll.hasClients) return;
    AppDb.instance.saveProgress(
        widget.book.id!, _idx, _scroll.position.pixels.round());
  }

  void _goto(int idx) {
    if (idx < 0 || idx >= _chapters.length || idx == _idx) return;
    _saveProgress();
    setState(() {
      _idx = idx;
      _scrollOffset = 0;
    });
    _loadChapter();
  }

  // ---------- TTS ----------

  Future<void> _toggleTts() async {
    if (_ttsPlaying) {
      await _stopTts();
      return;
    }
    final clean = _cleanBody;
    if (clean == null || clean.isEmpty) return;
    setState(() => _ttsPlaying = true);
    final s = ref.read(settingsProvider);
    await _tts.setSpeechRate((s.ttsRate * 0.5).clamp(0.1, 1.0));
    await _tts.setPitch(s.ttsPitch);
    await _tts.speak(clean);
  }

  Future<void> _stopTts() async {
    await _tts.stop();
    if (mounted) setState(() => _ttsPlaying = false);
  }

  Future<void> _nextChapterForTts() async {
    if (_idx + 1 >= _chapters.length) {
      if (mounted) setState(() => _ttsPlaying = false);
      return;
    }
    _goto(_idx + 1);
    await Future.delayed(const Duration(milliseconds: 600));
    if (_ttsPlaying && mounted) {
      final s = ref.read(settingsProvider);
      await _tts.setSpeechRate((s.ttsRate * 0.5).clamp(0.1, 1.0));
      await _tts.speak(_cleanBody ?? '');
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _statTimer?.cancel();
    if (_sessionSeconds > 0) _saveProgress();
    _tts.stop();
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider);
    ref.watch(replaceRulesProvider); // 确保净化规则已加载
    final bg = readerBgs[settings.readerBg];
    final dark = settings.readerBg == 4;
    final textColor = dark ? const Color(0xFFB8BDB8) : const Color(0xFF2A2C2A);

    return Scaffold(
      backgroundColor: bg,
      body: Stack(
        children: [
          // 正文
          GestureDetector(
            onTap: () => setState(() {
              _menuVisible = !_menuVisible;
              _tocVisible = false;
              _bookmarkVisible = false;
            }),
            child: NotificationListener<ScrollNotification>(
              onNotification: (n) {
                if (n is ScrollEndNotification) _saveProgress();
                return false;
              },
              child: ListView(
                controller: _scroll,
                physics: const BouncingScrollPhysics(),
                padding: EdgeInsets.fromLTRB(
                    24,
                    _menuVisible ? 90 : MediaQuery.paddingOf(context).top + 24,
                    24,
                    _menuVisible || _ttsPanel
                        ? 180
                        : MediaQuery.paddingOf(context).bottom + 32),
                children: [
                  Text(_chapters.isEmpty ? '' : _chapters[_idx].title,
                      style: TextStyle(
                          fontSize: settings.fontSize + 4,
                          fontWeight: FontWeight.w700,
                          color: textColor)),
                  const SizedBox(height: 20),
                  if (_loading)
                    const Padding(
                      padding: EdgeInsets.all(40),
                      child: Center(
                          child: SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2.5))),
                    )
                  else if (_body != null)
                    Text(_cleanBody!,
                        style: TextStyle(
                            fontSize: settings.fontSize,
                            height: settings.lineHeight,
                            color: textColor,
                            letterSpacing: 0.3)),
                ],
              ),
            ),
          ),
          // 左右翻页热区
          Positioned.fill(
            child: Row(
              children: [
                Expanded(
                  flex: 1,
                  child: GestureDetector(
                    behavior: HitTestBehavior.translucent,
                    onTap: () => _goto(_idx - 1),
                  ),
                ),
                const Expanded(flex: 2, child: SizedBox()),
                Expanded(
                  flex: 1,
                  child: GestureDetector(
                    behavior: HitTestBehavior.translucent,
                    onTap: () => _goto(_idx + 1),
                  ),
                ),
              ],
            ),
          ),
          // 顶栏
          if (_menuVisible)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 4, 12, 0),
                  child: SoftCard(
                    borderRadius: BorderRadius.circular(20),
                    child: Row(
                      children: [
                        IconButton(
                            icon: const Icon(Icons.arrow_back_rounded),
                            onPressed: () {
                              _saveProgress();
                              Navigator.pop(context);
                            }),
                        Expanded(
                          child: Text(widget.book.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  fontWeight: FontWeight.w600)),
                        ),
                        IconButton(
                            icon: const Icon(Icons.toc_rounded),
                            onPressed: () => setState(() {
                              _tocVisible = !_tocVisible;
                              _bookmarkVisible = false;
                            })),
                        IconButton(
                            icon: const Icon(Icons.bookmark_add_outlined),
                            onPressed: _addBookmark),
                        IconButton(
                            icon: const Icon(Icons.record_voice_over_outlined),
                            onPressed: () => setState(() {
                              _ttsPanel = !_ttsPanel;
                              _menuVisible = false;
                            })),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          // 底部设置
          if (_menuVisible)
            Positioned(
              left: 12,
              right: 12,
              bottom: 12,
              child: SafeArea(
                child: _SettingsDrawer(
                  onBgChanged: (i) => ref
                      .read(settingsProvider.notifier)
                      .save(settings.copyWith(readerBg: i)),
                  onFontChanged: (v) => ref
                      .read(settingsProvider.notifier)
                      .save(settings.copyWith(fontSize: v)),
                ),
              ),
            ),
          // 目录抽屉
          if (_tocVisible)
            Positioned(
              top: 0,
              bottom: 0,
              left: 0,
              width: MediaQuery.sizeOf(context).width * 0.72,
              child: _TocDrawer(
                chapters: _chapters,
                current: _idx,
                onSelect: (i) {
                  setState(() => _tocVisible = false);
                  _goto(i);
                },
                onClose: () => setState(() => _tocVisible = false),
              ),
            ),
          // TTS 播放条
          if (_ttsPanel)
            Positioned(
              left: 16,
              right: 16,
              bottom: 16,
              child: SafeArea(
                child: SoftCard(
                  borderRadius: BorderRadius.circular(24),
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              _chapters.isEmpty ? '' : _chapters[_idx].title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  fontWeight: FontWeight.w600, fontSize: 14),
                            ),
                          ),
                          IconButton(
                              icon: Icon(_ttsPlaying
                                  ? Icons.pause_circle_filled_rounded
                                  : Icons.play_circle_fill_rounded),
                              iconSize: 40,
                              onPressed: _toggleTts),
                          IconButton(
                              icon: const Icon(Icons.close_rounded),
                              onPressed: () => setState(() {
                                _ttsPanel = false;
                                _stopTts();
                              })),
                        ],
                      ),
                      Row(
                        children: [
                          const Text('语速', style: TextStyle(fontSize: 12)),
                          Expanded(
                            child: Slider(
                              value: settings.ttsRate,
                              min: 0.5,
                              max: 2.0,
                              onChanged: (v) => ref
                                  .read(settingsProvider.notifier)
                                  .save(settings.copyWith(ttsRate: v)),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _addBookmark() async {
    await AppDb.instance
        .addBookmark(widget.book.id!, _idx, _chapters[_idx].title);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('已添加书签'), duration: Duration(seconds: 1)));
  }
}

class _SettingsDrawer extends ConsumerWidget {
  final ValueChanged<int> onBgChanged;
  final ValueChanged<double> onFontChanged;
  const _SettingsDrawer(
      {required this.onBgChanged, required this.onFontChanged});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    return SoftCard(
      borderRadius: BorderRadius.circular(24),
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 14),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              const Text('A-', style: TextStyle(fontSize: 13)),
              Expanded(
                child: Slider(
                    value: settings.fontSize,
                    min: 14,
                    max: 30,
                    onChanged: onFontChanged),
              ),
              const Text('A', style: TextStyle(fontSize: 18)),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: List.generate(readerBgs.length, (i) {
              final selected = settings.readerBg == i;
              return GestureDetector(
                onTap: () => onBgChanged(i),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: readerBgs[i],
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                        color: selected
                            ? Theme.of(context).colorScheme.primary
                            : Colors.black12,
                        width: selected ? 2.5 : 1),
                  ),
                  child: selected
                      ? Icon(Icons.check_rounded,
                          size: 16,
                          color: i == 4 ? Colors.white : Colors.black54)
                      : null,
                ),
              );
            }),
          ),
        ],
      ),
    );
  }
}

class _TocDrawer extends StatelessWidget {
  final List<Chapter> chapters;
  final int current;
  final ValueChanged<int> onSelect;
  final VoidCallback onClose;
  const _TocDrawer(
      {required this.chapters,
      required this.current,
      required this.onSelect,
      required this.onClose});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Stack(
      children: [
        Positioned.fill(child: GestureDetector(
            onTap: onClose, child: Container(color: Colors.black26))),
        Positioned.fill(
          child: ClipRRect(
            borderRadius: const BorderRadius.horizontal(right: Radius.circular(24)),
            child: Container(
              color: scheme.surface,
              child: SafeArea(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 12, 8, 4),
                        child: Row(
                          children: [
                            Text('目录 (${chapters.length})',
                                style: const TextStyle(
                                    fontSize: 16, fontWeight: FontWeight.w600)),
                            const Spacer(),
                            IconButton(
                                icon: const Icon(Icons.close_rounded),
                                onPressed: onClose),
                          ],
                        ),
                      ),
                      Expanded(
                        child: ListView.builder(
                          padding: const EdgeInsets.only(bottom: 40),
                          itemCount: chapters.length,
                          itemBuilder: (context, i) {
                            final selected = i == current;
                            return ListTile(
                              dense: true,
                              selected: selected,
                              selectedTileColor:
                                  scheme.primary.withOpacity(0.1),
                              title: Text(chapters[i].title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                      fontSize: 14,
                                      color: selected
                                          ? scheme.primary
                                          : null)),
                              onTap: () => onSelect(i),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}


