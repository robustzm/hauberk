class Dungeon {
  static int NUM_ROOM_TRIES = 1000;
  static int NUM_JUNCTION_TRIES = 30;

  final Level level;
  final List<Room> _rooms;
  final Set<int> _usedColors;

  Dungeon(this.level)
  : _rooms = <Room>[],
    _usedColors = new Set<int>();

  TileType getTile(Vec pos) => level[pos].type;

  void setTile(Vec pos, TileType type) {
    level[pos].type = type;
  }

  void generate() {
    // Layout the rooms.
    int color = 0;
    for (var i = 0; i < NUM_ROOM_TRIES; i++) {
      final width = rng.range(3, 12);
      final height = rng.range(3, 8);
      final x = rng.range(1, level.width - width);
      final y = rng.range(1, level.height - height);

      final room = new Rect(x, y, width, height);
      if (!overlapsExistingRooms(room, true)){
        _rooms.add(new Room(room, ++color));
        _usedColors.add(color);
      }
    }

    // Add some one-tile "rooms" to work as corridor junctions.
    for (var i = 0; i < NUM_JUNCTION_TRIES; i++) {
      final x = rng.range(1, level.width - 3);
      final y = rng.range(1, level.height - 3);

      final room = new Rect(x, y, 1, 1);
      if (!overlapsExistingRooms(room, false)){
        _rooms.add(new Room(room, ++color));
        _usedColors.add(color);
      }
    }

    // Fill them in.
    for (final room in _rooms) {
      for (final pos in room.bounds) {
        setTile(pos, TileType.FLOOR);
      }
    }

    // Unify colors for rooms that are already overlapping.
    // TODO(bob): Inner loop shouldn't go through all rooms. Redundantly
    // considers each pair twice.
    for (final room in _rooms) {
      for (final other in _rooms) {
        if (room == other) continue;
        if (room.bounds.distanceTo(other.bounds) <= 0) {
          mergeColors(room, other);
        }
      }
    }

    carveCorridors();

    // We do this after carving corridors so that when corridors carve through
    // rooms, they don't mess up the decorations.
    decorateRooms();

    // We do this last so that we only add doors where they actually make sense
    // and don't have to worry about overlapping corridors and other stuff
    // leading to nonsensical doors.
    addDoors();
  }

  bool overlapsExistingRooms(Rect room, bool allowOverlap) {
    for (final other in _rooms) {
      if (room.distanceTo(other.bounds) <= 0) {
        // Allow some rooms to overlap.
        if (allowOverlap && rng.oneIn(50)) continue;
        return true;
      }
    }

    return false;
  }

  void mergeColors(Room a, Room b) {
    if (a.color == b.color) return;

    final color = Math.min(a.color, b.color);
    _usedColors.remove(Math.max(a.color, b.color));

    for (final room in _rooms) {
      if (room.color == a.color || room.color == b.color) {
        room.color = color;
      }
    }
  }

  void carveCorridors() {
    // Keep adding corridors until all rooms are connected.
    while (_usedColors.length > 1) {
      // Pick a random color.
      final fromColor = rng.item(_rooms).color;

      // Find the room that is nearest to any room of this color and has a
      // different color. (In other words, find the nearest unconnected room to
      // this set of rooms.)
      var nearestFrom = null;
      var nearestTo = null;
      var nearestDistance = 9999;

      // TODO(bob): Inner loop shouldn't go through all rooms. Redundantly
      // considers each pair twice.
      for (final fromRoom in _rooms) {
        if (fromRoom.color != fromColor) continue;

        for (final toRoom in _rooms) {
          if (toRoom.color == fromColor) continue;

          final distance = fromRoom.bounds.distanceTo(toRoom.bounds);
          if (distance < nearestDistance) {
            nearestFrom = fromRoom;
            nearestTo = toRoom;
            nearestDistance = distance;
          }
        }
      }

      carveCorridor(nearestFrom, nearestTo);
    }

    // Add some extra corridors so the dungeon isn't a minimum spanning tree.
    // TODO(bob): Inner loop shouldn't go through all rooms. Redundantly
    // considers each pair twice.
    for (final fromRoom in _rooms) {
      for (final toRoom in _rooms) {
        if (fromRoom == toRoom) continue;

        final distance = fromRoom.bounds.distanceTo(toRoom.bounds);
        if ((distance < 10) && rng.oneIn(20 + distance * 4)) {
          carveCorridor(fromRoom, toRoom);
        }
      }
    }
  }

  void carveCorridor(Room fromRoom, Room toRoom) {
    // Draw a corridor.
    final from = rng.vecInRect(fromRoom.bounds);
    final to = rng.vecInRect(toRoom.bounds);

    // TODO(bob): Make corridor meander more.
    var pos = from;
    while (pos != to) {
      if (pos.y < to.y) {
        pos = pos.offsetY(1);
      } else if (pos.y > to.y) {
        pos = pos.offsetY(-1);
      } else if (pos.x < to.x) {
        pos = pos.offsetX(1);
      } else if (pos.x > to.x) {
        pos = pos.offsetX(-1);
      }

      setTile(pos, TileType.FLOOR);
    }

    mergeColors(fromRoom, toRoom);
  }

  void decorateRooms() {
    // TODO(bob): Inner loop shouldn't go through all rooms. Redundantly
    // considers each pair twice.
    for (var i = 0; i < _rooms.length; i++) {
      final room = _rooms[i];

      // Don't decorate overlapping rooms.
      var overlap = false;
      for (var j = i + 1; j < _rooms.length; j++) {
        if (room.bounds.distanceTo(_rooms[j].bounds) <= 0) {
          overlap = true;
          break;
        }
      }
      if (overlap) continue;

      // Try the different kinds of decorations until one succeeds.
      if (rng.oneIn(4) && decoratePillars(room.bounds)) continue;
      if (rng.oneIn(4) && decorateInnerRoom(room.bounds)) continue;
      // TODO(bob): Add more decorations.
    }
  }

  /// Add rows of pillars to the edge(s) of the room.
  bool decoratePillars(Rect room) {
    if (room.width < 5) return false;
    if (room.height < 5) return false;

    // Only odd-sized sides get them, so make sure at least one side is.
    if ((room.width % 2 == 0) && (room.height % 2 == 0)) return false;

    final type = rng.oneIn(2) ? TileType.WALL : TileType.LOW_WALL;

    if (room.width % 2 == 1) {
      for (var x = room.left + 1; x < room.right - 1; x += 2) {
        setTile(new Vec(x, room.top + 1), type);
        setTile(new Vec(x, room.bottom - 2), type);
      }
    }

    if (room.height % 2 == 1) {
      for (var y = room.top + 1; y < room.bottom - 1; y += 2) {
        setTile(new Vec(room.left + 1, y), type);
        setTile(new Vec(room.right - 2, y), type);
      }
    }
  }

  /// If [room] is big enough, adds a floating room inside of it with a single
  /// entrance.
  bool decorateInnerRoom(Rect room) {
    if (room.width < 5) return false;
    if (room.height < 5) return false;

    final width = rng.range(3, room.width  - 2);
    final height = rng.range(3, room.height - 2);
    final x = rng.range(room.x + 1, room.right - width);
    final y = rng.range(room.y + 1, room.bottom - height);

    // Trace the room.
    final type = rng.oneIn(2) ? TileType.WALL : TileType.LOW_WALL;
    for (final pos in new Rect(x, y, width, height).trace()) {
      setTile(pos, type);
    }

    // Make an entrance. If it's a narrow room, always place the door on the
    // wider side.
    var directions;
    if ((width == 3) && (height > 3)) {
      directions = [Direction.E, Direction.W];
    } else if ((height == 3) && (width > 3)) {
      directions = [Direction.N, Direction.S];
    } else {
      directions = [Direction.N, Direction.S, Direction.E, Direction.W];
    }

    var door;
    switch (rng.item(directions)) {
      case Direction.N:
        door = new Vec(rng.range(x + 1, x + width - 1), y);
        break;
      case Direction.S:
        door = new Vec(rng.range(x + 1, x + width - 1), y + height - 1);
        break;
      case Direction.W:
        door = new Vec(x, rng.range(y + 1, y + height - 1));
        break;
      case Direction.E:
        door = new Vec(x + width - 1, rng.range(y + 1, y + height - 1));
        break;
    }
    setTile(door, TileType.FLOOR);

    return true;
  }

  bool isFloor(int x, int y) {
    return level.get(x, y).type == TileType.FLOOR;
  }

  bool isWall(int x, int y) {
    return level.get(x, y).type == TileType.WALL;
  }

  void addDoors() {
    // For each room, attempt to place doors along its edges.
    for (final room in _rooms) {
      // Top and bottom.
      for (var x = room.bounds.left; x < room.bounds.right; x++) {
        tryHorizontalDoor(x, room.bounds.top - 1);
        tryHorizontalDoor(x, room.bounds.bottom);
      }

      // Left and right.
      for (var y = room.bounds.top; y < room.bounds.bottom; y++) {
        tryVerticalDoor(room.bounds.left - 1, y);
        tryVerticalDoor(room.bounds.right, y);
      }
    }
  }

  void tryHorizontalDoor(int x, int y) {
    // Must be an opening where the door will be.
    if (!isFloor(x, y)) return;

    // Must be wall on either end of the door.
    if (!isWall(x - 1, y)) return;
    if (!isWall(x + 1, y)) return;

    // And open in front and behind it.
    if (!isFloor(x, y - 1)) return;
    if (!isFloor(x, y + 1)) return;

    addDoor(x, y);
  }

  void tryVerticalDoor(int x, int y) {
    // Must be an opening where the door will be.
    if (!isFloor(x, y)) return;

    // Must be wall on either end of the door.
    if (!isWall(x, y - 1)) return;
    if (!isWall(x, y + 1)) return;

    // And open in front and behind it.
    if (!isFloor(x - 1, y)) return;
    if (!isFloor(x + 1, y)) return;

    addDoor(x, y);
  }

  void addDoor(int x, int y) {
    var type;
    switch (rng.range(3)) {
    case 0: type = TileType.FLOOR; break; // No door.
    case 1: type = TileType.CLOSED_DOOR; break;
    case 2: type = TileType.OPEN_DOOR; break;
    }

    setTile(new Vec(x, y), type);
  }
}

