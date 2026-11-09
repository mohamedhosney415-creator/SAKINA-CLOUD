import 'package:flutter/material.dart';

class QuranGameLogo extends StatelessWidget {
  final double size;
  const QuranGameLogo({super.key, this.size = 56});
  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(size * .28),
          gradient: const LinearGradient(
            colors: [Color(0xFFB98B45), Color(0xFFE6C77A)],
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFB98B45).withAlpha(65),
              blurRadius: 16,
              offset: const Offset(0, 7),
            ),
          ],
        ),
        child: Icon(
          Icons.menu_book_rounded,
          color: const Color(0xFF173A36),
          size: size * .52,
        ),
      );
}
