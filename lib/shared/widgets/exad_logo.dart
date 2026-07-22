import 'package:flutter/material.dart';

class ExadLogo extends StatelessWidget {
  const ExadLogo({super.key, this.height = 62, this.inverse = false});

  final double height;
  final bool inverse;

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      'assets/images/logo-exad.png',
      height: height,
      fit: BoxFit.contain,
      color: inverse ? Colors.white : null,
      colorBlendMode: inverse ? BlendMode.srcIn : null,
      errorBuilder: (_, _, _) => Text(
        'EXAD',
        style: TextStyle(
          color: inverse ? Colors.white : Theme.of(context).colorScheme.primary,
          fontSize: height * .45,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}
