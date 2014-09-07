library hauberk.content.room_decorator;

import 'package:piecemeal/piecemeal.dart';

import 'stage_builder.dart';
import 'tiles.dart';

/// Mixin class with methods for decorating a room.
abstract class RoomDecorator implements StageBuilder {
  /// Places a few tables in the room.
  bool decorateTable(Rect room) {
    var pos = rng.vecInRect(room);

    // Don't block an exit.
    if (pos.x == room.left && getTile(pos.offsetX(-1)) != Tiles.wall) {
      return false;
    }

    if (pos.y == room.top && getTile(pos.offsetY(-1)) != Tiles.wall) {
      return false;
    }

    if (pos.x == room.right && getTile(pos.offsetX(1)) != Tiles.wall) {
      return false;
    }

    if (pos.y == room.bottom && getTile(pos.offsetY(1)) != Tiles.wall) {
      return false;
    }

    setTile(pos, Tiles.table);
    return true;
  }

  /// Add rows of pillars to the edge(s) of the room.
  bool decoratePillars(Rect room) {
    if (room.width < 5) return false;
    if (room.height < 5) return false;

    // Only odd-sized sides get them, so make sure at least one side is.
    if ((room.width % 2 == 0) && (room.height % 2 == 0)) return false;

    var type = rng.oneIn(2) ? Tiles.wall : Tiles.lowWall;

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

    return true;
  }

  /// If [room] is big enough, adds a floating room inside of it with a single
  /// entrance.
  bool decorateInnerRoom(Rect room) {
    if (room.width < 5) return false;
    if (room.height < 5) return false;

    var width = rng.inclusive(3, room.width  - 2);
    var height = rng.inclusive(3, room.height - 2);
    var x = rng.range(room.x + 1, room.right - width);
    var y = rng.range(room.y + 1, room.bottom - height);

    // Trace the room.
    var type = rng.oneIn(3) ? Tiles.wall : Tiles.lowWall;
    for (var pos in new Rect(x, y, width, height).trace()) {
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
    setTile(door, Tiles.floor);

    return true;
  }

  /// Tries to randomly bring in the corners and round off the room.
  bool decorateRoundedCorners(Rect room) {
    if (room.width <= 3 || room.height <= 3) return false;

    var modified = false;

    // Try the top-left corner.
    if (getTile(room.topLeft + Direction.W) == Tiles.wall &&
        getTile(room.topLeft + Direction.N) == Tiles.wall) {
      setTile(room.topLeft, Tiles.wall);
      modified = true;

      if (room.height > 5 &&
          getTile(room.topLeft + Direction.SW) == Tiles.wall) {
        setTile(room.topLeft + Direction.S, Tiles.wall);
      }

      if (room.width > 5 &&
          getTile(room.topLeft + Direction.NE) == Tiles.wall) {
        setTile(room.topLeft + Direction.E, Tiles.wall);
      }
    }

    // Try the top-right corner.
    var topRight = room.topRight + Direction.W;
    if (getTile(topRight + Direction.E) == Tiles.wall &&
        getTile(topRight + Direction.N) == Tiles.wall) {
      setTile(topRight, Tiles.wall);
      modified = true;

      if (room.height > 5 &&
          getTile(topRight + Direction.SE) == Tiles.wall) {
        setTile(topRight + Direction.S, Tiles.wall);
      }

      if (room.width > 5 &&
          getTile(topRight + Direction.NW) == Tiles.wall) {
        setTile(topRight + Direction.W, Tiles.wall);
      }
    }

    // Try the bottom-left corner.
    var bottomLeft = room.bottomLeft + Direction.N;
    if (getTile(bottomLeft + Direction.W) == Tiles.wall &&
        getTile(bottomLeft + Direction.S) == Tiles.wall) {
      setTile(bottomLeft, Tiles.wall);
      modified = true;

      if (room.height > 5 &&
          getTile(bottomLeft + Direction.NW) == Tiles.wall) {
        setTile(bottomLeft + Direction.N, Tiles.wall);
      }

      if (room.width > 5 &&
          getTile(bottomLeft + Direction.SE) == Tiles.wall) {
        setTile(bottomLeft + Direction.E, Tiles.wall);
      }
    }

    // Try the bottom-right corner.
    var bottomRight = room.bottomRight + Direction.NW;
    if (getTile(bottomRight + Direction.E) == Tiles.wall &&
        getTile(bottomRight + Direction.S) == Tiles.wall) {
      setTile(bottomRight, Tiles.wall);
      modified = true;

      if (room.height > 5 &&
          getTile(bottomRight + Direction.SW) == Tiles.wall) {
        setTile(bottomRight + Direction.S, Tiles.wall);
      }

      if (room.width > 5 &&
          getTile(bottomRight + Direction.NE) == Tiles.wall) {
        setTile(bottomRight + Direction.E, Tiles.wall);
      }
    }

    return modified;
  }
}
