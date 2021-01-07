import 'dart:async';
import 'dart:html' as html;
import 'dart:math' as math;

import 'package:malison/malison.dart';
import 'package:malison/malison_web.dart';
import 'package:piecemeal/piecemeal.dart';

import 'package:hauberk/src/content.dart';
import 'package:hauberk/src/content/stage/architect.dart';
import 'package:hauberk/src/content/stage/decorator.dart';
import 'package:hauberk/src/content/stage/keep.dart';
import 'package:hauberk/src/debug.dart';
import 'package:hauberk/src/engine.dart';
import 'package:hauberk/src/hues.dart';

import 'histogram.dart';

final validator = html.NodeValidatorBuilder.common()..allowInlineStyles();

var depthSelect = html.querySelector("#depth") as html.SelectElement;
var canvas = html.querySelector("canvas#tiles") as html.CanvasElement;
var stateCanvas = html.querySelector("canvas#states") as html.CanvasElement;

var content = createContent();
var save = content.createHero("hero");
Game _game;
RenderableTerminal terminal;
Vec hoverPos;

final Map<Architecture, int> hues = {};

int get depth {
  return int.parse(depthSelect.value);
}

void main() {
  for (var i = 1; i <= Option.maxDepth; i++) {
    depthSelect.append(html.OptionElement(
        data: i.toString(), value: i.toString(), selected: i == 1));
  }

  depthSelect.onChange.listen((event) {
    generate();
  });

  canvas.onClick.listen((_) {
    generate();
  });

  stateCanvas.onClick.listen((_) {
    generate();
  });

  stateCanvas.onMouseMove.listen((event) {
    hover(Vec(event.offset.x ~/ 8, event.offset.y ~/ 8));
  });

  generate();
}

void hover(Vec pos) {
  if (pos == hoverPos) return;
  hoverPos = pos;

  var buffer = StringBuffer();
//  var dungeon = Dungeon.last;
  var stage = _game.stage;
  if (stage.bounds.contains(pos)) {
    buffer.write("<h2>Hover $pos</h2>");

    var actor = stage.actorAt(pos);
    if (actor != null) {
      buffer.writeln("<p>$actor</p>");
    }

    for (var item in stage.itemsAt(pos)) {
      buffer.writeln("<p>$item</p>");
    }

    buffer.write("<p>${stage[pos].type.name}</p>");

//    var place = dungeon.placeAt(pos);
//    if (place != null) {
//      var themes = place.themes.keys.toList();
//      themes.sort((a, b) => place.themes[b].compareTo(place.themes[a]));
//
//      if (themes.isNotEmpty) {
//        buffer.writeln("<h3>${themes.first} ${place.cells.first}</h3>");
//      } else {
//        buffer.writeln("<h3>(no theme) ${place.cells.first}</h3>");
//      }
//      buffer.writeln("<ul>");
//
//      var total = place.totalStrength.toStringAsFixed(2);
//      for (var theme in themes) {
//        var strength = place.themes[theme];
//        var percent = 100 * strength ~/ place.totalStrength;
//        buffer.writeln("<li>${percent.toString().padLeft(3)}% $theme "
//            "(${strength.toStringAsFixed(2)}/$total)</li>");
//      }
//      buffer.writeln("</ul>");
//    }
  }

  html
      .querySelector('div[id=hover]')
      .setInnerHtml(buffer.toString(), validator: validator);
}

