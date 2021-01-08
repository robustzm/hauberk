import 'dart:math' as math;

import 'package:piecemeal/piecemeal.dart';

import 'bucket_queue.dart';
import 'fov.dart';
import 'stage.dart';

/// Calculates the lighting and occlusion for the level.
///
/// This determines which tiles the hero (and the player) can see, as well as
/// how much light is cast on each tile.
///
/// This information potentially affects the entire level and needs to be
/// recalculated whenever the hero moves, a light-carrying actor moves, a door
/// is opened, a light-element attack is made, etc. Thus, this is one of the
/// most performance-critical parts of the engine.
///
/// The algorithms used here are designed to give acceptable results while also
/// being efficient, at the expense of sacrificing realism. Also, much of this
/// code is micro-optimized in ways that do matter for performance.
class Lighting {
  /// The maximum illumination value of a tile.
  ///
  /// This is clamped because the light propagation code uses a bucket queue
  /// which assumes a maximum light level.
  static const max = 255;

  /// The maximum illumination of a tile itself, excluding light from nearby
  /// actors. We clamp this lower so that you can still see the glow from a lit
  /// actor even in a maximally lit area.
  static const floorMax = 192;

  /// Given an emanation "level", returns the quantity of light produced.
  ///
  /// The levels are tuned higher-level echelons where each value corresponds
  /// to a "nice-looking" increasing radius of light. Changing the attenuation
  /// values below will likely require these to be re-tuned.
  static int emanationForLevel(int level) {
    switch (level) {
      case 1:
        // Only the tile itself.
        return 40;

      case 2:
        // A 3x3 "plus" shape.
        return 56;

      case 3:
        // A 3x3 square.
        return 72;

      case 4:
        // A 5x5 diamond.
        return 96;

      case 5:
        // A 5x5 circle.
        return 120;

      case 6:
        // A 7x7 circle.
        return 160;

      case 7:
        // A 9x9 circle.
        return 200;

      case 8:
        // A 11x11 circle.
        return 240;

      default:
        // Anything else is clamped.
        if (level <= 0) return 0;
        return max;
    }
  }

  final Stage _stage;

  /// The cached illumination on each tile from tile emanation values.
  final Array2D<int> _floorLight;

  /// The cached illumination on each tile from actor emanation.
  ///
  /// We store this separately from [_floorLight] because there are many more
  /// emanating tiles than actors but actors change (move) more frequently.
  /// Splitting these into two layers lets us recalculate one without
  /// invalidating the other.
  final Array2D<int> _actorLight;

  final Fov _fov;
  final BucketQueue<Vec> _queue = BucketQueue();

  bool _floorLightDirty = true;
  bool _actorLightDirty = true;
  bool _visibilityDirty = true;

  Lighting(Stage stage)
      : _stage = stage,
        _floorLight = Array2D(stage.width, stage.height, 0),
        _actorLight = Array2D(stage.width, stage.height, 0),
        _fov = Fov(stage);

  void dirtyFloorLight() {
    _floorLightDirty = true;
  }

  void dirtyActorLight() {
    _actorLightDirty = true;
  }

  void dirtyVisibility() {
    _visibilityDirty = true;
  }

  void refresh() {
    if (_floorLightDirty) _lightFloor();
    if (_actorLightDirty) _lightActors();
    if (_visibilityDirty) _fov.refresh(_stage.game.hero.pos);

    if (_floorLightDirty || _actorLightDirty || _visibilityDirty) {
      _mergeLayers();
      _lightWalls();
      _updateExplored();
    }

    _floorLightDirty = false;
    _actorLightDirty = false;
    _visibilityDirty = false;
  }

  /// Recalculates [_floorLight] by propagating light from the emanating tiles
  /// and items on the ground.
  void _lightFloor() {
    _queue.reset();

    for (var y = 0; y < _stage.height; y++) {
      for (var x = 0; x < _stage.width; x++) {
        var pos = Vec(x, y);
        var tile = _stage[pos];

        // Take the tile's light.
        var emanation = tile.emanation;

        // Add any light from items laying on the tile.
        var itemEmanation = 0;
        for (var item in _stage.itemsAt(pos)) {
          itemEmanation = math.max(itemEmanation, item.emanationLevel);
        }

        // Reduce emanation since floor lighting has less attenuation than
        // actor lighting. We don't want torches to glow farther on the floor
        // than when held.
        emanation += emanationForLevel(itemEmanation) ~/ 2;

        if (tile.element.emanates && tile.substance > 0) {
          // TODO: Different levels for different substances?
          emanation += emanationForLevel(7);
        }

        if (emanation > 0) {
          emanation = math.min(emanation, floorMax);
          _floorLight.set(x, y, emanation);
          _enqueue(pos, emanation);
        } else {
          _floorLight[pos] = 0;
        }
      }
    }

    _process(_floorLight, 256 ~/ 12);
  }

  /// Recalculates [_actorLight] by propagating light from the emanating actors.
  void _lightActors() {
    _actorLight.fill(0);
    _queue.reset();

    for (var actor in _stage.actors) {
      var emanation = emanationForLevel(actor.emanationLevel);

      if (emanation > 0) {
        _actorLight[actor.pos] = emanation;
        _enqueue(actor.pos, emanation);
      }
    }

    _process(_actorLight, 256 ~/ 6);
  }

