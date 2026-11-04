import 'package:flutter/painting.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// Recolours the light-theme illustrations (pale mint shapes and a bright teal) for dark
/// surfaces, so they do not glow or lose contrast. Anything not listed keeps its colour.
class DarkSvgColors implements ColorMapper {
  const DarkSvgColors();

  // fill colours
  static const _fills = {
    0xFFF0F6F3: Color(0xFF1A2C29), // big backdrop circle
    0xFFEAF1EE: Color(0xFF162622), // ground shadow
    0xFFD5E8E1: Color(0xFF28433E), // small accents and soft shapes
    0xFFE2EEE7: Color(0xFF213832),
    0xFFDBEAE3: Color(0xFF24403A),
    0xFFD2E5DD: Color(0xFF27423C),
    0xFFFAF6F1: Color(0xFFD9E6E2), // "paper" objects: dimmed, still the brightest thing
    0xFF0F766E: Color(0xFF2A9D8F), // brand teal, lifted for contrast
  };

  // stroke colours (a stroke drawn in cream sits on top of teal, so it is left alone)
  static const _strokes = {
    0xFFB3D5CB: Color(0xFF3A6158),
    0xFFA7CEC0: Color(0xFF3E6A60),
    0xFFD5E8E1: Color(0xFF28433E),
    0xFF0F766E: Color(0xFF2A9D8F),
  };

  @override
  Color substitute(String? id, String elementName, String attributeName, Color color) {
    final table = attributeName == 'stroke' ? _strokes : _fills;
    return table[color.toARGB32()] ?? color;
  }
}