Future generate() async {
  hues.clear();
  Keep.debugJunctions = null;
  Debug.densityMap = null;

  _game = Game(content, save, depth);
  var thisGame = _game;
  var stage = _game.stage;

  terminal = RetroTerminal(stage.width, stage.height, "../font_8.png",
      canvas: canvas, charWidth: 8, charHeight: 8, scale: 1);
  canvas.width = stage.width * 8;
  canvas.height = stage.height * 8;

  stateCanvas.width = stage.width * 8;
  stateCanvas.height = stage.height * 8;

  var start = DateTime.now();
  for (var _ in _game.generate()) {
//    print(event);
    render();

    var elapsed = DateTime.now().difference(start);
    if (elapsed.inMilliseconds > 60) {
      await html.window.animationFrame;
      start = DateTime.now();
    }

    // Bail if another generate is called.
    if (_game != thisGame) return;
  }

  _game.stage.refreshView();
  render(showInfo: false);

  var monsters = Histogram<Breed>();
  for (var actor in stage.actors) {
    if (actor is Monster) {
      var breed = actor.breed;
      monsters.add(breed);
    }
  }

  var tableContents = StringBuffer();
  tableContents.write('''
    <thead>
    <tr>
      <td>Count</td>
      <td colspan="2">Breed</td>
      <td>Depth</td>
      <td>Exp.</td>
      <!--<td>Drops</td>-->
    </tr>
    </thead>
    <tbody>
    ''');

  for (var breed in monsters.descending()) {
    var glyph = breed.appearance as Glyph;
    tableContents.write('''
      <tr>
        <td>${monsters.count(breed)}</td>
        <td>
          <pre><span style="color: ${glyph.fore.cssColor}">${String.fromCharCodes([
      glyph.char
    ])}</span></pre>
        </td>
        <td>${breed.name}</td>
        <td>${breed.depth}</td>
        <td class="r">${breed.experience}</td>
        <td>
      ''');

    var attacks = breed.attacks.map((attack) =>
        '${Log.conjugate(attack.verb, breed.pronoun)} (${attack.damage})');
    tableContents.write(attacks.join(', '));

    tableContents.write('</td><td>');
    tableContents.write(breed.flags);
    tableContents.write('</td></tr>');
  }
  tableContents.write('</tbody>');

  html
      .querySelector('table[id=monsters]')
      .setInnerHtml(tableContents.toString(), validator: validator);

  tableContents.clear();
  tableContents.write('''
    <thead>
    <tr>
      <td colspan="2">Item</td>
      <td>Depth</td>
      <td>Tags</td>
      <td>Equip.</td>
      <td>Attack</td>
      <td>Armor</td>
    </tr>
    </thead>
    <tbody>
    ''');

  var items = Histogram<String>();
  for (var item in stage.allItems) {
    items.add(item.toString());
  }

  tableContents.clear();
  tableContents.write('''
    <thead>
    <tr>
      <td>Count</td>
      <td width="300px">Item</td>
    </tr>
    </thead>
    <tbody>
    ''');

  for (var item in items.descending()) {
    tableContents.write('''
    <tr>
      <td>${items.count(item)}</td>
      <td>$item</td>
    </tr>
    ''');
  }
  html
      .querySelector('table[id=items]')
      .setInnerHtml(tableContents.toString(), validator: validator);
}

void render({bool showInfo = true}) {
  var stage = _game.stage;

  for (var y = 0; y < stage.height; y++) {
    for (var x = 0; x < stage.width; x++) {
      var pos = Vec(x, y);
      var tile = stage[pos];

      Glyph glyph;
      if (tile.type.appearance is Glyph) {
        glyph = tile.type.appearance as Glyph;
      } else {
        var glyphs = tile.type.appearance as List<Glyph>;
        // Calculate a "random" but consistent phase for each position.
        var phase = hashPoint(x, y);
        glyph = glyphs[phase % glyphs.length];
      }

      var light = ((1.0 - tile.illumination / 128) * 0.5).clamp(0.0, 1.0);
      glyph = Glyph.fromCharCode(
          glyph.char,
          glyph.fore.blend(Color.black, light),
          glyph.back.blend(Color.black, light));

      var items = stage.itemsAt(pos);
      if (items.isNotEmpty) {
        glyph = items.first.appearance as Glyph;
      }

      var actor = stage.actorAt(pos);
      if (actor != null) {
        if (actor.appearance is String) {
          glyph = Glyph.fromCharCode(CharCode.at, ash);
        } else {
          glyph = actor.appearance as Glyph;
        }
      }

      terminal.drawGlyph(x, y, glyph);
    }
  }

  terminal.render();

  var context = stateCanvas.context2D;
  context.clearRect(0, 0, stateCanvas.width, stateCanvas.height);

  if (!showInfo) return;

  if (Architect.debugOwners != null) {
    for (var pos in Architect.debugOwners.bounds) {
      var architecture = Architect.debugOwners[pos];
      if (architecture == null) continue;

      var hue = hues.putIfAbsent(architecture, () => hues.length * 49);
      context.fillStyle = 'hsla($hue, 100%, 50%, 0.1)';
      context.fillRect(pos.x * 8, pos.y * 8, 8, 8);
    }
  }

  if (Debug.densityMap != null) {
    var densityMap = Debug.densityMap as DensityMap;

    var max = 0;
    for (var pos in _game.stage.bounds) {
      max = math.max(max, densityMap[pos]);
    }

    if (max > 0) {
      for (var pos in _game.stage.bounds) {
        var density = densityMap[pos] / max;
        if (density == 0) continue;

        context.fillStyle = 'rgba(255,255,0,$density)';
        context.fillRect(pos.x * 8, pos.y * 8, 8, 8);
      }
    }
  }

  context.fillStyle = 'hsla(0, 100%, 100%, 0.4)';
  if (Keep.debugJunctions != null) {
    for (var pos in _game.stage.bounds) {
      var junction = Keep.debugJunctions[pos];
      if (junction == null) continue;

      switch (junction.direction) {
        case Direction.n:
          context.fillRect(pos.x * 8 + 3, pos.y * 8, 2, 4);
          break;
        case Direction.s:
          context.fillRect(pos.x * 8 + 3, pos.y * 8 + 4, 2, 4);
          break;
        case Direction.e:
          context.fillRect(pos.x * 8 + 4, pos.y * 8 + 3, 4, 2);
          break;
        case Direction.w:
          context.fillRect(pos.x * 8, pos.y * 8 + 3, 4, 2);
          break;
      }
    }
  }
}
