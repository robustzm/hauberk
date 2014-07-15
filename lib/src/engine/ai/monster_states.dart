library hauberk.engine.ai.monster_states;

import 'dart:math' as math;

import '../../debug.dart';
import '../../util.dart';
import '../action_base.dart';
import '../breed.dart';
import '../game.dart';
import '../log.dart';
import '../los.dart';
import '../monster.dart';
import '../option.dart';
import 'a_star.dart';
import 'flow.dart';
import 'move.dart';

/// This defines the monster AI. AI is broken into a three level hierarchy.
///
/// The top sort-of level is the monster's "mood". This is a set of variables
/// that describe how the monster is "feeling". How afraid they are, how bored
/// they are, etc. These are the monster's senses and memory.
///
/// At the beginning of each turn, the monster uses these and some hysteresis
/// to determine it's *state*, which is how their mood manifests in behavior.
/// Where the "fear" mood fluctuates every turn, only when it reaches a high
/// enough point to trigger a transition to the "afraid" *state* does its
/// behavior change.
///
/// Most monsters the hero is interacting with are in the "awake" state.
/// Monsters off in the distances are usually asleep. Other states may be added
/// later: confused, blind, charmed, etc.
///
/// When awake, the monster has to decide what to do. It has a few options:
///
/// - It can perform a [Move], which are the "special" things different breeds
///   can do: teleportation, bolt attacks, etc.
/// - It can try to walk up to the hero and engage in melee combat.
/// - If it has a ranged attack move, it can try to get to a good vantage point
///   (not near the hero but still in range, with open LOS) and use a ranged
///   move.
///
/// Each move carries with it a little bit of logic to determine if it's a good
/// idea to use it. For example, the [HealMove] won't let itself be used if the
/// monster is at max health. In order to use a move, the monster must be
/// "recharged". Each move has a cost, and after using it, the monster must
/// recharge before another move can be performed. (Melee attacks have no cost.)
///
/// If a monster is recharged and does have a usable move, it will always prefer
/// to do that first. Once it's got no moves to do, it has to determine how it
/// wants to fight.
///
/// To choose between melee and ranged attacks, it decides how "cautious" it is.
/// The more damaging its ranged attacks are relative to melee, the more
/// cautious it is. Greater fear and lower health also make it more cautious.
/// If caution is above a threshold, the monster will prefer a ranged attack.
///
/// To get in position for that, it pathfinds to the nearest tile that's in
/// range and has an open line of sight to the hero. Checking for an open line
/// of sight obviously avoids friendly fire, but also makes monsters spread out
/// and flank the hero, which plays and looks cool.
///
/// Once it's on a good targeting tile, it will keep walking towards adjacent
/// tiles that are farther from the hero but still in range until it's fully
/// charged.
///
/// If it decides to go melee, it simply pathfinds to the hero and goes for it.
/// In either case, the end result is walking one tile (or possibly standing
/// in place.)

abstract class MonsterState {
  Monster _monster;

  void bind(Monster monster) {
    _monster = monster;
  }

  Monster get monster => _monster;
  Breed get breed => _monster.breed;
  Game get game => _monster.game;
  Vec get pos => _monster.pos;
  bool get isRecharged => _monster.isRecharged;
  bool get isVisible => _monster.isVisible;
  bool get canOpenDoors => _monster.canOpenDoors;

  void log(String message, [Noun noun1, Noun noun2, Noun noun3]) {
    monster.log(message, noun1, noun2, noun3);
  }

  void defend() {}
  Action getAction();

  void changeState(MonsterState state) {
    _monster.changeState(state);
  }

  Action getNextStateAction(MonsterState state) {
    _monster.changeState(state);
    return state.getAction();
  }
}

class AsleepState extends MonsterState {
  void defend() {
    // Don't sleep through a beating!
    Debug.logMonster(monster, "Wake on hit.");
    changeState(new AwakeState());
  }

