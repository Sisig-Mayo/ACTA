import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class BrandLoadingScreen extends StatefulWidget {
  const BrandLoadingScreen({
    super.key,
    this.message = 'Preparing ACTA...',
    this.backgroundColor = Colors.white,
  });

  final String message;
  final Color backgroundColor;

  @override
  State<BrandLoadingScreen> createState() => _BrandLoadingScreenState();
}

class _BrandLoadingScreenState extends State<BrandLoadingScreen>
    with SingleTickerProviderStateMixin {
  static const _logoColor = Color(0xFF13587A);

  late final AnimationController _controller;
  late final Animation<double> _floatOffset;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    )..repeat(reverse: true);

    _floatOffset = Tween<double>(begin: -8, end: 8).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOutSine),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: widget.backgroundColor,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedBuilder(
              animation: _floatOffset,
              child: Image.asset(
                'lib/assets/logo-1.png',
                height: 112,
                fit: BoxFit.contain,
                errorBuilder: (context, error, stackTrace) {
                  return const Icon(Icons.shield, color: _logoColor, size: 112);
                },
              ),
              builder: (context, child) {
                return Transform.translate(
                  offset: Offset(0, _floatOffset.value),
                  child: child,
                );
              },
            ),
            const SizedBox(height: 28),
            SizedBox(
              width: 190,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(999),
                child: const LinearProgressIndicator(
                  minHeight: 5,
                  color: _logoColor,
                  backgroundColor: Color(0xFFE5E7EB),
                ),
              ),
            ),
            const SizedBox(height: 18),
            Text(
              widget.message,
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF111827),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
