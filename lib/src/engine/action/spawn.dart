library hauberk.engine.action.spawn;

import 'package:piecemeal/piecemeal.dart';

import 'action.dart';
import '../breed.dart';
import '../game.dart';
import '../monster.dart';

/// Spawns a new [Monster] of a given [Breed].
class SpawnAction extends Action {
  final Vec _pos;
  final Breed _breed;

  SpawnAction(this._pos, this._breed);

  ActionResult onPerform() {
    // There's a chance the move will do nothing (except burn charge) based on
    // the monster's generation. This is to keep breeders from filling the
    // dungeon.
    if (!rng.oneIn(monster.generation)) return ActionResult.SUCCESS;

    // Increase the generation on the spawner too so that its rate decreases
    // over time.
    monster.generation++;

    var spawned = _breed.spawn(game, _pos, actor);
    game.stage.addActor(spawned);

    addEvent(new Event(EventType.SPAWN, actor: spawned));

    // TODO: Message?
    return ActionResult.SUCCESS;
  }
}
