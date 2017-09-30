import 'dart:collection';
import 'dart:math' as math;

import 'package:piecemeal/piecemeal.dart';

import '../../engine.dart';
import '../tiles.dart';
import 'blob.dart';
import 'dungeon.dart';

class Junction {
  /// Points from the first room towards where the new room should be attached.
  ///
  /// A room must have an opposing junction in order to match.
  final Direction direction;

  /// The location of the junction.
  ///
  /// For a placed room, this is in absolute coordinates. For a room yet to be
  /// placed, it's relative to the room's tile array.
  final Vec position;

  Junction(this.direction, this.position);
}

class RoomBiome extends Biome {
  final Dungeon _dungeon;
  final List<Junction> _junctions = [];

  RoomBiome(this._dungeon);

  Iterable<String> generate(Dungeon dungeon) sync* {
    // TODO: Hack temp.
    Dungeon.debugJunctions = _junctions;

    yield "Add starting room";
    // TODO: Sometimes start at a natural feature?
    _createStartingRoom();

    yield "Adding rooms";

    // Keep growing as long as we have attachment points.
    var roomNumber = 1;
    while (_junctions.isNotEmpty) {
      var junction = rng.take(_junctions);

      if (_tryCreateCycle(junction)) {
        yield "Created cycle";
        continue;
      }

      // TODO: If the junction opens up into another room, see how much it
      // shortens the path and consider placing it to add a cycle to the level.

      // TODO: Tune this.
      for (var i = 0; i < 40; i++) {
        // Try to place a hallway.
        // TODO: Turns and branches in hallways.
        var hallLength = rng.range(3, 8);
        if (_canPlaceHallway(
            junction.position, junction.direction, hallLength)) {
          var endJunction = new Junction(junction.direction,
              junction.position + junction.direction * hallLength);
          if (_tryPlaceRoom(endJunction)) {
            _placeHallway(junction.position, junction.direction, hallLength);
            yield "Placed room ${roomNumber++}";
            break;
          }
        } else if (_tryPlaceRoom(junction)) {
          yield "Placed room ${roomNumber++}";
          break;
        }
      }
    }
  }

  void _createStartingRoom() {
    var startRoom = Room.create(_dungeon.depth);

    int x, y;
    do {
      x = rng.inclusive(0, _dungeon.width - startRoom.tiles.width);
      y = rng.inclusive(0, _dungeon.height - startRoom.tiles.height);

      // TODO: After a certain number of tries, should try a different room.
    } while (!_canPlaceRoom(startRoom, x, y));

    _placeRoom(startRoom, x, y);

    // Place the hero on an open tile in the starting room.
    var openTiles = <Vec>[];
    for (var pos in startRoom.tiles.bounds) {
      if (startRoom.tiles[pos].isPassable) openTiles.add(pos.offset(x, y));
    }
    _dungeon.placeHero(rng.item(openTiles));
  }

  /// Checks if the junction is already next to an open area.
  ///
  /// If so, and the path around the junction is long enough, creates a doorway
  /// to add a cycle to the dungeon.
  bool _tryCreateCycle(Junction junction) {
    if (rng.range(100) < 20) return false;

    if (!_dungeon
        .getTileAt(junction.position + junction.direction)
        .isTraversable) {
      return false;
    }

    // The junction is next to an already open area. Consider adding a cycle
    // to the dungeon here if it cuts down on the path length significantly.
    var from = junction.position - junction.direction;
    var to = junction.position + junction.direction;

    // TODO: For some reason AStar needs to be given a longer max path than
    // we are looking for or it will very rarely find paths at the maximum
    // length. Figure out why.
    var path = AStar.findPath(_dungeon.stage, from, to,
        maxLength: 30, canOpenDoors: true);
    if (path.length != 0 && path.length < 20) return false;

    _placeDoor(junction.position);
    return true;
  }

  bool _tryPlaceRoom(Junction junction) {
    // TODO: Choosing random room types looks kind of blah. It's weird to
    // have blob rooms randomly scattered amongst other ones. Instead, it
    // would be better to have "regions" in the dungeon that preferentially
    // lean towards some room types.
    //
    // Alternatively (or do both), have the room type chosen based on the
    // preceding rooms that lead to this junction so that you don't have
    // weird things like a closet leading to a great hall.
    var room = Room.create(_dungeon.depth, junction);

    var roomJunctions = room.junctions
        .where((roomJunction) =>
            roomJunction.direction == junction.direction.rotate180)
        .toList();
    roomJunctions.shuffle();

    for (var roomJunction in roomJunctions) {
      // Calculate the room position by lining up the junctions.
      var roomPos = junction.position - roomJunction.position;

      if (!_canPlaceRoom(room, roomPos.x, roomPos.y)) continue;

      _placeRoom(room, roomPos.x, roomPos.y);
      _placeDoor(junction.position);
      return true;
    }

    return false;
  }

