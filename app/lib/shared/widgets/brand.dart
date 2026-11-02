import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/theme/timbang_colors.dart';

/// Seal-style emblem: a filled disc with a highlight ring and the scale glyph.
/// Shared across both themes; colors come from the active theme.
class TimbangEmblem extends StatelessWidget {
  const TimbangEmblem({super.key, this.size = 40, this.onDark = false});

  final double size;

  /// True when placed on a primary-colored band (draws a light disc instead).
  final bool onDark;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final c = TimbangColors.of(context);
    final disc = onDark ? scheme.onPrimary : scheme.primary;
    final glyph = onDark ? scheme.primary : scheme.onPrimary;
    return Semantics(
      label: 'TIMBANG',
      excludeSemantics: true,
      child: SizedBox.square(
        dimension: size,
        child: CustomPaint(
          painter: _SealPainter(disc: disc, ring: c.highlight),
          child: Center(
            child: Icon(Icons.balance, size: size * 0.52, color: glyph),
          ),
        ),
      ),
    );
  }
}

class _SealPainter extends CustomPainter {
  _SealPainter({required this.disc, required this.ring});
  final Color disc;
  final Color ring;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.shortestSide / 2;
    canvas.drawCircle(c, r, Paint()..color = ring);
    canvas.drawCircle(c, r * 0.88, Paint()..color = disc);
    // Fine inner rule, like an official seal.
    canvas.drawCircle(
      c,
      r * 0.78,
      Paint()
        ..color = ring.withValues(alpha: 0.85)
        ..style = PaintingStyle.stroke
        ..strokeWidth = math.max(1, r * 0.04),
    );
  }

  @override
  bool shouldRepaint(_SealPainter old) => old.disc != disc || old.ring != ring;
}

/// Emblem + "TIMBANG" + small-caps place line.
class TimbangWordmark extends StatelessWidget {
  const TimbangWordmark({
    super.key,
    this.size = 40,
    this.onDark = false,
    this.subtitle = 'NUEVA VIZCAYA',
  });

  final double size;
  final bool onDark;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final fg = onDark ? scheme.onPrimary : scheme.primary;
    final muted = onDark ? scheme.onPrimary : TimbangColors.of(context).textMuted;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        TimbangEmblem(size: size, onDark: onDark),
        SizedBox(width: size * 0.28),
        Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'TIMBANG',
              style: TextStyle(
                fontFamily: 'PublicSans',
                color: fg,
                fontSize: size * 0.5,
                height: 1.05,
                fontWeight: FontWeight.w800,
                letterSpacing: size * 0.06,
              ),
            ),
            if (subtitle != null)
              Text(
                subtitle!,
                style: TextStyle(
                  fontFamily: 'PublicSans',
                  color: muted,
                  fontSize: math.max(11, size * 0.24),
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.6,
                  height: 1.2,
                ),
              ),
          ],
        ),
      ],
    );
  }
}

/// Subtle contour lines (rice-terrace motif) drawn over primary bands.
class TerracePattern extends StatelessWidget {
  const TerracePattern({super.key, required this.child, this.opacity = 0.07});

  final Widget child;
  final double opacity;

  @override
  Widget build(BuildContext context) {
    final line = Theme.of(context).colorScheme.onPrimary.withValues(alpha: opacity);
    return CustomPaint(painter: _TerracePainter(line), child: child);
  }
}

class _TerracePainter extends CustomPainter {
  _TerracePainter(this.color);
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4;
    const gap = 22.0;
    for (var i = -4; i * gap < size.height + 120; i++) {
      final path = Path();
      final y0 = i * gap;
      path.moveTo(size.width * 0.35, y0);
      for (double x = size.width * 0.35; x <= size.width + 20; x += 20) {
        final t = (x - size.width * 0.35) / size.width;
        path.lineTo(x, y0 + math.sin(t * math.pi * 2.2 + i * 0.35) * 14 + t * 60);
      }
      canvas.drawPath(path, p);
    }
  }

  @override
  bool shouldRepaint(_TerracePainter old) => old.color != color;
}