  /// Combines the light layers of opaque tiles into a single summed
  /// illumination value.
  ///
  /// This should be called after the layers have been updated.
  void _mergeLayers() {
    for (var y = 0; y < _stage.height; y++) {
      for (var x = 0; x < _stage.width; x++) {
        var tile = _stage.get(x, y);
        if (tile.blocksView) continue;

        tile.illumination =
            (_floorLight.get(x, y) + _actorLight.get(x, y)).clamp(0, max);
      }
    }
  }

  /// Illuminates opaque tiles based on the nearest transparent neighbor's
  /// illumination.
  ///
  /// This must be called after [_mergeLayers].
  void _lightWalls() {
    // Now that we've illuminated the transparent tiles, illuminate the opaque
    // tiles based on their nearest open neighbor's illumination.
    for (var y = 0; y < _stage.height; y++) {
      for (var x = 0; x < _stage.width; x++) {
        var tile = _stage.get(x, y);
        if (!tile.blocksView) continue;

        var illumination = 0;
        var openNeighbor = false;

        void checkNeighbor(Vec offset) {
          // Not using Vec for math because that creates a lot of temporary
          // objects and this method is performance critical.
          var neighborX = x + offset.x;
          var neighborY = y + offset.y;

          if (neighborX < 0) return;
          if (neighborX >= _stage.width) return;
          if (neighborY < 0) return;
          if (neighborY >= _stage.height) return;

          var neighborTile = _stage.get(neighborX, neighborY);

          if (neighborTile.isOccluded) return;
          if (neighborTile.blocksView) return;

          openNeighbor = true;
          illumination = math.max(illumination, neighborTile.illumination);
        }

        // First, see if any of the cardinal neighbors are lit.
        for (var dir in Direction.cardinal) {
          checkNeighbor(dir);
        }

        // If so, we use their light. Only if not do we check the corners. This
        // makes the corners of room walls visible, but avoids overly lightening
        // walls that don't need to be because they aren't in corners.
        if (!openNeighbor) {
          for (var dir in Direction.intercardinal) {
            checkNeighbor(dir);
          }
        }

        tile.illumination = illumination;
      }
    }
  }

  void _updateExplored() {
    for (var y = 0; y < _stage.height; y++) {
      for (var x = 0; x < _stage.width; x++) {
        _stage.exploreAt(x, y);
      }
    }

    // The hero can always tell what they're standing on, even in the dark.
    _stage.explore(_stage.game.hero.pos, force: true);
  }

  /// Adds [pos] with [brightness] to the queue of lit tiles needing
  /// propagation.
  void _enqueue(Vec pos, int brightness) {
    // The brightest light has the lowest cost.
    _queue.add(pos, max - brightness);
  }

  void _process(Array2D<int> tiles, int attenuate) {
    // How much brightness decreases each diagonal step.
    //
    // The "1.5" scale is to roughly approximate the `sqrt(2)` Cartesian length
    // of the diagonal. This gives the fall-off a more circular appearance. This
    // is a little weird because distance in terms of game mechanics (i.e. how
    // many steps you have to take to get from point A to B) treats diagonals as
    // the same length as straight lines, but it looks nicer.
    //
    // Using 1.5 instead of a closer approximation to `sqrt(2)` because it makes
    // fall-off look a little less squarish.
    var diagonalAttenuate = (attenuate * 1.5).ceil();

    while (true) {
      var pos = _queue.removeNext();
      if (pos == null) break;

      var parentLight = tiles[pos];

      void checkNeighbor(Vec dir, int attenuation) {
        var neighborPos = pos + dir;

        if (!_stage.bounds.contains(neighborPos)) return;

        var neighborTile = _stage[neighborPos];

        // Don't illuminate opaque (we'll do this in a separate pass).
        if (neighborTile.blocksView) return;

        var illumination = parentLight - attenuation;

        // Don't revisit a tiles that are already as light as they should be.
        // We may actually revisit a tile if it is both directly lit (and thus
        // pre-emptively enqueued) *and* a nearby even brighter light is
        // brighter than its own direct illumination. That's OK. When that
        // happens, the second time we process the tile, nothing will happen.
        if (tiles[neighborPos] >= illumination) return;

        // Lighten the tile.
        tiles[neighborPos] = illumination;

        // If the neighbor is too dim for light to propagate from it, don't
        // bother enqueuing it.
        if (illumination <= attenuate) return;

        // Check the tile's neighbors.
        _enqueue(neighborPos, illumination);
      }

      checkNeighbor(Direction.n, attenuate);
      checkNeighbor(Direction.s, attenuate);
      checkNeighbor(Direction.e, attenuate);
      checkNeighbor(Direction.w, attenuate);
      checkNeighbor(Direction.ne, diagonalAttenuate);
      checkNeighbor(Direction.se, diagonalAttenuate);
      checkNeighbor(Direction.nw, diagonalAttenuate);
      checkNeighbor(Direction.sw, diagonalAttenuate);
    }
  }
}
