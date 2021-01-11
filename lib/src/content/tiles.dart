import 'package:malison/malison.dart';
import 'package:piecemeal/piecemeal.dart';

import '../engine.dart';
import '../hues.dart';
import 'action/tile.dart';

// Note: Not using lambdas for these because that prevents [Tiles.openDoor] and
// [Tiles.closedDoor] from having their types inferred.
Action _closeDoor(Vec pos) => CloseDoorAction(pos, Tiles.closedDoor);

Action _openDoor(Vec pos) => OpenDoorAction(pos, Tiles.openDoor);

Action _closeSquareDoor(Vec pos) =>
    CloseDoorAction(pos, Tiles.closedSquareDoor);

Action _openSquareDoor(Vec pos) => OpenDoorAction(pos, Tiles.openSquareDoor);

Action _closeBarredDoor(Vec pos) =>
    CloseDoorAction(pos, Tiles.closedBarredDoor);

Action _openBarredDoor(Vec pos) => OpenDoorAction(pos, Tiles.openBarredDoor);

/// Static class containing all of the [TileType]s.
class Tiles {
  // Temporary tile types used during stage generation.

  /// An unformed tile that can be turned into aquatic, passage, or solid.
  static final unformed = tile("unformed", "?", coolGray).open();

  /// An unformed tile that can be turned into water of some kind when "filled"
  /// or a bridge when used as a passage.
  static final unformedWet = tile("unformed wet", "≈", coolGray).open();

  /// An open floor tile generated by an architecture.
  static final open = tile("open", "·", lightCoolGray).open();

  /// A solid tile that has been filled in the passage generator.
  static final solid = tile("solid", "#", lightCoolGray).solid();

  /// An open tile that the passage generator knows must remain open.
  static final passage = tile("passage", "-", lightCoolGray).open();

  /// The end of a passage.
  static final doorway = tile("doorway", "○", lightCoolGray).open();

  /// An untraversable wet tile that has been filled in the passage generator.
  static final solidWet = tile("solid wet", "≈", lightBlue).solid();

  /// A traversable wet tile that the passage generator knows must remain open.
  static final passageWet = tile("wet passage", "-", lightBlue).open();

  // Real tiles.

  // Walls.
  static final flagstoneWall =
      tile("flagstone wall", "▒", lightWarmGray, warmGray).solid();

  static final graniteWall =
      tile("granite wall", "▒", coolGray, darkCoolGray).solid();

  static final granite1 = tile("granite", "▓", coolGray, darkCoolGray)
      .blend(0.0, darkCoolGray, darkerCoolGray)
      .solid();
  static final granite2 = tile("granite", "▓", coolGray, darkCoolGray)
      .blend(0.2, darkCoolGray, darkerCoolGray)
      .solid();
  static final granite3 = tile("granite", "▓", coolGray, darkCoolGray)
      .blend(0.4, darkCoolGray, darkerCoolGray)
      .solid();

  // Floors.
  static final flagstoneFloor = tile("flagstone floor", "·", warmGray).open();

  static final graniteFloor = tile("granite floor", "·", coolGray).open();

  // Doors.
  static final openDoor =
      tile("open door", "○", tan, darkBrown).onClose(_closeDoor).open();
  static final closedDoor =
      tile("closed door", "◙", tan, darkBrown).onOpen(_openDoor).door();

  static final openSquareDoor = tile("open square door", "♂", tan, darkBrown)
      .onClose(_closeSquareDoor)
      .open();

  static final closedSquareDoor =
      tile("closed square door", "♀", tan, darkBrown)
          .onOpen(_openSquareDoor)
          .door();

  static final openBarredDoor =
      tile("open barred door", "♂", lightWarmGray, coolGray)
          .onClose(_closeBarredDoor)
          .open();

  // TODO: Should be able to see through but not fly through.
  static final closedBarredDoor =
      tile("closed barred door", "♪", lightWarmGray, coolGray)
          .onOpen(_openBarredDoor)
          .transparentDoor();

  // Unsorted.

  // TODO: Organize these.
  static final burntFloor = tile("burnt floor", "φ", darkCoolGray).open();
  static final burntFloor2 = tile("burnt floor", "ε", darkCoolGray).open();
  static final lowWall = tile("low wall", "%", lightWarmGray).obstacle();

  // TODO: Different character that doesn't look like bridge?
  static final stairs =
      tile("stairs", "≡", lightWarmGray, coolGray).to(TilePortals.exit).open();
  static final bridge = tile("bridge", "≡", tan, darkBrown).open();

  // TODO: Stop glowing when stepped on?
  static final glowingMoss = Tiles.tile("moss", "░", aqua).emanate(128).open();

  static final water = tile("water", "≈", blue, darkBlue)
      .animate(10, 0.5, darkBlue, darkerCoolGray)
      .water();
  static final steppingStone =
      tile("stepping stone", "•", lightCoolGray, darkBlue).open();

