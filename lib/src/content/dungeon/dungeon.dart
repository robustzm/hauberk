import 'package:piecemeal/piecemeal.dart';

import '../../engine.dart';
import '../floor_drops.dart';
import '../monsters.dart';
import '../tiles.dart';
import 'blob.dart';
import 'choke_points.dart';
import 'grotto.dart';
import 'lake.dart';
import 'river.dart';
import 'room.dart';

abstract class Biome {
  Iterable<String> generate(Dungeon dungeon);
  Iterable<String> decorate(Dungeon dungeon) => const [];
}

// TODO: Figure out how we want to do the region stuff around water.
//class WaterBiome extends Biome {
//  static const _maxDistance = 20;
//
//  Array2D<int> _tiles;
//
//    // Run breadth-first search to find out how far each tile is from water.
//    // TODO: This leads to a sort of diamond-like region around the water. An
//    // actual blur convolution might work better.
//    var queue = new Queue<Vec>();
//
//    for (var pos in dungeon.bounds) {
//      // TODO: Handle other kinds of water.
//      if (dungeon.getTileAt(pos) == Tiles.water ||
//          dungeon.getTileAt(pos) == Tiles.grass) {
//        queue.add(pos);
//        _tiles[pos] = 0;
//      }
//    }
//
//    while (queue.isNotEmpty) {
//      var pos = queue.removeFirst();
//      var distance = _tiles[pos] + 1;
//      if (distance >= _maxDistance) continue;
//
//      for (var dir in Direction.cardinal) {
//        var neighbor = pos + dir;
//
//        if (!dungeon.bounds.contains(neighbor)) continue;
//        if (_tiles[neighbor] != _maxDistance) continue;
//
//        _tiles[neighbor] = distance;
//        queue.add(neighbor);
//      }
//    }
//  }
//
//  double intensity(int x, int y) {
//    var distance = _tiles.get(x, y);
//    if (distance == 0) return 1.0;
//
//    return ((20 - distance) / 20.0).clamp(0.0, 1.0);
//  }
//}

class TileInfo {
  int distance;

  /// If this tile is for a junction (doorway, etc.) counts the number of
  /// passable tiles that can only be reached from the starting room by going
  /// through this tile.
  ///
  /// Will be 0 if this tile isn't a junction, or doesn't provide unique acces
  /// to any tiles.
  int reachableTiles = 0;

  /// If this tile is only reachable by going through a choke point junction,
  /// this contains the position of the nearest choke point.
  Vec chokePoint;

  // TODO: Temp. For visualization.
  int junctionId;
  int regionId;
}

class Dungeon {
  // TODO: Hack temp. Static so that dungeon_test can access these while it's
  // being generated.
  static List<Junction> debugJunctions;
  static Array2D<TileInfo> debugInfo;

  final Stage stage;
  final int depth;

  final List<Biome> _biomes = [];
  final Array2D<TileInfo> _info;
  final List<Vec> _corridors = [];

  Vec _heroPos;

  Rect get bounds => stage.bounds;
  Rect get safeBounds => stage.bounds.inflate(-1);

  int get width => stage.width;
  int get height => stage.height;

  Dungeon(this.stage, this.depth)
      : _info = new Array2D.generated(
            stage.width, stage.height, () => new TileInfo());

  Iterable<String> generate(Function(Vec) placeHero) sync* {
    debugJunctions = null;
    debugInfo = null;

    for (var y = 0; y < height; y++) {
      for (var x = 0; x < width; x++) {
        setTile(x, y, Tiles.rock);
      }
    }

    _chooseBiomes();

    for (var biome in _biomes) {
      yield* biome.generate(this);
    }

    // If a biome didn't place the hero, do it now.
    if (_heroPos == null) _heroPos = stage.findOpenTile();
    placeHero(_heroPos);

    // TODO: Placing the hero before placing decorations means the hero can end
    // up on a decoration. That's bad. But we want to calculate the distance
    // info before decorating... Maybe the info should be explicitly room-based
    // instead of tile based and then just pick the hero's starting *room*
    // first?

    yield "Populating dungeon";
    _calculateInfo();

    // Now that we know more global information, let the biomes use that to
    // tweak themselves.
    for (var biome in _biomes) {
      yield* biome.decorate(this);
    }

    // TODO: Should we do a sanity check for traversable tiles that ended up
    // unreachable?

    // Pick a point far from the hero to place the exit stairs.
    // TODO: Place the stairs in a more logical place like next to a wall, in a
    // room, etc?
    Vec stairPos;
    for (var i = 0; i < 10; i++) {
      var pos = stage.findOpenTile();
      // TODO: If there are unconnected regions (usually from a river looping
      // back onto the dungeon) then distance will be null and this may fail.
      if (stairPos == null || _info[pos].distance > _info[stairPos].distance) {
        stairPos = pos;
      }
    }

    setTileAt(stairPos, Tiles.stairs);

    // Monsters.
    var numSpawns = 40 + (depth ~/ 4);
    numSpawns = rng.triangleInt(numSpawns, numSpawns ~/ 3);
    for (var i = 0; i < numSpawns; i++) {
      _spawnMonster(Monsters.breeds.tryChoose(depth, "monster"));
    }

    // Items.
    // TODO: Tune this.
    var numItems = 6 + (depth ~/ 5);
    numItems = rng.triangleInt(numItems, numItems ~/ 2);
    for (var i = 0; i < numItems; i++) {
      // TODO: Distribute them more evenly?
      // TODO: Have biome affect density?
      var drop = FloorDrops.choose(depth);
      drop.spawn(this);
    }
  }

