import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/theme.dart';
import 'pages/home_page.dart';
import 'pages/profile_page.dart';
import 'pages/sources_page.dart';
import 'pages/stats_page.dart';
import 'state/providers.dart';
import 'widgets/glass.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const ProviderScope(child: ShuJingApp()));
}

class ShuJingApp extends ConsumerWidget {
  const ShuJingApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode = ref.watch(settingsProvider).themeMode;
    return MaterialApp(
      title: '书径',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: mode,
      builder: (context, child) => _PhoneFrame(child: child!),
      home: const HomeShell(),
    );
  }
}

/// Web 桌面浏览器下以手机画布呈现（居中、限宽、圆角边框）；
/// 移动端（窄屏）自动全屏。
class _PhoneFrame extends StatelessWidget {
  final Widget child;
  const _PhoneFrame({required this.child});

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    const phoneWidth = 430.0;
    const phoneHeight = 932.0;
    // 窄屏（手机）直接全屏
    if (size.width <= phoneWidth + 40) return child;
    return Center(
      child: Container(
        width: phoneWidth,
        height: size.height < phoneHeight ? size.height : phoneHeight,
        margin: const EdgeInsets.all(16),
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(28),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.18),
              blurRadius: 40,
              offset: const Offset(0, 12),
            ),
          ],
        ),
        child: MediaQuery(
          data: MediaQuery.of(context).copyWith(
            size: Size(phoneWidth,
                size.height < phoneHeight ? size.height : phoneHeight),
          ),
          child: child,
        ),
      ),
    );
  }
}

class HomeShell extends ConsumerStatefulWidget {
  const HomeShell({super.key});

  @override
  ConsumerState<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends ConsumerState<HomeShell> {
  int _index = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(settingsProvider.notifier).load();
    });
  }

  @override
  Widget build(BuildContext context) {
    final pages = const [
      HomePage(),
      SourcesPage(),
      StatsPage(),
      ProfilePage(),
    ];
    return Scaffold(
      extendBody: true,
      body: IndexedStack(index: _index, children: pages),
      bottomNavigationBar: GlassNavBar(
        index: _index,
        onTap: (i) => setState(() => _index = i),
        items: const [
          NavItem(Icons.home_rounded, '首页'),
          NavItem(Icons.cloud_download_rounded, '书源'),
          NavItem(Icons.pie_chart_outline_rounded, '统计'),
          NavItem(Icons.person_rounded, '我的'),
        ],
      ),
    );
  }
}
