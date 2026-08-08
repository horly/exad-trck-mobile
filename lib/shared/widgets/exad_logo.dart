import 'package:flutter/material.dart';

class ExadLogo extends StatelessWidget {
  const ExadLogo({super.key, this.height = 62, this.inverse});

  final double height;
  final bool? inverse;

  @override
  Widget build(BuildContext context) {
    final useInverse =
        inverse ?? Theme.of(context).brightness == Brightness.dark;
    return Image.asset(
      'assets/images/logo-exad.png',
      height: height,
      fit: BoxFit.contain,
      color: useInverse ? Colors.white : null,
      colorBlendMode: useInverse ? BlendMode.srcIn : null,
      errorBuilder: (_, _, _) => Text(
        'EXAD',
        style: TextStyle(
          color: useInverse
              ? Colors.white
              : Theme.of(context).colorScheme.primary,
          fontSize: height * .45,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}