  TileType getTile(int x, int y) => stage.get(x, y).type;

  TileType getTileAt(Vec pos) => stage[pos].type;

  void setTile(int x, int y, TileType type) {
    stage.get(x, y).type = type;
  }

  void setTileAt(Vec pos, TileType type) {
    stage[pos].type = type;
  }

  bool isRock(int x, int y) => stage.get(x, y).type == Tiles.rock;
  bool isRockAt(Vec pos) => stage[pos].type == Tiles.rock;

  TileInfo infoAt(Vec pos) => _info[pos];

  /// Returns `true` if the cell at [pos] has at least one adjacent tile with
  /// type [tile].
  bool hasCardinalNeighbor(Vec pos, List<TileType> tiles) {
    for (var dir in Direction.cardinal) {
      var neighbor = pos + dir;
      if (!safeBounds.contains(neighbor)) continue;

      if (tiles.contains(stage[neighbor].type)) return true;
    }

    return false;
  }

  /// Returns `true` if the cell at [pos] has at least one adjacent tile with
  /// type [tile].
  bool hasNeighbor(Vec pos, TileType tile) {
    for (var dir in Direction.all) {
      var neighbor = pos + dir;
      if (!safeBounds.contains(neighbor)) continue;

      if (stage[neighbor].type == tile) return true;
    }

    return false;
  }

  void placeHero(Vec pos) {
    assert(_heroPos == null, "Should only place the hero once.");
    _heroPos = pos;
  }

  /// Grows a randomly shaped blob starting at [start].
  ///
  /// Tries to add approximately [size] tiles of type [tile] that are directly
  /// attached to the starting tile. Only grows through tiles of [allowed]
  /// types. The larger [smoothing] is, the less jagged and spidery the blobs
  /// will be.
  void growSeed(List<Vec> starts, int size, int smoothing, TileType tile) {
    var edges = new Set<Vec>();

    addNeighbors(Vec pos) {
      for (var dir in Direction.cardinal) {
        var neighbor = pos + dir;
        if (!safeBounds.contains(neighbor)) continue;

        // TODO: Allow passing in the tile types that can be grown into.
        var type = getTileAt(neighbor);
        if (type != Tiles.wall && type != Tiles.rock) continue;
        edges.add(neighbor);
      }
    }

    scorePos(Vec pos) {
      var score = 0;

      // Count straight neighbors higher to discourage diagonal growth.
      for (var dir in Direction.cardinal) {
        var neighbor = pos + dir;
        if (getTileAt(neighbor) == tile) score += 2;
      }

      for (var dir in Direction.intercardinal) {
        var neighbor = pos + dir;
        if (getTileAt(neighbor) == tile) score++;
      }

      return score;
    }

    starts.forEach(addNeighbors);

    var count = rng.triangleInt(size, size ~/ 2);
    while (edges.isNotEmpty && count > 0) {
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
      setTile(pos.x, pos.y, tile);
      addNeighbors(pos);
      edges.remove(pos);

      count--;
    }
  }

  Vec findOpenCorridor() {
    assert(_corridors.isNotEmpty, "Need to calculate info first.");

    _corridors.shuffle();
    for (var pos in _corridors) {
      if (stage.actorAt(pos) == null) return pos;
    }

    // If we get here, the corridors are all full.
    return stage.findOpenTile();
  }

  void _spawnMonster(Breed breed) {
    var pos = findSpawnTile(breed.location);
    var corpse = rng.oneIn(8);

    var breeds = breed.spawnAll(stage.game);

    spawn(Breed breed, Vec pos) {
      if (corpse) {
        stage.placeDrops(pos, breed);
      } else {
        stage.addActor(breed.spawn(stage.game, pos));
      }

      if (breed.stain != null) {
        // TODO: Larger stains for stronger monsters?
        _stain(breed.stain, pos, 5, 2);
      }
    }

    // TODO: Hack. Flow doesn't include the starting tile, so handle it here.
    spawn(breeds[0], pos);

    for (var breed in breeds.skip(1)) {
      // TODO: Hack. Need to create a new flow each iteration because it doesn't
      // handle actors being placed while the flow is being used -- it still
      // thinks those tiles are available. Come up with a better way to place
      // the monsters.
      var flow = new Flow(stage, pos);
      // TODO: Ideally, this would follow the location preference of the breed
      // too, even for minions of different breeds.
      var here = flow.nearestWhere((_) => true);

      // If there are no open tiles, discard the remaining monsters.
      if (here == null) break;

      spawn(breed, here);
    }
  }