  bool _canPlaceHallway(Vec start, Direction dir, int length) {
    var pos = start;
    for (var i = 0; i < length; i++) {
      pos += dir;
      if (!_dungeon.safeBounds.contains(pos)) return false;
      if (!_dungeon.isRockAt(pos)) return false;
      if (!_dungeon.isRockAt(pos + dir.rotateLeft90)) return false;
      if (!_dungeon.isRockAt(pos + dir.rotateRight90)) return false;
    }

    return true;
  }

  void _placeHallway(Vec start, Direction dir, int length) {
    var pos = start;
    for (var i = 0; i <= length; i++) {
      _dungeon.setTile(pos.x, pos.y, Tiles.floor);

      var left = pos + dir.rotateLeft90;
      _dungeon.setTile(left.x, left.y, Tiles.wall);

      var right = pos + dir.rotateRight90;
      _dungeon.setTile(right.x, right.y, Tiles.wall);
      pos += dir;
    }

    _placeDoor(start);
    _placeDoor(start + dir * length);
  }

  bool _canPlaceRoom(Room room, int x, int y) {
    if (!_dungeon.bounds.containsRect(room.tiles.bounds.offset(x, y))) {
      return false;
    }

    var allowed = 0;
    var nature = 0;

    for (var pos in room.tiles.bounds) {
      // If the room doesn't care about the tile, it's fine.
      if (room.tiles[pos] == null) continue;

      // Otherwise, it must still be solid on the stage.
      var tile = _dungeon.getTile(pos.x + x, pos.y + y);

      if (tile == Tiles.rock) {
        allowed++;
      } else if (tile == Tiles.water || tile == Tiles.grass) {
        nature++;
      } else if (tile == room.tiles[pos]) {
        // Allow it if it wouldn't change the type. This lets room walls
        // overlap.
      } else {
        return false;
      }
    }

    // Allow overlapping natural features somewhat, but not too much.
    // TODO: Do we want to only allow certain room types to open into natural
    // areas?
    return allowed > nature * 2;
  }

  void _placeRoom(Room room, int x, int y) {
    List<Vec> nature = [];

    for (var pos in room.tiles.bounds) {
      var tile = room.tiles[pos];
      if (tile == null) continue;

      // Don't erase existing natural features.
      var existing = _dungeon.getTileAt(pos.offset(x, y));
      if (existing != Tiles.rock) {
        if (tile.isTraversable) nature.add(pos.offset(x, y));
        continue;
      }

      _dungeon.setTile(pos.x + x, pos.y + y, tile);
    }

    // Add its junctions unless they are already blocked.
    var roomPos = new Vec(x, y);

    for (var junction in room.junctions) {
      _tryAddJunction(roomPos + junction.position, junction.direction);
    }

    // If the room opens up into a natural feature, that feature is reachable
    // now.
    if (nature != null) _reachNature(nature);
  }

  void _placeDoor(Vec pos) {
    // TODO: Hidden passageways.
    var tile = Tiles.closedDoor;
    if (rng.oneIn(5)) {
      tile = Tiles.openDoor;
    } else if (rng.oneIn(4)) {
      tile = Tiles.floor;
    }

    _dungeon.setTile(pos.x, pos.y, tile);

    // Since halls are placed after the room they connect to, they may overlap
    // a room junction. Remove that since it's pointless.
    _junctions.removeWhere((junction) => junction.position == pos);
  }

  void _tryAddJunction(Vec junctionPos, Direction junctionDir) {
    isBlocked(Direction direction) {
      var pos = junctionPos + direction;
      if (!_dungeon.safeBounds.contains(pos)) return true;

      var tile = _dungeon.getTileAt(pos);
      // TODO: Is there a more generic way we can handle this?
      return tile != Tiles.wall && tile != Tiles.rock;
    }

    if (isBlocked(Direction.none)) return;
    if (isBlocked(junctionDir)) return;
    if (isBlocked(junctionDir.rotateLeft45)) return;
    if (isBlocked(junctionDir.rotateRight45)) return;
    if (isBlocked(junctionDir.rotateLeft90)) return;
    if (isBlocked(junctionDir.rotateRight90)) return;

    _junctions.add(new Junction(junctionDir, junctionPos));
  }

