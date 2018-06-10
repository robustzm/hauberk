import 'package:piecemeal/piecemeal.dart';

import '../action/action.dart';
import 'combat.dart';

class Element {
  static final none = new Element("none", "No", 1.0);

  final String name;
  final String abbreviation;

  /// Whether this element emanates light when a substance on the ground.
  final bool emanates;

  /// The multiplier to a experience gained when killing a monster with a move
  /// or attack using this element.
  final double experience;

  String get capitalized => "${name[0].toUpperCase()}${name.substring(1)}";

  /// Creates a side-effect action to perform when an [Attack] of this element
  /// hits an actor for [damage] or `null` if this element has no side effect.
  final Action Function(int damage) attackAction;

  /// Creates a side-effect action to perform when an area attack of this
  /// element hits a tile or `null` if this element has no effect.
  final Action Function(Vec pos, Hit hit, num distance) floorAction;

  Element(this.name, this.abbreviation, this.experience,
      {bool emanates,
      Action Function(int damage) attack,
      Action Function(Vec pos, Hit hit, num distance) floor})
      : emanates = emanates ?? false,
        attackAction = attack ?? ((_) => null),
        floorAction = floor ?? ((_, __, ___) => null);

  String toString() => name;
}
