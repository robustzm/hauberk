library hauberk.engine.move;

import 'package:piecemeal/piecemeal.dart';

import '../../debug.dart';
import '../action/action.dart';
import '../action/attack.dart';
import '../action/bolt.dart';
import '../action/condition.dart';
import '../action/cone.dart';
import '../action/heal.dart';
import '../action/spawn.dart';
import '../action/teleport.dart';
import '../melee.dart';
import '../monster.dart';

/// A [Move] is an action that a [Monster] can perform aside from the basic
/// walking and melee attack actions. Moves include things like spells, breaths,
/// and missiles.
abstract class Move {
  /// The frequency at which the monster can perform this move (with some
  /// randomness added in).
  ///
  /// A rate of 1 means the monster can perform the move roughly every turn.
  /// A rate of 10 means it can perform it about one in ten turns. Fractional
  /// rates are allowed.
  final num rate;

  /// The range of this move if it's a ranged one, or `0` otherwise.
  int get range => 0;

  Move(this.rate);

  /// Returns `true` if the monster would reasonably perform this move right
  /// now.
  bool shouldUse(Monster monster) => true;

  /// Called when the [Monster] has selected this move. Returns an [Action] that
  /// performs the move.
  Action getAction(Monster monster) {
    monster.useMove(this);
    return onGetAction(monster);
  }

  /// Create the [Action] to perform this move.
  Action onGetAction(Monster monster);
}

class BoltMove extends Move {
  final Attack attack;

  int get range => attack.range;

  BoltMove(num rate, this.attack)
    : super(rate);

  bool shouldUse(Monster monster) {
    var target = monster.game.hero.pos;

    // Don't fire if out of range.
    var toTarget = target - monster.pos;
    if (toTarget > range) {
      Debug.logMonster(monster, "Bolt move too far.");
      return false;
    }
    if (toTarget < 1.5) {
      Debug.logMonster(monster, "Bolt move too close.");
      return false;
    }

    // Don't fire a bolt if it's obstructed.
    if (!monster.canTarget(target)) {
      Debug.logMonster(monster, "Bolt move can't target.");
      return false;
    }

    Debug.logMonster(monster, "Bolt move OK.");
    return true;
  }

  Action onGetAction(Monster monster) {
    return new BoltAction(monster.pos, monster.game.hero.pos, attack);
  }

  String toString() => "Bolt $attack rate: $rate";
}

class ConeMove extends Move {  final Attack attack;
  int get range => attack.range;

  ConeMove(num rate, this.attack)
    : super(rate);

  bool shouldUse(Monster monster) {
    var target = monster.game.hero.pos;

    // Don't fire if out of range.
    var toTarget = target - monster.pos;
    if (toTarget > range) {
      Debug.logMonster(monster, "Cone move too far.");
      return false;
    }

    // TODO: Should minimize friendly fire.
    if (!monster.canView(target)) {
      Debug.logMonster(monster, "Cone move can't target.");
      return false;
    }

    Debug.logMonster(monster, "Cone move OK.");
    return true;
  }

  Action onGetAction(Monster monster) {
    return new ConeAction(monster.pos, monster.game.hero.pos, attack);
  }

  String toString() => "Cone $attack rate: $rate";
}

class HealMove extends Move {
  /// How much health to restore.
  final int _amount;

  HealMove(num rate, this._amount) : super(rate);

  bool shouldUse(Monster monster) {
    // Heal if it could heal the full amount, or it's getting close to death.
    return (monster.health.current / monster.health.max < 0.25) ||
           (monster.health.max - monster.health.current >= _amount);
  }

  Action onGetAction(Monster monster) {
    return new HealAction(_amount);
  }

  String toString() => "Heal $_amount rate: $rate";
}

class InsultMove extends Move {
  InsultMove(num rate) : super(rate);

  bool get isRanged => true;

  bool shouldUse(Monster monster) {
    var target = monster.game.hero.pos;
    var distance = (target - monster.pos).kingLength;

    // Don't insult when in melee distance.
    if (distance <= 1) return false;

    // Don't insult someone it can't see.
    return monster.canView(target);
  }

  Action onGetAction(Monster monster) => new InsultAction(monster.game.hero);

  String toString() => "Insult rate: $rate";
}

class HasteMove extends Move {
  final int _duration;
  final int _speed;

  HasteMove(num rate, this._duration, this._speed) : super(rate);

  bool shouldUse(Monster monster) {
    // Don't use if already hasted.
    return !monster.haste.isActive;
  }

  Action onGetAction(Monster monster) => new HasteAction(_duration, _speed);

  String toString() => "Haste $_speed for $_duration turns rate: $rate";
}

/// Teleports the [Monster] randomly from its current position.
class TeleportMove extends Move {
  final int _range;

  TeleportMove(int cost, this._range) : super(cost);

  Action onGetAction(Monster monster) => new TeleportAction(_range);
}

/// Spawns a new [Monster] of the same [Breed] adjacent to this one.
class SpawnMove extends Move {
  SpawnMove(num rate) : super(rate);

  bool shouldUse(Monster monster) {
    // Look for an open adjacent tile.
    for (var dir in Direction.ALL) {
      var here = monster.pos + dir;
      if (monster.game.stage[here].isPassable &&
          monster.game.stage.actorAt(here) == null) return true;
    }

    return false;
  }

  Action onGetAction(Monster monster) {
    // Pick an open adjacent tile.
    var dirs = Direction.ALL.where((dir) {
      var here = monster.pos + dir;
      return monster.game.stage[here].isPassable &&
          monster.game.stage.actorAt(here) == null;
    }).toList();

    return new SpawnAction(monster.pos + rng.item(dirs), monster.breed);
  }
}
