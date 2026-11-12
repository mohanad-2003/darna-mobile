import 'package:flutter/material.dart';
import '../../app/theme.dart';

/// The 3D house and Darna wordmark, with text adapted to the background.
/// Pass [onLight] when the background is fixed and does not follow the theme.
class DarnaLogo extends StatelessWidget {
  const DarnaLogo({super.key, this.height = 40, this.onLight});

  final double height;

  /// true: the logo sits on a light background; false: on a dark one; null: follow the theme.
  final bool? onLight;

  @override
  Widget build(BuildContext context) {
    final light = onLight ?? Theme.of(context).brightness == Brightness.light;
    return Semantics(
      label: 'دارنا',
      image: true,
      excludeSemantics: true,
      child: SizedBox(
        height: height,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          textDirection: TextDirection.rtl,
          children: [
            Image.asset(
              'assets/branding/darna_house_mark.png',
              width: height,
              height: height,
              fit: BoxFit.contain,
              filterQuality: FilterQuality.medium,
            ),
            SizedBox(width: height * .16),
            Text(
              'دارنا',
              textScaler: TextScaler.noScaling,
              style: TextStyle(
                fontFamily: 'Tajawal',
                fontSize: height * .82,
                height: 1,
                fontWeight: FontWeight.w700,
                color: light ? brandPrimary : brandIvory,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
