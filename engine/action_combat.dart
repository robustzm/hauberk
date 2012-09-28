/// [Action] for a melee attack from one [Actor] to another.
class AttackAction extends Action {
  final Actor defender;

  AttackAction(this.defender);

  ActionResult onPerform() {
    // Get all of the melee information from the participants.
    final attack = actor.getAttack(defender);
    return attack.perform(this, actor, defender);
  }

  int get noise() => Option.NOISE_HIT;

  String toString() => '$actor attacks $defender';
}

class BoltAction extends Action {
  final Iterator<Vec> los;
  final Attack attack;

  BoltAction(Vec from, Vec to, this.attack)
  : los = new Los(from, to).iterator();

  ActionResult onPerform() {
    final pos = los.next();

    // Stop if we hit a wall.
    if (!game.stage[pos].isTransparent) return succeed();

    addEvent(new Event.bolt(pos));

    // See if there is an actor there.
    final target = game.stage.actorAt(pos);
    if (target != null && target != actor) {
      return attack.perform(this, actor, target);
    }

    return los.hasNext() ? ActionResult.NOT_DONE : ActionResult.SUCCESS;
  }
}

