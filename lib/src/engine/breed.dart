library dngn.engine.breed;

import '../util.dart';
import 'energy.dart';
import 'game.dart';
import 'hero.dart';
import 'item.dart';
import 'log.dart';
import 'melee.dart';
import 'move.dart';
import 'monster.dart';
import 'option.dart';

/// A single kind of [Monster] in the game.
class Breed implements Quantifiable {
  final Pronoun pronoun;
  String get name => singular;

  /// Untyped so the engine isn't coupled to how monsters appear.
  final appearance;

  final List<Attack> attacks;
  final List<Move>   moves;

  final int maxHealth;

  /// How much randomness the monster has when walking towards its target.
  final int meander;

  /// The breed's speed, relative to normal. Ranges from `-6` (slowest) to `6`
  /// (fastest) where `0` is normal speed.
  final int speed;

  /// The [Item]s this monster may drop when killed.
  final Drop drop;

  final Set<String> flags;

  /// The name of the breed. If the breed's name has irregular pluralization
  /// like "bunn[y|ies]", this will be the original unparsed string.
  final String _name;

  Breed(this._name, this.pronoun, this.appearance, this.attacks, this.moves,
      this.drop, {
      this.maxHealth, this.meander, this.speed, this.flags});

  String get singular =>
      Log.parsePlural(_name, isPlural: false, forcePlural: true);
  String get plural =>
      Log.parsePlural(_name, isPlural: true, forcePlural: true);

  /// How much experience a level one [Hero] gains for killing a [Monster] of
  /// this breed.
  int get experienceCents {
    // The more health it has, the longer it can hurt the hero.
    num exp = maxHealth;

    // Faster monsters are worth more.
    exp *= Energy.GAINS[Energy.NORMAL_SPEED + speed];

    // Average the attacks (since they are selected randomly) and factor them
    // in.
    var attackTotal = 0;
    for (final attack in attacks) {
      attackTotal += attack.damage;
    }
    exp *= attackTotal / attacks.length;

    // Take into account flags.
    for (final flag in flags) {
      exp *= Option.EXP_FLAG[flag];
    }

    // Meandering monsters are worth less.
    exp *= (Option.EXP_MEANDER - meander) / Option.EXP_MEANDER;

    // TODO(bob): Take into account moves.
    return exp.toInt();
  }

  /// When a [Monster] of this Breed is generated, how many of the same type
  /// should be spawned together (roughly).
  int get numberInGroup {
    if (flags.contains('horde')) return 18;
    if (flags.contains('swarm')) return 12;
    if (flags.contains('pack')) return 8;
    if (flags.contains('group')) return 4;
    if (flags.contains('few')) return 2;
    return 1;
  }

  Monster spawn(Game game, Vec pos) {
    return new Monster(game, this, pos.x, pos.y, maxHealth);
  }
}
