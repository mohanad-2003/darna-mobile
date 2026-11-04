import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// The Darna logo (vector). Picks the teal version on light backgrounds and the ivory version
/// on dark ones. Pass [onLight] when the background is fixed and does not follow the theme.
class DarnaLogo extends StatelessWidget {
  const DarnaLogo({super.key, this.height = 40, this.onLight});

  final double height;

  /// true: the logo sits on a light background; false: on a dark one; null: follow the theme.
  final bool? onLight;

  @override
  Widget build(BuildContext context) {
    final light = onLight ?? Theme.of(context).brightness == Brightness.light;
    return SvgPicture.asset(
      light ? 'assets/branding/darna_logo_tight.svg' : 'assets/branding/darna_logo_tight_dark.svg',
      height: height,
      semanticsLabel: 'دارنا',
    );
  }
}
