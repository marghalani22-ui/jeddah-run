import 'package:flutter/material.dart';

import '../theme/tokens.dart';

const _grads = [
  [Color(0xFFF25C2C), Color(0xFFFFB81C)],
  [Color(0xFF0B6E8A), Color(0xFF12A4B8)],
  [Color(0xFF4B2FC9), Color(0xFFB04BD9)],
  [Color(0xFF1E8E57), Color(0xFF2FB36C)],
  [Color(0xFFD9465F), Color(0xFFF2894B)],
];

/// A friend's initial on a gradient picked from their name. With [ring], a
/// sunset ring marks someone who ran this week (like a story ring).
class FriendAvatar extends StatelessWidget {
  const FriendAvatar({super.key, required this.name, this.size = 48, this.ring = false});
  final String name;
  final double size;
  final bool ring;

  @override
  Widget build(BuildContext context) {
    final g = _grads[name.hashCode.abs() % _grads.length];
    final face = Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(shape: BoxShape.circle, gradient: LinearGradient(begin: Alignment.topRight, end: Alignment.bottomLeft, colors: g)),
      child: Text(name.isEmpty ? '؟' : name.characters.first,
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: size * .42)),
    );
    if (!ring) return face;
    return Container(
      padding: EdgeInsets.all(size * .055),
      decoration: const BoxDecoration(shape: BoxShape.circle, gradient: Grad.sunset),
      child: Container(
        padding: EdgeInsets.all(size * .05),
        decoration: BoxDecoration(shape: BoxShape.circle, color: context.pal.sand),
        child: face,
      ),
    );
  }
}

/// "الحين", "5د", "3س", "أمس", "4ي", or the date.
String chatAgo(DateTime? d) {
  if (d == null) return '';
  final diff = DateTime.now().difference(d);
  if (diff.inMinutes < 1) return 'الحين';
  if (diff.inMinutes < 60) return '${diff.inMinutes}د';
  if (diff.inHours < 24) return '${diff.inHours}س';
  if (diff.inDays < 2) return 'أمس';
  if (diff.inDays < 7) return '${diff.inDays}ي';
  return '${d.day}/${d.month}';
}
