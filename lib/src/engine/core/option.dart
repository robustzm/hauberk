// TODO: Should this be in content?
/// This contains all of the tunable game engine parameters. Tweaking these can
/// massively affect all aspects of gameplay.
class Option {
  static const maxDepth = 100;

  static const skillPointsPerLevel = 3;

  /// How much damage an unarmed hero does.
  static const heroPunchDamage = 3;

  /// The amount of gold a new hero starts with.
  static const heroGoldStart = 60;

  static const heroMaxStomach = 400;

  /// The maximum number of items the hero's inventory can contain.
  static const inventoryCapacity = 24;

  /// The maximum number of items the hero's home inventory can contain.
  /// Note: To make this is more than 26, the home screen UI will need to be
  /// changed.
  static const homeCapacity = 26;

  /// The maximum number of items the hero's crucible can contain.
  static const crucibleCapacity = 8;
}
