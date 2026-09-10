import 'dart:ui';

import 'package:flutter/material.dart';

import '../core/theme.dart';

/// 毛玻璃容器
class GlassContainer extends StatelessWidget {
  final Widget child;
  final BorderRadius? borderRadius;
  final double blur;
  final EdgeInsetsGeometry? padding;
  final Color? fill;
  final bool showBorder;

  const GlassContainer({
    super.key,
    required this.child,
    this.borderRadius,
    this.blur = 18,
    this.padding,
    this.fill,
    this.showBorder = true,
  });

  @override
  Widget build(BuildContext context) {
    final radius = borderRadius ?? BorderRadius.circular(24);
    return ClipRRect(
      borderRadius: radius,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            color: fill ?? Glass.fill(context),
            borderRadius: radius,
            border: showBorder
                ? Border.all(color: Glass.border(context), width: 1)
                : null,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.06),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: child,
        ),
      ),
    );
  }
}

/// 悬浮毛玻璃底部导航（胶囊样式）
class GlassNavBar extends StatelessWidget {
  final int index;
  final ValueChanged<int> onTap;
  final List<NavItem> items;

  const GlassNavBar({
    super.key,
    required this.index,
    required this.onTap,
    required this.items,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 12),
        child: GlassContainer(
          borderRadius: BorderRadius.circular(32),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: List.generate(items.length, (i) {
              final selected = i == index;
              return GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => onTap(i),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 220),
                  curve: Curves.easeOutCubic,
                  padding: EdgeInsets.symmetric(
                      horizontal: selected ? 18 : 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: selected
                        ? scheme.primary.withOpacity(0.14)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        items[i].icon,
                        size: 24,
                        color: selected
                            ? scheme.primary
                            : scheme.onSurface.withOpacity(0.55),
                      ),
                      if (selected) ...[
                        const SizedBox(height: 2),
                        Text(
                          items[i].label,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: scheme.primary,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }
}

class NavItem {
  final IconData icon;
  final String label;
  const NavItem(this.icon, this.label);
}