  Action getAction() {
    var distance = (game.hero.pos - pos).kingLength;

    // TODO: Make this more cumulative over time. Getting in a drawn out fight
    // next to a monster should definitely wake it up, not subject to a large
    // number of random chances failing.

    // Don't wake up it very far away.
    if (distance > 30) {
      Debug.logMonster(monster, "Sleep: Distance $distance is too far to see.");
      return new RestAction();
    }

    // If the monster can see the hero, there's a good chance it will wake up.
    if (isVisible) {
      // TODO: Breed-specific sight/alertness.
      if (rng.oneIn(distance + 1)) {
        log('{1} notice[s] {2}!', monster, game.hero);
        Debug.logMonster(monster, "Sleep: In LOS, awoke.");
        return getNextStateAction(new AwakeState());
      }

      Debug.logMonster(monster,
      "Sleep: In LOS, failed oneIn(${distance + 1}).");
      return new RestAction();
    }

    if (distance > 20) {
      Debug.logMonster(monster,
      "Sleep: Distance $distance is too far to hear");
      return new RestAction();
    }

    // Otherwise, if sound can travel to it from the hero, it may wake up.
    // TODO: Breed-specific hearing.
    // Sound attenuates based on the inverse square of the distance.
    var flowDistance = game.stage.getHeroDistanceTo(pos);
    var noise = game.hero.lastNoise * 100 ~/ (flowDistance * flowDistance);

    if (noise > rng.range(500)) {
      game.log.message('Something stirs in the darkness.');
      Debug.logMonster(monster, "Sleep: Passed noise check, flow distance: "
      "$flowDistance, noise: $noise");
      return getNextStateAction(new AwakeState());
    }

    // Keep sleeping.
    Debug.logMonster(monster, "Sleep: Failed noise check, flow distance: "
    "$flowDistance, noise: $noise");
    return new RestAction();
  }
}

class AIChoice {
  final num score;
  final createAction;
  final description;

  AIChoice(this.score, this.description, this.createAction);

  String toString() => "$score - $description";
}

class AwakeState extends MonsterState {
  /// How many turns the monster has taken while awake since it last saw the
  /// hero. If it goes too long, it will eventually get bored and fall back
  /// asleep.
  int _turnsSinceLastSawHero = 0;

