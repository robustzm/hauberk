
interface Terminal {
  int get width();
  int get height();

  void write(String text, [Color color]);
  void writeAt(int x, int y, String text, [Color color]);
  Terminal rect(int x, int y, int width, int height);
}

class DomTerminal implements Terminal {
  final Element element;
  final Array2D<Glyph> glyphs;

  DomTerminal(int width, int height, this.element)
  : glyphs = new Array2D<Glyph>(width, height,
      () => new Glyph(' ', Color.WHITE, Color.BLACK));

  int get width() => glyphs.width;
  int get height() => glyphs.height;

  render() {
    final buffer = new StringBuffer();

    var fore = null;
    var back = null;
    for (int y = 0; y < height; y++) {
      for (int x = 0; x < width; x++) {
        final glyph = glyphs.get(x, y);

        // Switch colors.
        if (glyph.fore != fore || glyph.back != back) {
          if (glyph.fore != null) buffer.add('</span>');
          fore = glyph.fore;
          back = glyph.back;
          buffer.add('<span class="${glyph.fore.cssClass} b${glyph.back.cssClass}">');
        }

        buffer.add(glyph.char);
      }
      buffer.add('\n');
    }

    element.innerHTML = buffer.toString();
  }

  void write(String text, [Color fore, Color back]) {
    for (int x = 0; x < text.length; x++) {
      if (x >= width) break;
      writeAt(x, 0, text[x], fore, back);
    }
  }

  void writeAt(int x, int y, String text, [Color fore, Color back]) {
    if (fore == null) fore = Color.WHITE;
    if (back == null) back = Color.BLACK;

    // TODO(bob): Bounds check.
    for (int i = 0; i < text.length; i++) {
      if (x + i >= width) break;
      glyphs.set(x, y, new Glyph(text[i], fore, back));
    }
  }

  Terminal rect(int x, int y, int width, int height) {
    // TODO(bob): Bounds check.
    return new PortTerminal(x, y, width, height, this);
  }
}

class PortTerminal implements Terminal {
  final int width;
  final int height;

  final int _x;
  final int _y;
  final DomTerminal _dom;

  PortTerminal(this._x, this._y, this.width, this.height, this._dom);

  void write(String text, [Color fore, Color back]) {
    _dom.writeAt(_x, _y, text[i], fore, back);
  }

  void writeAt(int x, int y, String text, [Color fore, Color back]) {
    // TODO(bob): Bounds check and crop.
    _dom.writeAt(_x + x, _y + y, text, fore, back);
  }

  Terminal rect(int x, int y, int width, int height) {
    // TODO(bob): Bounds check.
    return new PortTerminal(_x + x, _y + y, width, height, _dom);
  }
}

class Color {
  static final WHITE       = const Color('w');
  static final BLACK       = const Color('k');
  static final GRAY        = const Color('e');
  static final DARK_GRAY   = const Color('de');
  static final RED         = const Color('r');
  static final ORANGE      = const Color('o');
  static final YELLOW      = const Color('y');
  static final GREEN       = const Color('g');
  static final AQUA        = const Color('a');
  static final BLUE        = const Color('b');
  static final PURPLE      = const Color('p');
  static final DARK_RED    = const Color('dr');
  static final DARK_ORANGE = const Color('do');
  static final DARK_YELLOW = const Color('dy');
  static final DARK_GREEN  = const Color('dg');
  static final DARK_AQUA   = const Color('da');
  static final DARK_BLUE   = const Color('db');
  static final DARK_PURPLE = const Color('dp');

  final String cssClass;

  const Color(this.cssClass);
}

class Glyph {
  final String char;
  final Color  fore;
  final Color  back;

  const Glyph(this.char, this.fore, this.back);
}
