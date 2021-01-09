import 'package:malison/malison.dart';
import 'package:malison/malison_web.dart';
import 'package:piecemeal/piecemeal.dart';

import '../engine.dart';
import '../hues.dart';
import 'draw.dart';
import 'game_screen.dart';
import 'input.dart';

/// Modal dialog for letting the user select a target to perform a
/// [UsableSkill] on.
class TargetDialog extends Screen<Input> {
  static const _numFrames = 5;
  static const _ticksPerFrame = 5;

  final GameScreen _gameScreen;
  final int _range;
  final void Function(Vec target) _onSelect;
  final List<Monster> _monsters = <Monster>[];

  bool _targetingFloor = false;
  int _animateOffset = 0;

  bool get isTransparent => true;

  // TODO: Prevent targeting self if skill doesn't allow it?

  TargetDialog(this._gameScreen, this._range, this._onSelect) {
    // Find the targetable monsters.
    var hero = _gameScreen.game.hero;
    for (var actor in _gameScreen.game.stage.actors) {
      if (actor is! Monster) continue;
      if (!hero.canPerceive(actor)) continue;

      // Must be within range.
      var toMonster = actor.pos - hero.pos;
      if (toMonster > _range) continue;

      _monsters.add(actor);
    }

    if (_monsters.isEmpty) {
      // No visible monsters, so switch to floor targeting.
      _targetingFloor = true;
      _gameScreen.targetFloor(_gameScreen.game.hero.pos);
    } else {
      // Default to targeting the nearest monster to the hero.
      _targetNearest(_gameScreen.game.hero.pos);
    }
  }

  bool _targetNearest(Vec pos) {
    if (_monsters.isEmpty) return false;

    Actor nearest;
    for (var monster in _monsters) {
      if (nearest == null || pos - monster.pos < pos - nearest.pos) {
        nearest = monster;
      }
    }

    _gameScreen.targetActor(nearest);
    return true;
  }

  bool handleInput(Input input) {
    switch (input) {
      case Input.ok:
        if (_gameScreen.currentTarget != null) {
          ui.pop();
          _onSelect(_gameScreen.currentTarget);
        }
        break;

      case Input.cancel:
        ui.pop();
        break;

      case Input.nw:
        _changeTarget(Direction.nw);
        break;
      case Input.n:
        _changeTarget(Direction.n);
        break;
      case Input.ne:
        _changeTarget(Direction.ne);
        break;
      case Input.w:
        _changeTarget(Direction.w);
        break;
      case Input.e:
        _changeTarget(Direction.e);
        break;
      case Input.sw:
        _changeTarget(Direction.sw);
        break;
      case Input.s:
        _changeTarget(Direction.s);
        break;
      case Input.se:
        _changeTarget(Direction.se);
        break;
    }

    return true;
  }

  bool keyDown(int keyCode, {bool shift, bool alt}) {
    if (keyCode == KeyCode.tab && _monsters.isNotEmpty) {
      _targetingFloor = !_targetingFloor;
      if (!_targetingFloor) {
        // Target the nearest monster to the floor tile we were previously
        // targeting.
        _targetNearest(_gameScreen.currentTarget ?? _gameScreen.game.hero.pos);
      } else {
        _gameScreen.targetFloor(_gameScreen.currentTarget);
      }
      return true;
    }

    return false;
  }

  void update() {
    _animateOffset = (_animateOffset + 1) % (_numFrames * _ticksPerFrame);
    if (_animateOffset % _ticksPerFrame == 0) dirty();
  }

  void render(Terminal terminal) {
    var stage = _gameScreen.game.stage;
    var hero = _gameScreen.game.hero;

    // Show the range field.
    for (var pos in _gameScreen.cameraBounds) {
      var tile = stage[pos];

      // Don't leak information to the player about unknown tiles. Instead,
      // treat them as potentially targetable.
      var actor = stage.actorAt(pos);
      if (tile.isExplored) {
        // If the tile can't be reached, don't show it as targetable.
        if (tile.isOccluded) continue;

        if (!tile.isWalkable && tile.blocksView) continue;
        if (actor != null) continue;
        if (stage.isItemAt(pos)) continue;
      } else if (_isKnownOccluded(pos)) {
        // The player knows it can't be targeted.
        continue;
      } else if (actor != null && hero.canPerceive(actor)) {
        // Show the actor.
        continue;
      }

      // Must be in range.
      var toPos = pos - hero.pos;
      if (toPos > _range) continue;

      int charCode;
      if (tile.isExplored) {
        var appearance = tile.type.appearance;
        if (appearance is Glyph) {
          charCode = appearance.char;
        } else {
          charCode = (appearance as List<Glyph>)[0].char;
        }
      } else {
        // Since the hero doesn't know what's on the tile, optimistically guess
        // that it's some kind of floor.
        charCode = CharCode.middleDot;
      }

      _gameScreen.drawStageGlyph(
          terminal, pos.x, pos.y, Glyph.fromCharCode(charCode, gold));
    }

    var target = _gameScreen.currentTarget;
    if (target == null) return;

    // Don't target a tile the player knows can't be hit.
    var reachedTarget = false;
    var tile = _gameScreen.game.stage[target];
    if (!tile.isExplored || (!tile.blocksView && tile.isOccluded)) {
      // Show the path that the bolt will trace, stopping when it hits an
      // obstacle.
      var i = _animateOffset ~/ _ticksPerFrame;
      for (var pos in Line(_gameScreen.game.hero.pos, target)) {
        // Note if we made it to the target.
        if (pos == target) {
          reachedTarget = true;
          break;
        }

        var tile = stage[pos];

        // Don't leak information about unexplored tiles.
        if (tile.isExplored) {
          if (stage.actorAt(pos) != null) break;
          if (!tile.isFlyable) break;
        }

        _gameScreen.drawStageGlyph(
            terminal,
            pos.x,
            pos.y,
            Glyph.fromCharCode(
                CharCode.bullet, (i == 0) ? gold : darkCoolGray));
        i = (i + _numFrames - 1) % _numFrames;
      }
    }

    // Highlight the reticle if the bolt will reach the target.
    var reticleColor = reachedTarget ? gold : darkCoolGray;
    _gameScreen.drawStageGlyph(
        terminal, target.x - 1, target.y, Glyph('-', reticleColor));
    _gameScreen.drawStageGlyph(
        terminal, target.x + 1, target.y, Glyph('-', reticleColor));
    _gameScreen.drawStageGlyph(
        terminal, target.x, target.y - 1, Glyph('|', reticleColor));
    _gameScreen.drawStageGlyph(
        terminal, target.x, target.y + 1, Glyph('|', reticleColor));
    if (!reachedTarget) {
      _gameScreen.drawStageGlyph(
          terminal, target.x, target.y, Glyph('X', reticleColor));
    }

    var helpKeys = <String, String>{};
    if (_monsters.isEmpty) {
      helpKeys["↕↔"] = "Choose tile";
    } else if (_targetingFloor) {
      helpKeys["↕↔"] = "Choose tile";
      helpKeys["Tab"] = "Target monsters";
    } else {
      helpKeys["↕↔"] = "Choose monster";
      helpKeys["Tab"] = "Target floor";
    }
    helpKeys["Esc"] = "Cancel";
    Draw.helpKeys(terminal, helpKeys, "Choose a target");
  }