  Action getAction() {
    // See if things are quiet enough to fall asleep.
    if (isVisible) {
      _turnsSinceLastSawHero = 0;
    } else {
      _turnsSinceLastSawHero++;

      // The longer it goes without seeing the hero the more likely it will
      // fall asleep.
      if (_turnsSinceLastSawHero > rng.range(10, 20)) {
        Debug.logMonster(monster,
        "Haven't seen hero in $_turnsSinceLastSawHero, sleeping");
        return getNextStateAction(new AsleepState());
      }
    }

    // If there is a worthwhile move, use it.
    if (isRecharged) {
      var moves = breed.moves.where((move) => move.shouldUse(monster)).toList();
      if (moves.isNotEmpty) return rng.item(moves).getAction(monster);
    }

    // The monster doesn't have a move to use, so they are going to attack.
    // It needs to decide if it wants to do a ranged attack or a melee attack.
    var wantsToMelee = true;

    // First, it determines how "cautious" it is. Being more cautious makes the
    // monster prefer a ranged attack when possible.

    // Determine how much ranged damage it can dish out per turn.
    var rangedDamage = 0;
    var rangedAttacks = 0;

    for (var move in breed.moves) {
      // TODO: Handle other ranged damage moves.
      if (move is! BoltMove) continue;

      var movesPerTurn = Option.RECHARGE_RATE / move.cost;
      rangedDamage += move.attack.averageDamage * movesPerTurn;
      rangedAttacks++;

      // TODO: Take elements into account?
      // TODO: Smart monsters should take hero resists into account.
    }

    if (rangedAttacks != 0) {
      // Determine how much melee damage it can dish out per turn.
      var meleeDamage = 0;
      var meleeAttacks = 0;

      for (var attack in breed.attacks) {
        // Monsters don't have any raw ranged attacks, just ranged moves.
        assert(!attack.isRanged);
        meleeDamage += attack.averageDamage;
        meleeAttacks++;

        // TODO: Smart monsters should take hero resists into account.
      }

      if (meleeAttacks > 0) meleeDamage /= meleeAttacks;
      rangedDamage /= rangedAttacks;

      // The more damage a monster can do with ranged attacks, relative to its
      // melee attacks, the more cautious it is.
      var caution = 100 * rangedDamage / (rangedDamage + meleeDamage);

      // Being afraid makes the monster more cautious.
      caution += monster.fear;

      // Being close to death makes the monster more cautious.
      caution += 200 * (1 - monster.health.current / monster.health.max);

      // TODO: Breed-specific "aggression" modifier to caution.

      // Less likely to break away for a ranged attack if already in melee
      // distance.
      if (pos - game.hero.pos <= 1) {
        wantsToMelee = caution < 100;
      } else {
        wantsToMelee = caution < 50;
      }
    }

    // Now that we know what the monster *wants* to do, reconcile it with what
    // they're able to do.
    var meleePath = AStar.findPath(game.stage, pos, game.hero.pos,
        breed.tracking, canOpenDoors);

    var rangedDir;
    if (rangedAttacks > 0) rangedDir = _findRangedPath();

    var canMelee = meleePath.length > 0 &&
        game.stage.actorAt(pos + meleePath.direction) == null;
    var canRanged = rangedDir != null;

    var walkDir;
    if (wantsToMelee) {
      if (canMelee) {
        walkDir = meleePath.direction;
      } else {
        walkDir = rangedDir;
      }
    } else {
      if (canRanged) {
        walkDir = rangedDir;
      } else {
        walkDir = meleePath.direction;
      }
    }

    if (walkDir == null) walkDir = Direction.NONE;

    walkDir = _meander(walkDir);

    return new WalkAction(walkDir);
  }

  /// Applies the monster's meandering to [dir].
  Direction _meander(Direction dir) {
    var chance = 10;

    // Monsters are (mostly) smart enough to not meander when they're about to
    // melee. A small chance of meandering is still useful to get a monster out
    // of a doorway sometimes.
    if (pos + dir == game.hero.pos) chance = 50;

    if (breed.meander <= rng.range(chance)) return dir;

    var dirs;
    if (dir == Direction.NONE) {
      // Since the monster has no direction, any is equally valid.
      dirs = Direction.ALL;
    } else {
      dirs = [];

      // Otherwise, bias towards the direction the monster is headed.
      for (var i = 0; i < 3; i++) {
        dirs.add(dir.rotateLeft45);
        dirs.add(dir.rotateRight45);
      }

      for (var i = 0; i < 2; i++) {
        dirs.add(dir.rotateLeft90);
        dirs.add(dir.rotateRight90);
      }

      dirs.add(dir.rotateLeft90.rotateLeft45);
      dirs.add(dir.rotateRight90.rotateRight45);
      dirs.add(dir.rotate180);
    }

    dirs = dirs.where((dir) {
      var here = pos + dir;
      if (!monster.canOccupy(here)) return false;
      var actor = game.stage.actorAt(here);
      return actor == null || actor == game.hero;
    });

    if (dirs.isEmpty) return dir;
    return rng.item(dirs.toList());
  }

