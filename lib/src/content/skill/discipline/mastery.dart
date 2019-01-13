import 'package:piecemeal/piecemeal.dart';

import '../../../engine.dart';

// TODO: More disciplines:
// - Dodging attacks, which increases dodge.
// - Fury. Increases damage when health is low. Trained by killing monsters
//   when near death.

abstract class MasteryDiscipline extends Discipline implements UsableSkill {
  // TODO: Tune.
  int get maxLevel => 20;

  String get weaponType;

  double _damageScale(int level) => lerpDouble(level, 1, maxLevel, 1.00, 2.0);

  void modifyAttack(Hero hero, Monster monster, Hit hit, int level) {
    if (!_hasWeapon(hero)) return;

    // TODO: Tune.
    hit.scaleDamage(_damageScale(level));
  }

  String levelDescription(int level) {
    var damage = ((_damageScale(level) - 1.0) * 100).toInt();
    return "Melee attacks inflict $damage% more damage when using a "
        "$weaponType.";
  }

  String unusableReason(Game game) {
    if (_hasWeapon(game.hero)) return null;

    return "No $weaponType equipped.";
  }

  bool _hasWeapon(Hero hero) =>
      hero.equipment.weapons.any((item) => item.type.weaponType == weaponType);

  void killMonster(Hero hero, Action action, Monster monster) {
    // Have to have killed the monster by hitting it.
    if (action is! AttackAction) return;

    if (!_hasWeapon(hero)) return;

    hero.skills.earnPoints(this, (monster.experience / 100).ceil());
    hero.refreshSkill(this);
  }

  int baseTrainingNeeded(int level) {
    if (level == 0) return 0;

    // Get the mastery and unlock the action as soon as it's first used.
    if (level == 1) return 1;

    // TODO: Tune.
    level--;
    return 100 * level * level * level;
  }
}

abstract class MasteryAction extends Action {
  final double damageScale;

  MasteryAction(this.damageScale);

  String get weaponType;

  /// Attempts to hit the [Actor] at [pos], if any.
  int attack(Vec pos) {
    var defender = game.stage.actorAt(pos);
    if (defender == null) return null;

    // If dual-wielding two weapons of the mastered type, both are used.
    var weapons = hero.equipment.weapons.toList();
    var hits = hero.createMeleeHits(defender);
    assert(weapons.length == hits.length);

    var damage = 0;
    for (var i = 0; i < weapons.length; i++) {
      if (weapons[i].type.weaponType != weaponType) continue;

      var hit = hits[i];
      hit.scaleDamage(damageScale);
      damage += hit.perform(this, actor, defender);

      if (!defender.isAlive) break;
    }

    return damage;
  }

  double get noise => Sound.attackNoise;
}
