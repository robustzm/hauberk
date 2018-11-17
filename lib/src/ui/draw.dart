import 'package:malison/malison.dart';
import '../hues.dart';

class Draw {
  static void box(Terminal terminal, int x, int y, int width, int height,
      [Color color]) {
    _box(terminal, x, y, width, height, color, "┌", "─", "┐", "│", "└", "─",
        "┘");
  }

  static void frame(Terminal terminal, int x, int y, int width, int height,
      [Color color]) {
    _box(terminal, x, y, width, height, color, "╒", "═", "╕", "│", "└", "─",
        "┘");
  }

  static void doubleBox(Terminal terminal, int x, int y, int width, int height,
      [Color color]) {
    _box(terminal, x, y, width, height, color, "╔", "═", "╗", "║", "╚", "═",
        "╝");
  }

  static void _box(
      Terminal terminal,
      int x,
      int y,
      int width,
      int height,
      Color color,
      String topLeft,
      String top,
      String topRight,
      String vertical,
      String bottomLeft,
      String bottom,
      String bottomRight) {
    color ??= steelGray;
    var bar = vertical + " " * (width - 2) + vertical;
    for (var row = y + 1; row < y + height - 1; row++) {
      terminal.writeAt(x, row, bar, color);
    }

    var topRow = topLeft + top * (width - 2) + topRight;
    var bottomRow = bottomLeft + bottom * (width - 2) + bottomRight;
    terminal.writeAt(x, y, topRow, color);
    terminal.writeAt(x, y + height - 1, bottomRow, color);
  }

  /// Draws a progress bar to reflect [value]'s range between `0` and [max].
  /// Has a couple of special tweaks: the bar will only be empty if [value] is
  /// exactly `0`, otherwise it will at least show a sliver. Likewise, the bar
  /// will only be full if [value] is exactly [max], otherwise at least one
  /// half unit will be missing.
  static void meter(
      Terminal terminal, int x, int y, int width, int value, int max,
      [Color fore, Color back]) {
    assert(max != 0);

    fore ??= brickRed;
    back ??= maroon;

    var barWidth = (width * 2 * value / max).round();

    // Edge cases, don't show an empty or full bar unless actually at the min
    // or max.
    if (barWidth == 0 && value > 0) barWidth = 1;
    if (barWidth == width * 2 && value < max) barWidth = width * 2 - 1;

    for (var i = 0; i < width; i++) {
      int char;
      if (i < barWidth ~/ 2) {
        char = CharCode.fullBlock;
      } else if (i < (barWidth + 1) ~/ 2) {
        char = CharCode.leftHalfBlock;
      } else {
        char = CharCode.space;
      }
      terminal.drawGlyph(x + i, y, Glyph.fromCharCode(char, fore, back));
    }
  }
}
