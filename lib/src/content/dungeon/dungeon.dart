import 'dart:math' as math;

import 'package:piecemeal/piecemeal.dart';

import '../../engine.dart';
import '../decor/decor.dart';
import '../item/floor_drops.dart';
import '../monster/monsters.dart';
import '../tiles.dart';
import 'blob.dart';
import 'grotto.dart';
import 'junction.dart';
import 'lake.dart';
import 'place.dart';
import 'river.dart';
import 'room.dart';

// TODO: Eliminate biome as a class and just have dungeon call it directly?
abstract class Biome {
  Iterable<String> generate();
}

// TODO: Rename to something generic like "Generator" and then use "Dungeon"
// to refer to the "rooms and passages" biome.
class Dungeon {
  // TODO: Generate magical shrine/chests that let the player choose from one
  // of a few items. This should help reduce the number of useless-for-this-hero
  // items that are dropped.

  // TODO: Hack temp. Static so that dungeon_test can access these while it's
  // being generated.
  static Dungeon last;
  static List<Place> debugPlaces;

  final Lore _lore;
  final Stage stage;
  final int depth;

  final JunctionSet junctions = new JunctionSet();

  final List<Biome> _biomes = [];

  final List<Place> _places = [];
  final PlaceGraph _placeGraph = new PlaceGraph();

  /// The unique breeds that have already been place on the stage. Ensures we
  /// don't spawn the same unique more than once.
  var _spawnedUniques = new Set<Breed>();

  Rect get bounds => stage.bounds;

  Rect get safeBounds => stage.bounds.inflate(-1);

  int get width => stage.width;

  int get height => stage.height;

  Dungeon(this._lore, this.stage, this.depth);

  Iterable<String> generate(Function(Vec) placeHero) sync* {
    last = this;
    debugPlaces = _places;

    for (var y = 0; y < height; y++) {
      for (var x = 0; x < width; x++) {
        setTile(x, y, Tiles.rock);
      }
    }

    _chooseBiomes();

    for (var biome in _biomes) {
      yield* biome.generate();
    }

    yield "Applying themes";

    // Apply and spread themes from the biomes.
    _places.sort((a, b) => b.cells.length.compareTo(a.cells.length));
    _placeGraph.findConnections(this, _places);

    for (var place in _places) {
      place.applyThemes();
    }

    yield "Placing decor";
    for (var i = 0; i < 1000; i++) {
      var pos = rng.vecInRect(safeBounds);
      var place = placeAt(pos);
      if (place == null) continue;

      var theme = place.chooseTheme();
      var decor = Decor.choose(theme);
      if (decor == null) continue;

      var allowed = <Vec>[];

      for (var cell in place.cells) {
        var offset = cell.offset(-1, -1);
        if (decor.canPlace(this, offset)) {
          allowed.add(offset);
        }
      }

      if (allowed.isNotEmpty) {
        decor.place(this, rng.item(allowed));
        yield "Placed decor";
      }
    }

    // TODO: Should we do a sanity check for traversable tiles that ended up
    // unreachable?

    // TODO: Use room places and themes for placing stairs.
    var stairCount = rng.range(2, 4);
    for (var i = 0; i < stairCount; i++) {
      var pos = stage.findOpenTile();
      setTileAt(pos, Tiles.stairs);
    }

    for (var place in _places) {
      // TODO: Doing this here is kind of hacky.
      rng.shuffle(place.cells);

      _placeMonsters(place);
      _placeItems(place);
    }

    // Place the hero in the starting place.
    var startPlace = _places.firstWhere((place) => place.hasHero);
    // TODO: Because every dungeon has a room biome, we assume there is a place
    // that's marked to have the hero. If that's not the case, we'll need to
    // pick a place here.

    placeHero(_tryFindSpawnPos(
        startPlace.cells, MotilitySet.walk, SpawnLocation.open,
        avoidActors: true));
  }

  Place placeAt(Vec pos) => _placeGraph.placeAt(pos);

  TileType getTile(int x, int y) => stage.get(x, y).type;

  TileType getTileAt(Vec pos) => stage[pos].type;

  void setTile(int x, int y, TileType type) {
    var tile = stage.get(x, y);
    tile.type = type;
    _tileEmanation(tile);
  }

  void setTileAt(Vec pos, TileType type) {
    var tile = stage[pos];
    tile.type = type;
    _tileEmanation(tile);
  }