  static final dirt = tile("dirt", "·", brown).open();
  static final dirt2 = tile("dirt2", "φ", brown).open();
  static final grass = tile("grass", "░", peaGreen).open();
  static final tallGrass = tile("tall grass", "√", peaGreen).open();
  static final tree = tile("tree", "▲", peaGreen, sherwood).solid();
  static final treeAlt1 = tile("tree", "♠", peaGreen, sherwood).solid();
  static final treeAlt2 = tile("tree", "♣", peaGreen, sherwood).solid();

  // Decor.

  static final openChest = tile("open chest", "⌠", tan).obstacle();
  static final closedChest = tile("closed chest", "⌡", tan)
      .onOpen((pos) => OpenChestAction(pos))
      .obstacle();
  static final closedBarrel = tile("closed barrel", "°", tan)
      .onOpen((pos) => OpenBarrelAction(pos))
      .obstacle();
  static final openBarrel = tile("open barrel", "∙", tan).obstacle();

  static final tableTopLeft = tile("table", "┌", tan).obstacle();
  static final tableTop = tile("table", "─", tan).obstacle();
  static final tableTopRight = tile("table", "┐", tan).obstacle();
  static final tableSide = tile("table", "│", tan).obstacle();
  static final tableCenter = tile("table", " ", tan).obstacle();
  static final tableBottomLeft = tile("table", "╘", tan).obstacle();
  static final tableBottom = tile("table", "═", tan).obstacle();
  static final tableBottomRight = tile("table", "╛", tan).obstacle();

  static final tableLegLeft = tile("table", "╞", tan).obstacle();
  static final tableLeg = tile("table", "╤", tan).obstacle();
  static final tableLegRight = tile("table", "╡", tan).obstacle();

  static final candle = tile("candle", "≥", sandal).emanate(128).obstacle();

  static final wallTorch =
      tile("wall torch", "≤", gold, coolGray).emanate(192).solid();

  // TODO: Different glyph.
  static final braziers = multi("brazier", "≤", tan, null, 5,
      (tile, n) => tile.emanate(192 - n * 12).obstacle());

  static final statue = tile("statue", "P", ash, coolGray).obstacle();

  // Make these "monsters" that can be pushed around.
  static final chair = tile("chair", "π", tan).open();

  // Stains.

  // TODO: Not used right now.
  static final brownJellyStain = tile("brown jelly stain", "·", tan).open();

  static final grayJellyStain =
      tile("gray jelly stain", "·", darkCoolGray).open();

  static final greenJellyStain = tile("green jelly stain", "·", lima).open();

  static final redJellyStain = tile("red jelly stain", "·", red).open();

  static final violetJellyStain =
      tile("violet jelly stain", "·", purple).open();

  static final whiteJellyStain = tile("white jelly stain", "·", ash).open();

  // TODO: Make this do stuff when walked through.
  static final spiderweb = tile("spiderweb", "÷", coolGray).open();

  // Town tiles.

  static final dungeonEntrance =
      tile("dungeon entrance", "≡", lightWarmGray, coolGray)
          .to(TilePortals.dungeon)
          .open();

  static final home =
      tile("home entrance", "○", sandal).to(TilePortals.home).open();

  static final shop1 =
      tile("shop entrance", "○", carrot).to(TilePortals.shop1).open();

  static final shop2 =
      tile("shop entrance", "○", gold).to(TilePortals.shop2).open();

  static final shop3 =
      tile("shop entrance", "○", lima).to(TilePortals.shop3).open();

  static final shop4 =
      tile("shop entrance", "○", peaGreen).to(TilePortals.shop4).open();

  static final shop5 =
      tile("shop entrance", "○", aqua).to(TilePortals.shop5).open();

  static final shop6 =
      tile("shop entrance", "○", lightAqua).to(TilePortals.shop6).open();

  static final shop7 =
      tile("shop entrance", "○", blue).to(TilePortals.shop7).open();

  static final shop8 =
      tile("shop entrance", "○", purple).to(TilePortals.shop8).open();

  static final shop9 =
      tile("shop entrance", "○", red).to(TilePortals.shop9).open();

  static _TileBuilder tile(String name, Object char, Color fore,
          [Color back]) =>
      _TileBuilder(name, char, fore, back);

  static List<TileType> multi(String name, Object char, Color fore, Color back,
      int count, TileType Function(_TileBuilder, int) generate) {
    var result = <TileType>[];
    for (var i = 0; i < count; i++) {
      var builder = tile(name, char, fore, back);
      result.add(generate(builder, i));
    }

    return result;
  }

  /// The amount of heat required for [tile] to catch fire or 0 if the tile
  /// cannot be ignited.
  static int ignition(TileType tile) => _ignition[tile] ?? 0;

  static final _ignition = {
    openDoor: 30,
    closedDoor: 30,
    bridge: 50,
    glowingMoss: 10,
    grass: 3,
    tallGrass: 3,
    tree: 40,
    treeAlt1: 40,
    treeAlt2: 40,
    tableTopLeft: 20,
    tableTop: 20,
    tableTopRight: 20,
    tableSide: 20,
    tableCenter: 20,
    tableBottomLeft: 20,
    tableBottom: 20,
    tableBottomRight: 20,
    tableLegLeft: 20,
    tableLeg: 20,
    tableLegRight: 20,
    openChest: 40,
    closedChest: 80,
    openBarrel: 15,
    closedBarrel: 40,
    candle: 1,
    chair: 10,
    spiderweb: 1
  };