  Vec findSpawnTile(SpawnLocation location) {
    switch (location) {
      case SpawnLocation.anywhere:
        return stage.findOpenTile();

      case SpawnLocation.corner:
        return _preferWalls(20, 4);

      case SpawnLocation.corridor:
        print("corridor");
        return _preferWalls(100, 6);

      case SpawnLocation.grass:
        return _preferTile(Tiles.grass, 40);

      case SpawnLocation.open:
        return _avoidWalls(20);

      case SpawnLocation.wall:
        return _preferWalls(20, 3);
    }

    throw "unreachable";
  }

  Vec _preferWalls(int tries, int idealWalls) {
    var bestWalls = -1;
    Vec best;
    for (var i = 0; i < tries; i++) {
      var pos = stage.findOpenTile();
      var walls = Direction.all.where((dir) => !getTileAt(pos + dir).isTraversable).length;

      // Don't try to crowd corridors.
      if (walls >= 6 && !rng.oneIn(3)) continue;

      // Early out as soon as we find a good enough spot.
      if (walls >= idealWalls) return pos;

      if (walls > bestWalls) {
        best = pos;
        bestWalls = walls;
      }
    }

    // Otherwise, take the best we could find.
    return best;
  }

  Vec _avoidWalls(int tries) {
    var bestWalls = 100;
    Vec best;
    for (var i = 0; i < tries; i++) {
      var pos = stage.findOpenTile();
      var walls = Direction.all.where((dir) => !getTileAt(pos + dir).isWalkable).length;

      // Early out as soon as we find a good enough spot.
      if (walls == 0) return pos;

      if (walls < bestWalls) {
        best = pos;
        bestWalls = walls;
      }
    }

    // Otherwise, take the best we could find.
    return best;
  }

  /// Tries to pick a random open tile with [type].
  ///
  /// If it fails to find one after [tries], returns any random open tile.
  Vec _preferTile(TileType type, int tries) {
    // TODO: This isn't very efficient. Probably better to build a cached set of
    // all tile positions by type.
    for (var i = 0; i < tries; i++) {
      var pos = stage.findOpenTile();
      if (getTileAt(pos) == type) return pos;
    }

    // Pick any tile.
    return stage.findOpenTile();
  }

  void _stain(TileType tile, Vec start, int distance, int count) {
    // Make a bunch of wandering paths from the starting point, leaving stains
    // as they go.
    for (var i = 0; i < count; i++) {
      var pos = start;
      for (var j = 0; j < distance; j++) {
        if (rng.percent(60) && getTileAt(pos) == Tiles.floor) {
          setTileAt(pos, tile);
        }

        var dirs = Direction.all
            .where((dir) => getTileAt(pos + dir).isTraversable)
            .toList();
        pos += rng.item(dirs);
      }
    }
  }

  void _chooseBiomes() {
    // TODO: Take depth into account?
    var hasWater = false;

    if (rng.oneIn(3)) {
      _biomes.add(new RiverBiome());
      hasWater = true;
    }

    if (hasWater && rng.oneIn(20) || !hasWater && rng.oneIn(10)) {
      // TODO: 64 is pretty big. Might want to make these a little smaller, but
      // not all the way down to 32.
      _biomes.add(new LakeBiome(Blob.make64()));
      hasWater = true;
    }

    if (hasWater && rng.oneIn(10) || !hasWater && rng.oneIn(5)) {
      _biomes.add(new LakeBiome(Blob.make32()));
      hasWater = true;
    }

    if (rng.oneIn(5)) {
      var ponds = rng.taper(0, 3);
      for (var i = 0; i < ponds; i++) {
        _biomes.add(new LakeBiome(Blob.make16()));
      }
    }

    // TODO: Add grottoes other places than just on shores.
    // Add some old grottoes that eroded before the dungeon was built.
    if (hasWater) _biomes.add(new GrottoBiome(rng.taper(2, 3)));

    _biomes.add(new RoomBiome(this));

    // Add a few grottoes that have collapsed after rooms. Unlike the above,
    // these may erode into rooms.
    // TODO: It looks weird that these don't place grass on the room floor
    // itself. Probably want to apply grass after everything is carved based on
    // humidity or something.
    // TODO: Should these be flood-filled for reachability?
    if (hasWater && rng.oneIn(3)) {
      _biomes.add(new GrottoBiome(rng.taper(1, 3)));
    }
  }

  /// Calculates a bunch of information about the dungeon used to intelligently
  /// populate it.
  void _calculateInfo() {
    // Calculate how far every reachable tile is from the hero's starting point.
    debugInfo = _info;
    var flow = new Flow(stage, _heroPos,
        canOpenDoors: true, canFly: true, ignoreActors: true);
    for (var pos in safeBounds) {
      _info[pos].distance = flow.getDistance(pos);
    }

    // Figure out which junctions are chokepoints that provide unique access to
    // some areas.
    // TODO: Do something with the results of this.
    new ChokePoints(this).calculate(_heroPos);

    // Find all corridor tiles.
    for (var pos in safeBounds) {
      if (!getTileAt(pos).isWalkable) continue;

      var walls = Direction.all.where((dir) {
        return !getTileAt(pos + dir).isTraversable;
      }).length;

      if (walls >= 6) _corridors.add(pos);
    }
  }
}