  void _tileEmanation(Tile tile) {
    // TODO: Move this code somewhere better.
    // Water has occasional sparkles.
    if (tile.type == Tiles.water && rng.percent(2)) {
      tile.addEmanation(Lighting.emanationForLevel(5));
    }
  }

  bool isRock(int x, int y) => stage.get(x, y).type == Tiles.rock;

  bool isRockAt(Vec pos) => stage[pos].type == Tiles.rock;

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

  void addPlace(Place place) {
    _places.add(place);
  }

  /// Grows a randomly shaped blob starting at [start].
  ///
  /// Tries to add approximately [size] tiles of type [tile] that are directly
  /// attached to the starting tile. Only grows through tiles of [allowed]
  /// types. The larger [smoothing] is, the less jagged and spidery the blobs
  /// will be.
  void growSeed(List<Vec> starts, int size, int smoothing, TileType tile,
      [List<Vec> cells]) {
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
      setTileAt(pos, tile);
      addNeighbors(pos);
      edges.remove(pos);

      if (cells != null) cells.add(pos);

      count--;
    }
  }

  void _placeMonsters(Place place) {
    // Don't spawn monsters in the hero's starting room.
    if (place.hasHero) return;

    var spawnCount = _rollCount(place, place.monsterDensity);
    while (spawnCount > 0) {
      var theme = place.chooseTheme();
      var breed = Monsters.breeds.tryChoose(depth, theme);

      // Don't place dead or redundant uniques.
      if (breed.flags.unique) {
        if (_lore.slain(breed) > 0) continue;
        if (_spawnedUniques.contains(breed)) continue;

        _spawnedUniques.add(breed);
      }

      var spawned = _spawnMonster(place, breed);

      // Stop if we ran out of open tiles.
      if (spawned == null) break;

      spawnCount -= spawned;
    }
  }

  void _placeItems(Place place) {
    var density = place.itemDensity;

    // Increase the odds of the hero immediately finding something.
    if (place.hasHero) density *= 1.2;

    var dropCount = _rollCount(place, density);
    for (var i = 0; i < dropCount; i++) {
      var theme = place.chooseTheme();

      var floorDrop = FloorDrops.choose(theme, depth);
      var pos = _tryFindSpawnPos(
          place.cells, MotilitySet.walk, floorDrop.location,
          avoidActors: false);
      if (pos == null) break;

      stage.placeDrops(pos, MotilitySet.walk, floorDrop.drop);
    }
  }

  /// Rolls how many of something should be dropped in [place], taking the
  /// place's size and [density] into account.
  int _rollCount(Place place, double density) {
    // TODO: Tune based on depth?
    // Calculate the average number of monsters for a place with this many
    // cells.
    //
    // We want a roughly even difficulty across places of different sizes. That
    // means more monsters in bigger places. However, monsters can easily cross
    // an open space which means scaling linearly makes larger places more
    // difficult -- it's easy for the hero to get swarmed. The exponential
    // tapers that off a bit so that larger areas don't scale quite linearly.
    var base = math.pow(place.cells.length, 0.80) * density;

    // From the average, roll an actual number using a normal distribution
    // centered on the base number. The distribution gets wider as the base
    // gets larger.
    var floatCount = base + _normal() * (base / 2);

    // The actual number is floating point. For small places, it will likely be
    // less than 1. Handle that floating point reside by treat it as the chance,
    // out of 1.0, of having one additional monster. For example, 4.2 means
    // there will be 4 monsters, with a 20% chance of 5.
    var count = floatCount.floor();
    if (rng.float(1.0) < floatCount - count) count++;
    return count;
  }

  /// Calculate a random number with a normal distribution.
  ///
  /// Note that this means results may be less than -1.0 or greater than 1.0.
  ///
  /// Uses https://en.wikipedia.org/wiki/Marsaglia_polar_method.
  double _normal() {
    // TODO: Move into piecemeal.
    double u, v, lengthSquared;

    do {
      u = rng.float(-1.0, 1.0);
      v = rng.float(-1.0, 1.0);
      lengthSquared = u * u + v * v;
    } while (lengthSquared >= 1.0);

    return u * math.sqrt(-2.0 * math.log(lengthSquared) / lengthSquared);
  }

  int _spawnMonster(Place place, Breed breed) {
    var pos = _tryFindSpawnPos(place.cells, breed.motilities, breed.location,
        avoidActors: true);

    // If there are no remaining open tiles, abort.
    if (pos == null) return null;

    var isCorpse = rng.oneIn(8);
    var breeds = breed.spawnAll();

    var spawned = 0;
    spawn(Breed breed, Vec pos) {
      if (isCorpse) {
        stage.placeDrops(pos, breed.motilities, breed.drop);
      } else {
        stage.addActor(breed.spawn(stage.game, pos));
        spawned++;
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
      var flow = new MotilityFlow(stage, pos, breed.motilities);
      // TODO: Ideally, this would follow the location preference of the breed
      // too, even for minions of different breeds.
      var here = flow.reachable.firstWhere((_) => true, orElse: () => null);

      // If there are no open tiles, discard the remaining monsters.
      if (here == null) break;

      spawn(breed, here);
    }

    return spawned;
  }

  Vec _tryFindSpawnPos(
      List<Vec> cells, MotilitySet motilities, SpawnLocation location,
      {bool avoidActors}) {
    int minWalls;
    int maxWalls;

    switch (location) {
      case SpawnLocation.anywhere:
        minWalls = 0;
        maxWalls = 8;
        break;

      case SpawnLocation.wall:
        minWalls = 3;
        maxWalls = 8;
        break;

      case SpawnLocation.corner:
        minWalls = 4;
        maxWalls = 8;
        break;

      case SpawnLocation.open:
        minWalls = 0;
        maxWalls = 0;
        break;
    }

    Vec acceptable;

    for (var pos in cells) {
      if (!getTileAt(pos).canEnterAny(motilities)) continue;

      if (stage.actorAt(pos) != null) continue;

      var wallCount =
          Direction.all.where((dir) => !getTileAt(pos + dir).isWalkable).length;

      if (wallCount >= minWalls && wallCount <= maxWalls) return pos;

      // This position isn't ideal, but if we don't find anything else, we'll
      // settle for it.
      acceptable = pos;
    }

    return acceptable;
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
        if (dirs.isEmpty) return;
        pos += rng.item(dirs);
      }
    }
  }

  void _chooseBiomes() {
    // TODO: Take depth into account.
    var hasWater = _tryRiver();

    if (_tryLake64(hasWater)) hasWater = true;
    if (_tryLake32(hasWater)) hasWater = true;
    if (_tryLakes16(hasWater)) hasWater = true;

    // TODO: Grottoes don't add cells to the appropriate place.
    // TODO: Add grottoes other places than just on shores.
    // Add some old grottoes that eroded before the dungeon was built.
    if (hasWater) _biomes.add(new GrottoBiome(this, rng.taper(2, 3)));

    _biomes.add(new RoomBiome(this));

    // Add a few grottoes that have collapsed after rooms. Unlike the above,
    // these may erode into rooms.
    // TODO: It looks weird that these don't place grass on the room floor
    // itself. Probably want to apply grass after everything is carved based on
    // humidity or something.
    // TODO: Should these be flood-filled for reachability?
    if (hasWater && rng.oneIn(3)) {
      _biomes.add(new GrottoBiome(this, rng.taper(1, 3)));
    }
  }

  bool _tryRiver() {
    if (!rng.oneIn(3)) return false;

    _biomes.add(new RiverBiome(this));
    return true;
  }

  bool _tryLake64(bool hasWater) {
    if (width <= 64 || height <= 64) return false;

    var odds = hasWater ? 20 : 10;
    if (!rng.oneIn(odds)) return false;

    // TODO: 64 is pretty big. Might want to make these a little smaller, but
    // not all the way down to 32.
    _biomes.add(new LakeBiome(this, Blob.make64()));
    return true;
  }

  bool _tryLake32(bool hasWater) {
    if (width <= 32 || height <= 32) return false;

    var odds = hasWater ? 10 : 5;
    if (!rng.oneIn(odds)) return false;

    _biomes.add(new LakeBiome(this, Blob.make32()));
    return true;
  }

  bool _tryLakes16(bool hasWater) {
    if (!rng.oneIn(5)) return false;

    var ponds = rng.taper(0, 3);
    for (var i = 0; i < ponds; i++) {
      _biomes.add(new LakeBiome(this, Blob.make16()));
    }

    return true;
  }
}
