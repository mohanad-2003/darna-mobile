import 'package:flutter/painting.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// Recolours the light-theme illustrations (blue-grey shapes and deep blue) for dark
/// surfaces, so they do not glow or lose contrast. Anything not listed keeps its colour.
class DarkSvgColors implements ColorMapper {
  const DarkSvgColors();

  // fill colours
  static const _fills = {
    0xFFF1F3F5: Color(0xFF1B2735), // big backdrop circle
    0xFFE8ECEF: Color(0xFF17222F), // ground shadow
    0xFFD6E1E8: Color(0xFF354B5D), // small accents and soft shapes
    0xFFE8EEF1: Color(0xFF283B4C),
    0xFFDDE6EB: Color(0xFF304556),
    0xFFD4DFE6: Color(0xFF33495B),
    0xFFFAF7F2: Color(0xFFDCE5EC), // dimmed paper objects
    0xFF234457: Color(0xFF4F748C), // keeps contrast with both dark surfaces and ivory details
  };

  // Ivory strokes sit on the now-light blue shapes; use dark ink for contrast.
  static const _strokes = {
    0xFFAFBFCA: Color(0xFF6D879A),
    0xFF9FB4C2: Color(0xFF7894A8),
    0xFFD6E1E8: Color(0xFF354B5D),
    0xFF234457: Color(0xFF4F748C),
    0xFFFAF7F2: Color(0xFF1B2735),
  };

  @override
  Color substitute(String? id, String elementName, String attributeName, Color color) {
    final table = attributeName == 'stroke' ? _strokes : _fills;
    return table[color.toARGB32()] ?? color;
  }
}
