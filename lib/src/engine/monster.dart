library hauberk.engine.monster;

import 'dart:math' as math;

import 'package:piecemeal/piecemeal.dart';

import '../debug.dart';
import 'action/action.dart';
import 'actor.dart';
import 'ai/monster_states.dart';
import 'ai/move.dart';
import 'breed.dart';
import 'energy.dart';
import 'game.dart';
import 'hero/hero.dart';
import 'log.dart';
import 'los.dart';
import 'melee.dart';

class Monster extends Actor {
  final Breed breed;

  /// The monster's generation.
  ///
  /// Monsters created directly in the level are one. Monsters that are spawned
  /// or summoned by another monster have a generation one greater than that
  /// monster.
  ///
  /// When a monster spawns another, its generation increases too so that it
  /// also spawns less frequently over time.
  int generation;

  MonsterState _state;

  /// After performing a [Move] a monster must recharge to limit the rate that
  /// it can be performed. This tracks how much recharging is left to do for
  /// each move.
  ///
  /// When a move is performed, its rate is added to this. It then reduces over
  /// time. When it reaches zero, the move can be performed again.
  final _recharges = <Move, num>{};

  bool get isAfraid => _state is AfraidState;

  bool get isAsleep => _state is AsleepState;

  /// How afraid of the hero the monster currently is. If it gets high enough,
  /// the monster will switch to the afraid state and try to flee.
  double _fear = 0.0;

  /// The fear level that will cause the monster to become frightened.
  double _frightenThreshold;

  double get fear => _fear;

  get appearance => breed.appearance;

  String get nounText => 'the ${breed.name}';
  Pronoun get pronoun => breed.pronoun;

  /// How much experience a level one [Hero] gains for killing this monster.
  int get experienceCents => breed.experienceCents;

  Monster(Game game, this.breed, int x, int y, int maxHealth, this.generation)
      : super(game, x, y, maxHealth) {
    Debug.addMonster(this);
    changeState(new AsleepState());


    /// Give this some random variation within monsters of the same breed so
    /// they don't all become frightened at the same time.
    _frightenThreshold = rng.range(60, 200).toDouble();
    if (breed.flags.contains("cowardly")) _frightenThreshold *= 0.7;

    // All moves are initially charged.
    for (var move in breed.moves) {
      _recharges[move] = 0.0;
    }
  }

  void useMove(Move move) {
    // Add some randomness to the rate. Since monsters very eagerly prefer to
    // use moves, this ensures they don't use them too predictably.
    _recharges[move] += rng.range(move.rate, move.rate * 2);
  }

  /// Returns `true` if [move] is recharged.
  bool canUse(Move move) => _recharges[move] == 0;

  /// Gets whether or not this monster has a line of sight to [target].
  ///
  /// Does not take into account if there are other [Actor]s between the monster
  /// and the target.
  bool canView(Vec target) {
    // Walk to the target.
    for (final step in new Los(pos, target)) {
      if (step == target) return true;
      if (!game.stage[step].isTransparent) return false;
    }

    throw 'unreachable';
  }

  /// Gets whether or not this monster has a line of sight to [target].
  ///
  /// Does take into account if there are other [Actor]s between the monster
  /// and the target.
  bool canTarget(Vec target) {
    // Walk to the target.
    for (final step in new Los(pos, target)) {
      if (step == target) return true;
      if (game.stage.actorAt(step) != null) return false;
      if (!game.stage[step].isTransparent) return false;
    }

    throw 'unreachable';
  }

  bool get canOpenDoors => breed.flags.contains('open-doors');

  int onGetSpeed() => Energy.NORMAL_SPEED + breed.speed;

  Action onGetAction() {
    // Recharge moves.
    for (var move in breed.moves) {
      _recharges[move] = math.max(0.0, _recharges[move] - 1.0);
    }

    return _state.getAction();
  }

  /// Modifies fear and then determines if it's has crossed the threshold to
  /// cause a state change.
  void _modifyFear(Action action, double offset) {
    // Don't add effects if the monster already died.
    if (!isAlive) return;

    if (breed.flags.contains("fearless")) return;

    // If it can't run, there's no point in being afraid.
    if (breed.flags.contains("immobile")) return;

    _fear = math.max(0.0, _fear + offset);

    if (_state is AwakeState && _fear > _frightenThreshold) {
      // Clamp the fear. This is mainly to ensure that a bunch of monsters
      // don't all get over their fear at the exact same time later. Since the
      // threshold is randomized, this will make the delay before growing
      // courageous random too.
      _fear = _frightenThreshold;

      log("{1} is afraid!", this);
      changeState(new AfraidState());
      action.addEvent(new Event(EventType.FEAR, actor: this));
      return;
    }

    if (_state is AfraidState && _fear <= 0.0) {
      log("{1} grows courageous!", this);
      changeState(new AwakeState());
      action.addEvent(new Event(EventType.COURAGE, actor: this));
    }
  }

