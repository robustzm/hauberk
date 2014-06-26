library dngn.engine.condition;

import 'action_base.dart';
import 'actor.dart';
import 'log.dart';

/// A temporary condition that modifies some property of an [Actor] while it
/// is in effect.
abstract class Condition {
  /// The [Actor] that this condition applies to.
  Actor get actor => _actor;
  Actor _actor;

  /// The number of turns that the condition while remain in effect for.
  int _turnsRemaining = 0;

  /// The "intensity" of this condition. The interpretation of this varies from
  /// condition to condition.
  int _intensity = 0;

  /// Gets whether the condition is currently in effect.
  bool get isActive => _turnsRemaining > 0;

  int get duration => _turnsRemaining;

  /// The condition's current intensity, or zero if not active.
  int get intensity => _intensity;

  /// Binds the condition to the actor that it applies to. Must be called and
  /// can only be called once.
  void bind(Actor actor) {
    assert(_actor == null);
    _actor = actor;
  }

  /// Processes one turn of the condition.
  void update(Action action) {
    if (isActive) {
      _turnsRemaining--;
      if (isActive) {
        onUpdate(action);
      } else {
        onDeactivate();
        _intensity = 0;
      }
    }
  }

  /// Extends the condition by [duration].
  void extend(int duration) {
    _turnsRemaining += duration;
  }

  /// Activates the condition for [duration] turns at [intensity].
  void activate(int duration, [int intensity = 1]) {
    _turnsRemaining = duration;
    _intensity = intensity;
  }

  /// Cancels the condition immediately. Does not deactivate the condition.
  void cancel() {
    _turnsRemaining = 0;
    _intensity = 0;
  }

  void onUpdate(Action action) {}

  void onDeactivate();
}

/// A condition that temporarily modifies the actor's speed.
class HasteCondition extends Condition {
  void onDeactivate() {
    if (intensity > 0) {
      actor.log("{1} slow[s] back down.", actor);
    } else {
      actor.log("{1} speed[s] back up.", actor);
    }
  }
}

/// A condition that slowly regenerates health.
class FoodCondition extends Condition {
  void onDeactivate() {
    actor.log("{1} [are|is] getting hungry.", actor);
  }
}

/// A condition that slowly regenerates health.
class PoisonCondition extends Condition {
  void onUpdate(Action action) {
    // TODO: Apply resistances. If resistance lowers intensity to zero, end
    // condition and log message.

    if (!actor.takeDamage(action, intensity, new Noun("the poison"))) {
      actor.log("{1} [are|is] hurt by poison!", actor);
    }
  }

  void onDeactivate() {
    actor.log("{1} [are|is] no longer poisoned.", actor);
  }
}
