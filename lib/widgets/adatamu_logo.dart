import 'package:flutter/material.dart';

class AdaTamuLogo extends StatelessWidget {
  final double scale;

  const AdaTamuLogo({
    super.key,
    this.scale = 1.0,
  });

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      'lib/assets/adatamu_logo.png',
      width: 143 * scale,
      fit: BoxFit.contain,
    );
  }
}