class Room {
  final Rect bounds;
  int color;

  Room(this.bounds, this.color);
}

/*
/// Going down a passageway should feel like it's leading towards a goal.
///
/// The dungeon should be connected. Moreso, it should be multiply connected
/// with at least a few cycles.
///
/// Given the relatively small dungeon size, we should use space efficiently.
///
/// As much as possible, it should feel like the dungeon is a place that was
/// built by an intelligent hand with a sense of purpose.
///
/// Small-scale features should support tactical combat and make the micro-level
/// gameplay more interesting.
///
/// Different dungeons should have a different feel. There should be a sense of
/// consistency across the entire dungeon.
///
/// There should be foreshadowing: the player encounters something that hints
/// at what they will find as they keep exploring. Treasure hides behind secret
/// passageways. After defeating a particularly strong monster, there will be
/// more loot past it.

class Dungeon {
  final Level level;

  Dungeon(this.level);

  TileType getTile(Vec pos) => level[pos].type;

  void setTile(Vec pos, TileType type) {
    level[pos].type = type;
  }

  void generate() {
    placeGreatHall();
  }

  void placeGreatHall() {
    final width = rng.range(10, 50);
    final height = rng.range(1, 3);
    final x = rng.range(1, level.width - width - 1);
    final y = 20;

    for (final pos in new Rect(x, y, width, height)) {
      setTile(pos, TileType.FLOOR);
    }

    final doorSpacing = 4 + rng.range(6);
    final topWingHeight = rng.range(3, Math.min(y - 1, 20));
    final bottomWingHeight = rng.range(3, Math.min(level.height - y - height - 1, 20));

    placeRoomRow(x, y - topWingHeight - 1, width, topWingHeight, doorSpacing, false);
    placeRoomRow(x, y + height + 1, width, bottomWingHeight, doorSpacing, true);
  }

  void placeRoomRow(int x, int y, int width, int height, int doorSpacing,
      bool doorsOnTop) {
    var left = x;
    var door = left + doorSpacing ~/ 2;
    do {
      var right;
      if (door + doorSpacing >= x + width) {
        // Last room.
        right = x + width;
      } else {
        right = rng.range(door + 1, door + doorSpacing);
      }

      placeRooms(new Rect(left, y, right - left, height),
          door - left, doorsOnTop ? Direction.N : Direction.S);
      left = right + 1;
      door += doorSpacing;
    } while (left < x + width);
  }

  void placeRooms(Rect bounds, int doorPos, Direction doorSide) {
    for (final pos in bounds) {
      setTile(pos, TileType.FLOOR);
    }

    var door;
    switch (doorSide) {
      case Direction.N: door = new Vec(bounds.left + doorPos, bounds.top - 1); break;
      case Direction.E: door = new Vec(bounds.left - 1, bounds.top + doorPos); break;
      case Direction.S: door = new Vec(bounds.left + doorPos, bounds.bottom); break;
      case Direction.W: door = new Vec(bounds.right, bounds.top + doorPos); break;
    }

    setTile(door, TileType.FLOOR);
  }
}
*/