  /// How long [tile] burns before going out.
  static int fuel(TileType tile) => _fuel[tile] ?? 0;

  static final _fuel = {
    openDoor: 70,
    closedDoor: 70,
    bridge: 50,
    glowingMoss: 20,
    grass: 30,
    tallGrass: 50,
    tree: 100,
    treeAlt1: 100,
    treeAlt2: 100,
    tableTopLeft: 60,
    tableTop: 60,
    tableTopRight: 60,
    tableSide: 60,
    tableCenter: 60,
    tableBottomLeft: 60,
    tableBottom: 60,
    tableBottomRight: 60,
    tableLegLeft: 60,
    tableLeg: 60,
    tableLegRight: 60,
    openChest: 70,
    closedChest: 80,
    openBarrel: 30,
    closedBarrel: 40,
    candle: 60,
    chair: 40,
    spiderweb: 20
  };

  /// What types [tile] can turn into when it finishes burning.
  static List<TileType> burnResult(TileType tile) {
    if (_burnTypes.containsKey(tile)) return _burnTypes[tile];

    return [burntFloor, burntFloor2];
  }

  static final _burnTypes = {
    bridge: [water],
    grass: [dirt, dirt2],
    tallGrass: [dirt, dirt2],
    tree: [dirt, dirt2],
    treeAlt1: [dirt, dirt2],
    treeAlt2: [dirt, dirt2],
    candle: [tableCenter],
    // TODO: This doesn't handle spiderwebs on other floors.
    spiderweb: [flagstoneFloor]
  };
}

class _TileBuilder {
  final String name;
  final List<Glyph> glyphs;

  Action Function(Vec) _onClose;
  Action Function(Vec) _onOpen;
  TilePortal _portal;
  int _emanation = 0;

  factory _TileBuilder(String name, Object char, Color fore, [Color back]) {
    back ??= darkerCoolGray;
    var charCode = char is int ? char : (char as String).codeUnitAt(0);

    return _TileBuilder._(name, Glyph.fromCharCode(charCode, fore, back));
  }

  _TileBuilder._(this.name, Glyph glyph) : glyphs = [glyph];

  _TileBuilder blend(double amount, Color fore, Color back) {
    for (var i = 0; i < glyphs.length; i++) {
      var glyph = glyphs[i];
      glyphs[i] = Glyph.fromCharCode(glyph.char, glyph.fore.blend(fore, amount),
          glyph.back.blend(back, amount));
    }

    return this;
  }

  _TileBuilder animate(int count, double maxMix, Color fore, Color back) {
    var glyph = glyphs.first;
    for (var i = 1; i < count; i++) {
      var mixedFore =
          glyph.fore.blend(fore, lerpDouble(i, 0, count, 0.0, maxMix));
      var mixedBack =
          glyph.back.blend(back, lerpDouble(i, 0, count, 0.0, maxMix));

      glyphs.add(Glyph.fromCharCode(glyph.char, mixedFore, mixedBack));
    }

    return this;
  }

  _TileBuilder emanate(int emanation) {
    _emanation = emanation;
    return this;
  }

  _TileBuilder to(TilePortal portal) {
    _portal = portal;
    return this;
  }

  _TileBuilder onClose(Action Function(Vec) onClose) {
    _onClose = onClose;
    return this;
  }

  _TileBuilder onOpen(Action Function(Vec) onOpen) {
    _onOpen = onOpen;
    return this;
  }

  TileType door() => _motility(Motility.door);

  TileType transparentDoor() => _motility(Motility.fly | Motility.door);

  TileType obstacle() => _motility(Motility.fly);

  TileType open() => _motility(Motility.flyAndWalk);

  TileType solid() => _motility(Motility.none);

  TileType water() => _motility(Motility.fly | Motility.swim);

  TileType _motility(Motility motility) {
    return TileType(name, glyphs.length == 1 ? glyphs.first : glyphs, motility,
        portal: _portal,
        emanation: _emanation,
        onClose: _onClose,
        onOpen: _onOpen);
  }
}

class TilePortals {
  /// Stairs to exit the dungeon.
  static const exit = TilePortal("exit");

  /// Stairs to enter the dungeon from the town.
  static const dungeon = TilePortal("dungeon");

  static const home = TilePortal("home");

  static const shop1 = TilePortal("shop 1");
  static const shop2 = TilePortal("shop 2");
  static const shop3 = TilePortal("shop 3");
  static const shop4 = TilePortal("shop 4");
  static const shop5 = TilePortal("shop 5");
  static const shop6 = TilePortal("shop 6");
  static const shop7 = TilePortal("shop 7");
  static const shop8 = TilePortal("shop 8");
  static const shop9 = TilePortal("shop 9");
}
