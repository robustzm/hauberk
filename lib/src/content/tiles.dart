import 'package:malison/malison.dart';

import '../engine.dart';
import '../hues.dart';

// TODO: Move to hues.dart?
const _unlitBlend = const Color(0x02, 0x03, 0x25);
const _defaultBackUnlit = const Color(0x07, 0x06, 0x12);

/// Static class containing all of the [TileType]s.
class Tiles {
  static TileType floor = _open("floor", CharCode.middleDot, slate);
  static TileType rock = _solid("rock", CharCode.darkShade, gunsmoke, slate);
  static TileType wall = _solid("wall", CharCode.mediumShade, gunsmoke, slate);
  static TileType lowWall = _obstacle("low wall", CharCode.percent, gunsmoke);
  static TileType openDoor =
      _open("open door", CharCode.whiteCircle, persimmon, garnet);
  static TileType closedDoor =
      _solid("closed door", CharCode.inverseWhiteCircle, persimmon, garnet);
  // TODO: Different character that doesn't look like bridge?
  static TileType stairs =
      _exit("stairs", CharCode.identicalTo, gunsmoke, slate);
  static TileType bridge =
      _open("bridge", CharCode.identicalTo, persimmon, garnet);

  // TODO: Allow flying monster to fly over it.
  static TileType water =
      _obstacle("water", CharCode.almostEqualTo, cerulean, ultramarine);

  static TileType grass = _open("grass", CharCode.lightShade, peaGreen);
  static TileType tallGrass =
      _open("tall grass", CharCode.squareRoot, peaGreen);
  static TileType tree =
      _solid("tree", CharCode.blackUpPointingTriangle, peaGreen, sherwood);
  static TileType treeAlt1 =
      _solid("tree", CharCode.blackSpadeSuit, peaGreen, sherwood);
  static TileType treeAlt2 =
      _solid("tree", CharCode.blackClubSuit, peaGreen, sherwood);

  static final TileType tableTopLeft = _obstacle("table", "┌", persimmon);
  static final TileType tableTop = _obstacle("table", "─", persimmon);
  static final TileType tableTopRight = _obstacle("table", "┐", persimmon);
  static final TileType tableLeft = _obstacle("table", "│", persimmon);
  static final TileType tableCenter = _obstacle("table", " ", persimmon);
  static final TileType tableRight = _obstacle("table", "│", persimmon);
  static final TileType tableBottomLeft = _obstacle("table", "╘", persimmon);
  static final TileType tableBottom = _obstacle("table", "═", persimmon);
  static final TileType tableBottomRight = _obstacle("table", "╛", persimmon);

  static final TileType tableLegLeft = _obstacle("table", "╞", persimmon);
  static final TileType tableLeg = _obstacle("table", "╤", persimmon);
  static final TileType tableLegRight = _obstacle("table", "╡", persimmon);

  // Make these "monsters" that can be pushed around.
  static final TileType chair = _open("chair", "π", persimmon);

  static TileType greenJellyStain =
      _open("green jelly stain", CharCode.middleDot, lima);
  // TODO: Make this do stuff when walked through.
  static TileType spiderweb =
      _open("spiderweb", CharCode.divisionSign, slate);

  static void initialize() {
    // Link doors together.
    Tiles.openDoor.closesTo = Tiles.closedDoor;
    Tiles.closedDoor.opensTo = Tiles.openDoor;
  }
}

List<Glyph> _makeGlyphs(Object char, Color fore, [Color back]) {
  var charCode = char is int ? char : (char as String).codeUnitAt(0);
  Color unlitBack;
  if (back == null) {
    back = midnight;
    unlitBack = _defaultBackUnlit;
  } else {
    unlitBack = back.blend(_unlitBlend, 70);
  }

  var lit = new Glyph.fromCharCode(charCode, fore, back);
  var unlit =
      new Glyph.fromCharCode(charCode, fore.blend(_unlitBlend, 70), unlitBack);

  return [lit, unlit];
}

/// Creates a passable, transparent tile.
TileType _open(String name, Object char, Color fore, [Color back]) {
  return new TileType(name, _makeGlyphs(char, fore, back),
      isPassable: true, isTransparent: true, isExit: false);
}

/// Creates an impassable, opaque tile.
TileType _solid(String name, Object char, Color fore, [Color back]) {
  return new TileType(name, _makeGlyphs(char, fore, back),
      isPassable: false, isTransparent: false, isExit: false);
}

/// Creates an impassable, transparent tile.
TileType _obstacle(String name, Object char, Color fore, [Color back]) {
  return new TileType(name, _makeGlyphs(char, fore, back),
      isPassable: false, isTransparent: true, isExit: false);
}

/// Creates a passable, transparent exit tile.
TileType _exit(String name, Object char, Color fore, [Color back]) {
  return new TileType(name, _makeGlyphs(char, fore, back),
      isPassable: true, isTransparent: true, isExit: true);
}