  /// Changes the monster to its awake state if sleeping.
  void wakeUp() {
    if (_state is! AsleepState) return;
    changeState(new AwakeState());
  }

  void changeState(MonsterState state) {
    _state = state;
    _state.bind(this);
  }

  Attack onGetAttack(Actor defender) => rng.item(breed.attacks);

  Attack defend(Attack attack) {
    _state.defend();

    // TODO: Breed-specific resists.
    return super.defend(attack);
  }

  /// Inflicting damage decreases fear.
  void onDamage(Action action, Actor defender, int damage) {
    // The greater the power of the hit, the more emboldening it is.
    var fear = 100.0 * damage / game.hero.health.max;

    _modifyFear(action, -fear);
    Debug.logMonster(this, "Hit for ${damage} / ${game.hero.health.max} "
        "decreases fear by ${fear} to $_fear");

    // Nearby monsters may witness it.
    _updateWitnesses((witness) {
      witness._viewHeroDamage(action, damage);
    });
  }

  /// This is called when another monster in sight of this one has damaged the
  /// hero.
  void _viewHeroDamage(Action action, int damage) {
    var fear = 50.0 * damage / health.max;

    _modifyFear(action, -fear);
    Debug.logMonster(this, "Witness ${damage} / ${health.max} "
        "decreases fear by ${fear} to $_fear");
  }

  /// Taking damage increases fear.
  void onDamaged(Action action, Actor attacker, int damage) {
    // The greater the power of the hit, the more frightening it is.
    var fear = 100.0 * damage / health.max;

    // Getting hurt enrages it.
    if (breed.flags.contains("berzerk")) fear *= -3.0;

    _modifyFear(action, fear);
    Debug.logMonster(this, "Hit for ${damage} / ${health.max} "
        "increases fear by ${fear} to $_fear");

    // Nearby monsters may witness it.
    _updateWitnesses((witness) {
      witness._viewMonsterDamage(action, this, damage);
    });
  }

  /// This is called when another monster in sight of this one has taken
  /// damage.
  void _viewMonsterDamage(Action action, Monster monster, int damage) {
    var fear = 50.0 * damage / health.max;

    if (breed.flags.contains("protective") && monster.breed == breed) {
      // Seeing its own kind get hurt enrages it.
      fear *= -2.0;
    } else if (breed.flags.contains("berzerk")) {
      // Seeing any monster get hurt enrages it.
      fear *= -1.0;
    }

    _modifyFear(action, fear);
    Debug.logMonster(this, "Witness ${damage} / ${health.max} "
        "increases fear by ${fear} to $_fear");
  }

  /// Called when this Actor has been killed by [attacker].
  void onDied(Actor attacker) {
    // Handle drops.
    breed.drop.spawnDrop((item) {
      item.pos = pos;
      // TODO: Scatter items a bit?
      log("{1} drop[s] {2}.", this, item);
      game.stage.items.add(item);
    });

    // Tell the quest.
    game.quest.killMonster(game, this);

    game.stage.removeActor(this);
    Debug.removeMonster(this);
  }

  void onFinishTurn(Action action) {
    _decayFear(action);
  }

  void changePosition(Vec from, Vec to) {
    super.changePosition(from, to);

    // If the monster is (or was) visible, don't let the hero rest through it
    // moving.
    if (game.stage[from].visible || game.stage[to].visible) {
      game.hero.disturb();
    }
  }

  /// Invokes [callback] on all nearby monsters that can see this one.
  void _updateWitnesses(callback(Monster monster)) {
    for (var other in game.stage.actors) {
      if (other == this) continue;
      if (other is! Monster) continue;
      if (other._state is AsleepState) continue;

      var distance = (other.pos - pos).kingLength;
      if (distance > 20) continue;

      if (other.canView(pos)) callback(other);
    }
  }

  /// Fear decays over time, more quickly the farther the monster is from the
  /// hero.
  void _decayFear(Action action) {
    // TODO: Poison should slow the decay of fear.
    var fearDecay = 5.0 + (pos - game.hero.pos).kingLength;

    // Fear decays more quickly if out of sight.
    if (!isVisible) fearDecay = 5.0 + fearDecay * 2.0;

    // The closer the monster is to death, the less quickly it gets over fear.
    fearDecay = 2.0 + fearDecay * health.current / health.max;

    _modifyFear(action, -fearDecay);
    Debug.logMonster(this, "Decay fear by $fearDecay to $_fear");
  }
}