  void _changeTarget(Direction dir) {
    if (_targetingFloor) {
      _changeFloorTarget(dir);
    } else {
      _changeMonsterTarget(dir);
    }
  }

  void _changeFloorTarget(Direction dir) {
    var pos = _gameScreen.currentTarget + dir;

    // Don't target out of range.
    var toPos = pos - _gameScreen.game.hero.pos;
    if (toPos > _range) return;

    _gameScreen.targetFloor(pos);
  }

  /// Target the nearest monster in [dir] from the current target. Precisely,
  /// draws a line perpendicular to [dir] and divides the monsters into two
  /// half-planes. If the half-plane towards [dir] contains any monsters, then
  /// this targets the nearest one. Otherwise, it wraps around and targets the
  /// *farthest* monster in the other half-place.
  void _changeMonsterTarget(Direction dir) {
    var ahead = <Monster>[];
    var behind = <Monster>[];

    var perp = dir.rotateLeft90;
    for (var monster in _monsters) {
      var relative = monster.pos - _gameScreen.currentTarget;
      var dotProduct = perp.x * relative.y - perp.y * relative.x;
      if (dotProduct > 0) {
        ahead.add(monster);
      } else {
        behind.add(monster);
      }
    }

    var nearest = _findLowest<Monster>(ahead,
        (monster) => (monster.pos - _gameScreen.currentTarget).lengthSquared);
    if (nearest != null) {
      _gameScreen.targetActor(nearest);
      return;
    }

    var farthest = _findHighest<Monster>(behind,
        (monster) => (monster.pos - _gameScreen.currentTarget).lengthSquared);
    if (farthest != null) {
      _gameScreen.targetActor(farthest);
    }
  }

  /// Returns `true` if there is at least one *explored* tile that block LOS to
  /// [target].
  ///
  /// We need to ensure the targeting dialog doesn't leak information about
  /// unexplored tiles. At the same time, we do want to let the player try to
  /// target unexplored tiles because they may turn out to be reachable. (In
  /// particular, it's useful to let them lob light sources into the dark.)
  ///
  /// This is used to determine which unexplored tiles should be treated as
  /// targetable. We don't want to allow all unexplored tiles to be targeted
  /// because that would include tiles behind known walls, so this filters out
  /// any tile that is blocked by a known tile.
  bool _isKnownOccluded(Vec target) {
    var stage = _gameScreen.game.stage;

    for (var pos in Line(_gameScreen.game.hero.pos, target)) {
      // Note if we made it to the target.
      if (pos == target) return false;

      if (!stage.bounds.contains(pos)) return true;

      var tile = stage[pos];
      if (tile.isExplored && tile.blocksView) return true;
    }

    throw AssertionError("Unreachable.");
  }
}

/// Finds the item in [collection] whose score is lowest.
///
/// The score for an item is determined by calling [callback] on it. Returns
/// `null` if the [collection] is `null` or empty.
T _findLowest<T>(Iterable<T> collection, num Function(T) callback) {
  if (collection == null) return null;

  T bestItem;
  num bestScore;

  for (var item in collection) {
    var score = callback(item);
    if (bestScore == null || score < bestScore) {
      bestItem = item;
      bestScore = score;
    }
  }

  return bestItem;
}

/// Finds the item in [collection] whose score is highest.
///
/// The score for an item is determined by calling [callback] on it. Returns
/// `null` if the [collection] is `null` or empty.
T _findHighest<T>(Iterable<T> collection, num Function(T) callback) {
  if (collection == null) return null;

  T bestItem;
  num bestScore;

  for (var item in collection) {
    var score = callback(item);
    if (bestScore == null || score > bestScore) {
      bestItem = item;
      bestScore = score;
    }
  }

  return bestItem;
}
