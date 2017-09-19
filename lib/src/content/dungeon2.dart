import 'dart:collection';
import 'dart:math' as math;

import 'package:piecemeal/piecemeal.dart';

import '../engine.dart';
import 'blob.dart';
import 'room.dart';
import 'tiles.dart';

enum TileState {
  /// Nothing has been placed on the tile.
  unused,

  /// A natural formation is here, but the dungeon hasn't reached it yet.
  natural,

  /// The tile has been used and is reachable from the starting room.
  reached
}

class Dungeon2 {
  // TODO: Hack temp. Static so that dungeon_test can access these while it's
  // being generated.
  static Array2D<TileState> currentStates;
  static List<Junction> currentJunctions;

  final Stage stage;
  final int depth;

  final List<Junction> _junctions = [];
  final Array2D<TileState> _states;

  Rect get bounds => stage.bounds;
  Rect get safeBounds => stage.bounds.inflate(-1);

  int get width => stage.width;
  int get height => stage.height;

  Dungeon2(this.stage, this.depth)
      : _states = new Array2D(stage.width, stage.height, TileState.unused);

  Iterable<String> generate() sync* {
    currentStates = _states;
    currentJunctions = _junctions;

    for (var y = 0; y < height; y++) {
      for (var x = 0; x < width; x++) {
        // TODO: Stone?
        setTile(x, y, Tiles.wall, TileState.unused);
      }
    }

    // TODO: Change the odds based on depth.
    if (rng.oneIn(3)) {
      yield "Carving river";
      _addRiver();
    }

    // TODO: Rivers that flow into/from lakes?

    // TODO: Change the odds based on depth.
    if (rng.oneIn(5)) {
      yield "Pouring big lake";
      // TODO: 64 is pretty big. Might want to make these a little smaller, but
      // not all the way down to 32.
      _addLake(Blob.make64());
    } else if (rng.oneIn(2)) {
      yield "Pouring lake";
      _addLake(Blob.make32());
    }

    var ponds = rng.taper(0, 3);
    for (var i = 0; i < ponds; i++) {
      yield "Pouring pond $i/$ponds";
      _addLake(Blob.make16());
    }

    // TODO: Add grottoes other places than just on shores.
    // Add some old grottoes that eroded before the dungeon was built.
    yield* _addGrottoes(rng.taper(2, 3));

    yield* _addRooms();

    // Add a few grottoes that have collapsed after rooms. Unlike the above,
    // these may erode into rooms.
    // TODO: It looks weird that these don't place grass on the room floor
    // itself. Probably want to apply grass after everything is carved based on
    // humidity or something.
    yield* _addGrottoes(rng.taper(0, 3));
  }

  void setTile(int x, int y, TileType type, TileState state) {
    stage.get(x, y).type = type;
    _states.set(x, y, state);
  }

  bool isWall(int x, int y) => stage.get(x, y).type == Tiles.wall;

  /// Returns `true` if the cell at [pos] has at least one adjacent tile with
  /// type [tile].
  bool hasCardinalNeighbor(Vec pos, TileType tile) {
    for (var dir in Direction.cardinal) {
      var neighbor = pos + dir;
      if (!safeBounds.contains(neighbor)) continue;

      // TODO: Allow passing in the tile types that can be grown into.
      if (stage[neighbor].type == tile) return true;
    }

    return false;
  }

  /// Returns `true` if the cell at [pos] has at least one adjacent tile with
  /// type [tile].
  bool hasNeighbor(Vec pos, TileType tile) {
    for (var dir in Direction.all) {
      var neighbor = pos + dir;
      if (!safeBounds.contains(neighbor)) continue;

      // TODO: Allow passing in the tile types that can be grown into.
      if (stage[neighbor].type == tile) return true;
    }

    return false;
  }

  void _displace(RiverPoint start, RiverPoint end) {
    var h = start.x - end.x;
    var v = start.y - end.y;
    var length = math.sqrt(h * h + v * v);
    if (length > 1.0) {
      // TODO: Displace along the tangent line between start and end?
      var x = (start.x + end.x) / 2.0 + rng.float(length / 2.0) - length / 4.0;
      var y = (start.y + end.y) / 2.0 + rng.float(length / 2.0) - length / 4.0;
      var radius = (start.radius + end.radius) /
          2.0; //+ rng.float(length / 10.0) - length - 20.0;
      var mid = new RiverPoint(x, y, radius);
      _displace(start, mid);
      _displace(mid, end);
    } else {
      var radius = start.radius;
      var shoreRadius = radius + rng.float(1.0, 3.0);

      var x1 = (start.x - shoreRadius).floor();
      var y1 = (start.y - shoreRadius).floor();
      var x2 = (start.x + shoreRadius).ceil();
      var y2 = (start.y + shoreRadius).ceil();

      // Don't go off the edge of the level. In fact, inset one inside it so
      // that we don't carve walkable tiles up to the edge.
      // TODO: Some sort of different tile types at the edge of the level to
      // look better than the river just stopping?
      x1 = x1.clamp(1, width - 2);
      y1 = y1.clamp(1, height - 2);
      x2 = x2.clamp(1, width - 2);
      y2 = y2.clamp(1, height - 2);

      var radiusSquared = radius * radius;
      var shoreSquared = shoreRadius * shoreRadius;

      for (var y = y1; y <= y2; y++) {
        for (var x = x1; x <= x2; x++) {
          var xx = start.x - x;
          var yy = start.y - y;

          // TODO: Different types of river and shore: ice, slime, blood, lava,
          // etc.
          var lengthSquared = xx * xx + yy * yy;
          if (lengthSquared <= radiusSquared) {
            setTile(x, y, Tiles.water, TileState.natural);
          } else if (lengthSquared <= shoreSquared && isWall(x, y)) {
            setTile(x, y, Tiles.grass, TileState.natural);
          }
        }
      }
    }
  }

