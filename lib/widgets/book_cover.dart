import 'package:flutter/material.dart';

/// 无网络封面时，用书名生成文字封面（渐变底 + 竖排书名）
class BookCover extends StatelessWidget {
  final String? imageUrl;
  final String title;
  final double width;
  final double radius;

  const BookCover({
    super.key,
    this.imageUrl,
    required this.title,
    this.width = 100,
    this.radius = 8,
  });

  @override
  Widget build(BuildContext context) {
    final height = width * 4 / 3;
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: SizedBox(
        width: width,
        height: height,
        child: (imageUrl == null || imageUrl!.isEmpty)
            ? _textCover()
            : Image.network(
                imageUrl!,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => _textCover(),
                loadingBuilder: (_, child, prog) =>
                    prog == null ? child : _textCover(),
              ),
      ),
    );
  }

  Widget _textCover() {
    final colors = _palette(title);
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: colors,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: LayoutBuilder(builder: (context, c) {
          final chars = title.characters.toList();
          final max = (c.maxHeight / 18).floor().clamp(1, 12);
          final shown = chars.length > max
              ? chars.sublist(0, max).join() + '…'
              : title;
          return Center(
            child: Text(
              shown,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white.withOpacity(0.95),
                fontSize: 15,
                fontWeight: FontWeight.w600,
                height: 1.4,
                shadows: [Shadow(color: Colors.black26, blurRadius: 4)],
              ),
            ),
          );
        }),
      ),
    );
  }

  List<Color> _palette(String seed) {
    final hash = seed.codeUnits.fold<int>(7, (a, b) => (a * 31 + b) & 0x7fffffff);
    const palettes = [
      [Color(0xFF43A047), Color(0xFF1B5E20)],
      [Color(0xFF5C6BC0), Color(0xFF283593)],
      [Color(0xFF26A69A), Color(0xFF00695C)],
      [Color(0xFFEF5350), Color(0xFFB71C1C)],
      [Color(0xFFFFA726), Color(0xFFE65100)],
      [Color(0xFF7E57C2), Color(0xFF311B92)],
      [Color(0xFF66BB6A), Color(0xFF1B5E20)],
      [Color(0xFF42A5F5), Color(0xFF0D47A1)],
    ];
    return palettes[hash % palettes.length];
  }
}
