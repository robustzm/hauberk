import '../../../engine.dart';
import 'mastery.dart';

class Swordfighting extends MasteryDiscipline {
  static int _parryDefense(int level) => lerpInt(level, 1, 20, 1, 20);

  @override
  String get name => "Swordfighting";

  @override
  String get description =>
      "The most elegant tool for the most refined of martial arts.";

  @override
  String get weaponType => "sword";

  @override
  String levelDescription(int level) =>
      "${super.levelDescription(level)} Parrying increases dodge by "
      "${_parryDefense(level)}.";

  @override
  Defense? getDefense(Hero hero, int level) {
    var swords = hero.equipment.weapons
        .where((weapon) => weapon.type.weaponType == "sword")
        .length;

    // No parrying if not using a sword.
    if (swords == 0) return null;

    // Dual-wielding swords doubles the parry.
    return Defense(_parryDefense(level) * swords, "{1} parr[y|ies] {2}.");
  }
}