  void _addRiver() {
    // Midpoint displacement.
    // Consider also squig curves from: http://algorithmicbotany.org/papers/mountains.gi93.pdf.
    var start =
        new RiverPoint(rng.float(width.toDouble()), -4.0, rng.float(1.0, 3.0));
    var end = new RiverPoint(
        rng.float(width.toDouble()), height + 4.0, rng.float(1.0, 3.0));
    var mid = new RiverPoint(rng.float(width * 0.25, width * 0.75),
        rng.float(height * 0.25, height * 0.75), rng.float(1.0, 3.0));

    if (rng.oneIn(2)) {
      // Horizontal instead of vertical.
      start = new RiverPoint(start.y, start.x, start.radius);
      end = new RiverPoint(end.y, end.x, end.radius);
    }

    // TODO: Branching tributaries?

    _displace(start, mid);
    _displace(mid, end);

    // TODO: Need to add bridges.

    // TODO: Figure out how to handle the edge of the dungeon.
  }

  Iterable<String> _addGrottoes(int count) sync* {
    if (count == 0) return;

    for (var i = 0; i < 200; i++) {
      var pos = rng.vecInRect(safeBounds);
      // TODO: Handle different shore types.
      if (stage[pos].type == Tiles.grass &&
          hasCardinalNeighbor(pos, Tiles.wall)) {
        yield "Carving grotto";
        // TODO: Different sizes and smoothness.
        _growSeed([pos], 30, 3, Tiles.grass);
        if (--count == 0) break;
      }
    }
  }

  void _addLake(Array2D<bool> cells) {
    // Try to find a place to drop it.
    for (var i = 0; i < 100; i++) {
      var x = rng.range(0, width - cells.width);
      var y = rng.range(0, height - cells.height);

      // See if the lake overlaps anything.
      var canPlace = true;
      for (var pos in cells.bounds) {
        if (cells[pos]) {
          if (!isWall(pos.x + x, pos.y + y)) {
            canPlace = false;
            break;
          }
        }
      }

      if (!canPlace) continue;

      // We found a spot, carve the water.
      for (var pos in cells.bounds) {
        if (cells[pos]) {
          setTile(pos.x + x, pos.y + y, Tiles.water, TileState.natural);
        }
      }

      // Grow a shoreline.
      var edges = <Vec>[];
      var shoreBounds =
          Rect.intersect(cells.bounds.offset(x, y).inflate(1), bounds);
      for (var pos in shoreBounds) {
        if (isWall(pos.x, pos.y) && hasNeighbor(pos, Tiles.water)) {
          setTile(pos.x, pos.y, Tiles.grass, TileState.natural);
          edges.add(pos);
        }
      }

      _growSeed(edges, edges.length, 4, Tiles.grass);
      return;
    }
  }

  Iterable<String> _addRooms() sync* {
    yield "Add starting room";
    // TODO: Sometimes start at a natural feature.

    var startRoom = Room.create(depth);
    while (true) {
      var x = rng.inclusive(0, width - startRoom.tiles.width);
      var y = rng.inclusive(0, height - startRoom.tiles.height);

      if (!_canPlace(startRoom, x, y)) continue;
      // TODO: After a certain number of tries, should try a different room.

      yield "Placing starting room";
      _placeRoom(startRoom, x, y);
      break;
    }

    yield "Adding rooms";

    // Keep growing as long as we have attachment points.
    var roomNumber = 1;
    while (_junctions.isNotEmpty) {
      var junction = rng.take(_junctions);
      var roomJunctionDir = junction.direction.rotate180;
      // TODO: Add junctions to natural features so we can grow through them.

      var placed = false;
      // TODO: Tune this.
      for (var i = 0; i < 20; i++) {
        // TODO: Choosing random room types looks kind of blah. It's weird to
        // have blob rooms randomly scattered amongst other ones. Instead, it
        // would be better to have "regions" in the dungeon that preferentially
        // lean towards some room types.
        //
        // Alternatively (or do both), have the room type chosen based on the
        // preceding rooms that lead to this junction so that you don't have
        // weird things like a closet leading to a great hall.
        var room = Room.create(depth);

        for (var roomJunction in room.junctions) {
          if (roomJunction.direction != roomJunctionDir) continue;

          // Calculate the room position by lining up the junctions.
          var roomPos = junction.position - roomJunction.position;

          if (!_canPlace(room, roomPos.x, roomPos.y)) continue;

          yield "Placing room ${roomNumber++}";
          _placeRoom(room, roomPos.x, roomPos.y);
          // TODO: Different doors.
          setTile(junction.position.x, junction.position.y, Tiles.openDoor,
              TileState.reached);

          placed = true;
          break;
        }

        if (placed) break;
      }
    }
  }

