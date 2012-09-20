/// Base class for a skill. A skill is a levelable hero ability in the game.
/// The actual concrete skills are defined in content.
class Skill {
  abstract String get name;
  abstract String getHelpText(int level);
  num getAttackAddBonus(int level, Item weapon, Attack attack) => 0;
  num getAttackMultiplyBonus(int level, Item weapon, Attack attack) => 0;
  int modifyHealth(int level) => 0;
  int getDropChance(int level) => 0;
}

/// The [Hero]'s levels in each skill.
class SkillSet {
  final Map<String, Skill> _skills;
  final Map<String, int> _levels;

  SkillSet(this._skills)
      : _levels = {};

  /// Gets the hero's level at [skill].
  int operator[](Skill skill) {
    int level = _levels[skill.name];
    return level == null ? 0 : level;
  }

  /// Sets the hero's level at [skill].
  operator[]=(Skill skill, int level) {
    _levels[skill.name] = level;
  }

  /// Applies [callback] to every skill in the set.
  void forEach(void callback(Skill skill, int level)) {
    for (final skill in _skills.getValues()) callback(skill, this[skill]);
  }
}