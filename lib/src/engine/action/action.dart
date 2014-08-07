library hauberk.engine.action.action;

import 'dart:collection';

import '../actor.dart';
import '../game.dart';
import '../hero/hero.dart';
import '../log.dart';
import '../monster.dart';
import '../option.dart';

abstract class Action {
  Actor _actor;
  Game _game;
  Queue<Action> _actions;
  GameResult _gameResult;
  bool _consumesEnergy;

  Game get game => _game;
  Actor get actor => _actor;
  Monster get monster => _actor as Monster;
  Hero get hero => _actor as Hero;
  bool get consumesEnergy => _consumesEnergy;

  void bind(Actor actor, bool consumesEnergy) {
    assert(_actor == null);

    _actor = actor;
    _game = actor.game;
    _consumesEnergy = consumesEnergy;
  }

  ActionResult perform(Queue<Action> actions, GameResult gameResult) {
    assert(_actor != null); // Action should be bound already.

    _actions = actions;
    _gameResult = gameResult;
    return onPerform();
  }

  ActionResult onPerform();

  /// Enqueue a secondary action that is a consequence of this one.
  void addAction(Action action, [Actor actor]) {
    action.bind(actor == null ? _actor : actor, false);
    _actions.add(action);
  }

  void addEvent(Event event) {
    _gameResult.events.add(event);
  }

  /// How much noise is produced by this action. Override to make certain
  /// actions quieter or louder.
  int get noise => Option.NOISE_NORMAL;

  void error(String message, [Noun noun1, Noun noun2, Noun noun3]) {
    if (!_actor.isVisible) return;
    _game.log.error(message, noun1, noun2, noun3);
  }

  void log(String message, [Noun noun1, Noun noun2, Noun noun3]) {
    if (!_actor.isVisible) return;
    _game.log.message(message, noun1, noun2, noun3);
  }

  ActionResult succeed([String message, Noun noun1, Noun noun2, Noun noun3]) {
    if (message != null) log(message, noun1, noun2, noun3);
    return ActionResult.SUCCESS;
  }

  ActionResult fail([String message, Noun noun1, Noun noun2, Noun noun3]) {
    if (message != null) error(message, noun1, noun2, noun3);
    return ActionResult.FAILURE;
  }

  ActionResult alternate(Action action) {
    action.bind(_actor, _consumesEnergy);
    return new ActionResult.alternate(action);
  }
}

class ActionResult {
  static final SUCCESS = const ActionResult(succeeded: true, done: true);
  static final FAILURE = const ActionResult(succeeded: false, done: true);
  static final NOT_DONE = const ActionResult(succeeded: true, done: false);

  /// An alternate [Action] that should be performed instead of the one that
  /// failed to perform and returned this. For example, when the [Hero] walks
  /// into a closed door, the [WalkAction] will fail (the door is closed) and
  /// return an alternate [OpenDoorAction] instead.
  final Action alternative;

  /// `true` if the [Action] was successful and energy should be consumed.
  final bool succeeded;

  /// `true` if the [Action] does not need any further processing.
  final bool done;

  const ActionResult({this.succeeded, this.done})
  : alternative = null;

  const ActionResult.alternate(this.alternative)
  : succeeded = false,
    done = true;
}
