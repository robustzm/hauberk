library hauberk.content.tiles;

import 'package:malison/malison.dart';

import '../engine.dart';
import 'utils.dart';

/// Static class containing all of the [TileType]s.
class Tiles {
  static TileType floor;
  static TileType wall;
  static TileType lowWall;
  static TileType table;
  static TileType openDoor;
  static TileType closedDoor;
  static TileType stairs;

  static TileType grass;
  static TileType tree;
  static TileType treeAlt1;
  static TileType treeAlt2;

  static void initialize() {
    // Define the tile types.
    Tiles.floor = new TileType("floor", true, true,
        [gray('.'), darkGray('.')]);

    Tiles.wall = new TileType("wall", false, false,
        [lightGray('#', Color.DARK_GRAY), darkGray('#')]);

    Tiles.table = new TileType("table", false, true,
        [brown(CharCode.PI), darkBrown(CharCode.PI)]);

    Tiles.lowWall = new TileType("low wall", false, true,
        [gray('%', Color.DARK_GRAY), darkGray('%')]);

    Tiles.openDoor = new TileType("open door", true, true,
        [brown("'"), darkBrown("'")]);
    Tiles.closedDoor = new TileType("closed door", false, false,
        [brown('+'), darkBrown('+')]);
    Tiles.openDoor.closesTo = Tiles.closedDoor;
    Tiles.closedDoor.opensTo = Tiles.openDoor;

    Tiles.stairs = new TileType("stairs", true, true,
        [lightGray(CharCode.TRIPLE_BAR), darkGray(CharCode.TRIPLE_BAR)]);

    Tiles.grass = new TileType("grass", true, true,
        [lightGreen('.'), green('.')]);

    Tiles.tree = new TileType("tree", false, false, [
      green(CharCode.BLACK_UP_POINTING_TRIANGLE, Color.DARK_GREEN),
      darkGreen(CharCode.BLACK_UP_POINTING_TRIANGLE)
    ]);

    Tiles.treeAlt1 = new TileType("tree", false, false, [
      green(CharCode.BLACK_SPADE_SUIT, Color.DARK_GREEN),
      darkGreen(CharCode.BLACK_SPADE_SUIT)
    ]);

    Tiles.treeAlt2 = new TileType("tree", false, false, [
      green(CharCode.BLACK_CLUB_SUIT, Color.DARK_GREEN),
      darkGreen(CharCode.BLACK_CLUB_SUIT)
    ]);
  }
}