  void _reachNature(List<Vec> tiles) {
    var queue = new Queue.from(
        tiles.where((pos) => _dungeon.getTileAt(pos).isTraversable));
    var visited = new Set<Vec>();

    // TODO: Simplify.
    for (var pos in queue) {
      visited.add(pos);
    }

    while (queue.isNotEmpty) {
      var pos = queue.removeFirst();

      for (var dir in Direction.all) {
        var neighbor = pos + dir;
        if (!_dungeon.bounds.contains(neighbor)) continue;

        if (visited.contains(neighbor)) continue;

        var tile = _dungeon.getTileAt(neighbor);

        // Don't expand outside of the natural area.
        if (tile != Tiles.grass && tile != Tiles.bridge) {
          // If we're facing a straight direction, try to place a junction
          // there to allow building out from the area.
          if (Direction.cardinal.contains(dir) && rng.range(100) < 30) {
            _tryAddJunction(neighbor, dir);
          }
          continue;
        }

        // Don't go into impassable natural areas like water.
        if (!_dungeon.getTileAt(neighbor).isTraversable) continue;

        queue.add(neighbor);
        visited.add(neighbor);
      }
    }
  }
}

class Room {
  static ResourceSet<RoomType> _allTypes = new ResourceSet();

  // TODO: Hacky. ResourceSet assumes resources are named and have unique names.
  // Relax that constraint?
  static int _nextNameId = 0;

  static Room create(int depth, [Junction junction]) {
    if (_allTypes.isEmpty) _initializeRoomTypes();

    // TODO: Take depth into account somehow.
    var type = _allTypes.tryChoose(1, "room");
    return type.create();
  }

  static void _add(RoomType type, int rarity) {
    _allTypes.add("room_${_nextNameId++}", type, 1, rarity, "room");
  }

  static void _initializeRoomTypes() {
    _allTypes.defineTags("room");

    // Rectangular rooms of various sizes.
    for (var width = 3; width <= 13; width++) {
      for (var height = 3; height <= 13; height++) {
        // Don't make them too big.
        if (width * height > 120) continue;

        // Don't make them too oblong.
        if ((width - height).abs() > math.min(width, height)) continue;

        // Prefer larger rooms. They tend to fail to get placed more often,
        // so making them more common counter-acts that.
        var rarity = 100 ~/ math.sqrt(width * height);
        _add(new RectangleRoom(width, height), rarity);
      }
    }

    // Blob-shaped rooms.
    // TODO: Get blobs working with junctions.
//    _add(new BlobRoom(), 1);

    // TODO: Other room shapes: L, T, cross, etc.
  }

  final Array2D<TileType> tiles;
  final List<Junction> junctions;

  Room(this.tiles, this.junctions);
}

abstract class RoomType {
  Room create();
}

class RectangleRoom extends RoomType {
  final int width;
  final int height;

  RectangleRoom(this.width, this.height);

  Room create() {
    // TODO: Cache this with the type?
    var tiles = new Array2D<TileType>(width + 2, height + 2, Tiles.floor);

    for (var y = 0; y < tiles.height; y++) {
      tiles.set(0, y, Tiles.wall);
      tiles.set(tiles.width - 1, y, Tiles.wall);
    }

    for (var x = 0; x < tiles.width; x++) {
      tiles.set(x, 0, Tiles.wall);
      tiles.set(x, tiles.height - 1, Tiles.wall);
    }

    // TODO: Consider placing the junctions symmetrically sometimes.
    var junctions = <Junction>[];
    _placeJunctions(width, (i) {
      junctions.add(new Junction(Direction.n, new Vec(i + 1, 0)));
    });

    _placeJunctions(width, (i) {
      junctions.add(new Junction(Direction.s, new Vec(i + 1, height + 1)));
    });

    _placeJunctions(height, (i) {
      junctions.add(new Junction(Direction.w, new Vec(0, i + 1)));
    });

    _placeJunctions(height, (i) {
      junctions.add(new Junction(Direction.e, new Vec(width + 1, i + 1)));
    });

    return new Room(tiles, junctions);
  }

  /// Walks along [length], invoking [callback] at values where a junction
  /// should be placed.
  ///
  /// Ensures two junctions are not placed next to each other.
  void _placeJunctions(int length, void Function(int) callback) {
    var start = rng.oneIn(2) ? 0 : 1;
    for (var i = start; i < length; i++) {
      // TODO: Make chances tunable.
      if (rng.range(100) < 40) {
        callback(i);

        // Don't allow two junctions right next to each other.
        i++;
      }
    }
  }
}

class BlobRoom extends RoomType {
  Room create() {
    // TODO: Other size blobs.
    var blob = Blob.make16();
    // Note: Assumes the blob never has open cells at the very edge.
    var tiles = new Array2D<TileType>(blob.width, blob.height);
    for (var pos in tiles.bounds.inflate(-1)) {
      if (blob[pos]) {
        tiles[pos] = Tiles.floor;

        // If this cell is at the edge of the blob, ensure there is a ring of
        // wall around it.
        for (var dir in Direction.all) {
          var neighbor = pos + dir;
          if (tiles[neighbor] != Tiles.floor) {
            tiles[neighbor] = Tiles.wall;
          }
        }
      }
    }

    // TODO: Place junctions.
    return new Room(tiles, []);
  }
}
