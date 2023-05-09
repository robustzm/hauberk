import 'dart:html' as html;

final _validator = html.NodeValidatorBuilder.common()..allowInlineStyles();

class HtmlBuilder {
  final StringBuffer _buffer = StringBuffer();

  /// Whether we need to start a new `<tr>` before the next `<td>` is written.
  bool _needsRow = false;

  void h2(String text) {
    _buffer.writeln('<h2>$text</h2>');
  }

  void table() {
    _tag('table');
    // Implicitly start a head and row in it.
    thead();
  }

  void thead() {
    _tag('thead');
    _needsRow = true;
  }

  void tbody() {
    _finishTr();
    _end('thead');
    _tag('tbody');
    _needsRow = true;
  }

  void tbodyEnd() {
    _finishTr();
    _end('tbody');
  }

  void tableEnd() {
    tbodyEnd();
    _end('table');
  }

  void td(Object contents, {bool? right, Object? width}) {
    // Numbers default to right justification.
    tdBegin(right: right ?? contents is num, width: width);
    write(contents.toString());
    tdEnd();
  }

  void tdBegin({bool right = false, Object? width}) {
    if (_needsRow) {
      _tag('tr');
      _needsRow = false;
    }

    _tag('td', cssClass: right ? 'r' : null, width: width);
  }

  void tdEnd() {
    _end('td');
  }

  void trEnd() {
    // Complete the current row.
    _finishTr();

    // Start a new one if more cells are written.
    _needsRow = true;
  }

  void write(String text) {
    _buffer.write(text);
  }

  void writeln(String text) {
    _buffer.writeln(text);
  }

  void _tag(String tag, {String? cssClass, Object? width}) {
    if (width is num) width = '${width}px';
    if (width is! String?) {
      throw ArgumentError('Width must be number or String.');
    }

    _buffer.write('<$tag');
    if (cssClass != null) _buffer.write(' class=$cssClass');
    if (width != null) _buffer.write(' style="width: $width;"');
    _buffer.write('>');
  }

  void _end(String tag) {
    _buffer.writeln('</$tag>');
  }

  void _finishTr() {
    if (!_needsRow) _end('tr');
  }

  void appendToBody() {
    html
        .querySelector('body')!
        .appendHtml(_buffer.toString(), validator: _validator);
  }

  void replaceContents(String selector) {
    html
        .querySelector(selector)!
        .setInnerHtml(_buffer.toString(), validator: _validator);
  }
}
