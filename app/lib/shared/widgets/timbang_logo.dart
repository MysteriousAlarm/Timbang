import 'package:flutter/material.dart';

/// TIMBANG wordmark: a scale icon and the name. Shared across both themes.
class TimbangLogo extends StatelessWidget {
  const TimbangLogo({super.key, this.color, this.size = 28});

  final Color? color;
  final double size;

  @override
  Widget build(BuildContext context) {
    final fg = color ?? Theme.of(context).colorScheme.primary;
    return Semantics(
      label: 'TIMBANG',
      excludeSemantics: true,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.balance, color: fg, size: size),
          SizedBox(width: size * 0.3),
          Text(
            'TIMBANG',
            style: TextStyle(
              color: fg,
              fontSize: size * 0.85,
              fontWeight: FontWeight.w900,
              letterSpacing: 2,
            ),
          ),
        ],
      ),
    );
  }
}