  /// Tries to find a path a desirable position for using a ranged [Move].
  ///
  /// Returns the [Direction] to take along the path. Returns [Direction.NONE]
  /// if the monster's current position is a good ranged spot. Returns `null`
  /// if no good ranged position could be found.
  Direction _findRangedPath() {
    var maxRange = breed.moves.fold(0,
        (max, move) => math.min(max, move.range));

    var flow = new Flow(game.stage, pos, maxDistance: maxRange,
        canOpenDoors: canOpenDoors);

    isValidRangedPosition(pos) {
      // Ignore tiles that are out of range.
      var toHero = pos - game.hero.pos;
      if (toHero > maxRange) return false;

      // TODO: Being near max range reduces damage. Should try to be within
      // max damage range.

      // Don't go point-blank.
      if (toHero.kingLength <= 2) return false;

      // Ignore occupied tiles.
      var actor = game.stage.actorAt(pos);
      if (actor != null && actor != monster) return false;

      // Ignore tiles that don't have a line-of-sight to the hero.
      return _hasLosFrom(pos);
    }

    // First, see if the current tile or any of its neighbors are good. Once in
    // a tolerable position, the monster will hill-climb to get into a local
    // optimal position (which basically means as far from the hero as possible
    // while still in range).
    var best;
    var bestDistance = 0;

    if (isValidRangedPosition(pos)) {
      best = Direction.NONE;
      // TODO: Need to decide whether ranged attacks use kingLength or Cartesian
      // and then apply consistently.
      bestDistance = (pos - game.hero.pos).lengthSquared;
    }

    for (var dir in Direction.ALL) {
      var pos = monster.pos + dir;
      if (!monster.canOccupy(pos)) continue;
      if (!isValidRangedPosition(pos)) continue;

      var distance = (pos - game.hero.pos).lengthSquared;
      if (distance > bestDistance) {
        best = dir;
        bestDistance = distance;
      }
    }

    if (best != null) return best;

    // Otherwise, we'll need to actually pathfind to reach a good vantage point.
    var dir = flow.directionToNearestWhere(isValidRangedPosition);
    if (dir != Direction.NONE) {
      Debug.logMonster(monster, "Ranged position $dir");
      return dir;
    }

    // If we get here, couldn't find to a ranged position at all. We may be
    // cornered, or the hero may be surrounded.
    Debug.logMonster(monster, "No good ranged position");
    return null;
  }

  Direction _findMeleePath() {
    // Melee attack if next to the hero.
    var toHero = game.hero.pos - pos;
    if (toHero.kingLength == 1) return toHero;

    // Try to pathfind towards the hero.
    return AStar.findDirection(game.stage, pos, game.hero.pos,
        breed.tracking, canOpenDoors);
  }

  /// Returns `true` if there is an open LOS from [from] to the hero.
  bool _hasLosFrom(Vec from) {
    for (var step in new Los(from, game.hero.pos)) {
      if (step == game.hero.pos) return true;
      if (!game.stage[step].isTransparent) return false;
      var actor = game.stage.actorAt(step);
      if (actor != null && actor != this) return false;
    }

    throw "unreachable";
  }
}

class AfraidState extends MonsterState {
  Action getAction() {
    // TODO: Should not walk past hero to get to escape!
    // TODO: What should it do once it's in shadow?
    // Find the nearest place the hero can't see.
    var flow = new Flow(game.stage, pos, maxDistance: breed.tracking,
        canOpenDoors: monster.canOpenDoors);
    var dir = flow.directionToNearestWhere((pos) => !game.stage[pos].visible);

    if (dir != Direction.NONE) {
      Debug.logMonster(monster, "Fleeing $dir to darkness");
      return new WalkAction(dir);
    }

    // If we couldn't find a hidden tile, at least try to get some distance.
    var heroDistance = (pos - game.hero.pos).kingLength;
    var farther = Direction.ALL.where((dir) {
      var here = pos + dir;
      if (!monster.canOccupy(here)) return false;
      if (game.stage.actorAt(here) != null) return false;
      return (here - game.hero.pos).kingLength > heroDistance;
    });

    if (farther.isNotEmpty) {
      dir = rng.item(farther.toList());
      Debug.logMonster(monster, "Fleeing $dir away from hero");
      return new WalkAction(dir);
    }

    // If we got here, we couldn't escape. Cornered!
    Debug.logMonster(monster, "Cornered!");
    return getNextStateAction(new AwakeState());
  }
}