  bool _canPlace(Room room, int x, int y) {
    if (!bounds.containsRect(room.tiles.bounds.offset(x, y))) return false;

    var allowed = 0;
    var feature = 0;

    for (var pos in room.tiles.bounds) {
      // If the room doesn't care about the tile, it's fine.
      if (room.tiles[pos] == null) continue;

      // Otherwise, it must still be solid on the stage.
      var state = _states.get(pos.x + x, pos.y + y);
      var tile = stage.get(pos.x + x, pos.y + y).type;

      if (state == TileState.unused) {
        allowed++;
      } else if (state == TileState.natural) {
        feature++;
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
    return allowed > feature * 2;
  }

  void _placeRoom(Room room, int x, int y) {
    List<Vec> nature = [];

    for (var pos in room.tiles.bounds) {
      var tile = room.tiles[pos];
      if (tile == null) continue;

      // Don't erase existing natural features.
      var state = _states.get(pos.x + x, pos.y + y);
      if (state == TileState.natural) {
        if (tile.isTraversable) nature.add(pos.offset(x, y));
        continue;
      }

      setTile(pos.x + x, pos.y + y, tile, TileState.reached);
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

  void _tryAddJunction(Vec junctionPos, Direction junctionDir) {
    isBlocked(Direction direction) {
      var pos = junctionPos + direction;
      if (!safeBounds.contains(pos)) return true;
      return !isWall(pos.x, pos.y);
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
    var queue =
        new Queue.from(tiles.where((pos) => stage[pos].type.isTraversable));
    for (var pos in queue) {
      _states[pos] = TileState.reached;
    }

    while (queue.isNotEmpty) {
      var pos = queue.removeFirst();

      for (var dir in Direction.all) {
        var neighbor = pos + dir;
        if (!bounds.contains(neighbor)) continue;

        // If we hit the edge of the walkable natural area and we're facing a
        // straight direction, try to place a junction there to allow building
        // out from the area.
        if (_states[neighbor] != TileState.natural) {
          if (Direction.cardinal.contains(dir) && rng.range(100) < 30) {
            _tryAddJunction(neighbor, dir);
          }
          continue;
        }

        // Don't go into impassable natural areas like water.
        if (!stage[neighbor].type.isTraversable) continue;

        _states[neighbor] = TileState.reached;
        queue.add(neighbor);
      }
    }
  }

  /// Grows a randomly shaped blob starting at [start].
  ///
  /// Tries to add approximately [size] tiles of type [tile] that are directly
  /// attached to the starting tile. Only grows through tiles of [allowed]
  /// types. The larger [smoothing] is, the less jagged and spidery the blobs
  /// will be.
  void _growSeed(List<Vec> starts, int size, int smoothing, TileType tile) {
    var edges = new Set<Vec>();

    addNeighbors(Vec pos) {
      for (var dir in Direction.cardinal) {
        var neighbor = pos + dir;
        if (!safeBounds.contains(neighbor)) continue;

        // TODO: Allow passing in the tile types that can be grown into.
        if (stage[neighbor].type != Tiles.wall) continue;
        edges.add(neighbor);
      }
    }

    scorePos(Vec pos) {
      var score = 0;

      // Count straight neighbors higher to discourage diagonal growth.
      for (var dir in Direction.cardinal) {
        var neighbor = pos + dir;
        if (stage[neighbor].type == tile) score += 2;
      }

      for (var dir in Direction.intercardinal) {
        var neighbor = pos + dir;
        if (stage[neighbor].type == tile) score++;
      }

      return score;
    }

    starts.forEach(addNeighbors);

    var count = rng.triangleInt(size, size ~/ 2);
    var hack = 0;
    while (edges.isNotEmpty && count > 0) {
      if (hack++ > 1000) break;

      var edgeList = edges.toList();
      var best = <Vec>[];
      var bestScore = -1;

      // Pick a number of potential tiles to grow into and choose the least
      // jagged option -- the one with the most neighbors that are already
      // grown.
      for (var i = 0; i < smoothing; i++) {
        var pos = rng.item(edgeList);
        var score = scorePos(pos);

        if (score > bestScore) {
          best = [pos];
          bestScore = score;
        } else if (score == bestScore) {
          best.add(pos);
        }
      }

      var pos = rng.item(best);
      // TODO: Should be reached if start is reached.
      setTile(pos.x, pos.y, tile, TileState.natural);
      addNeighbors(pos);
      edges.remove(pos);

      count--;
    }
  }
}

class RiverPoint {
  final double x;
  final double y;
  final double radius;

  RiverPoint(this.x, this.y, this.radius);

  String toString() => "$x,$y ($radius)";
}
