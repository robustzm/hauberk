
class GameScreen extends Screen {
  final HeroSave save;
  final Game     game;
  List<Effect>   effects;
  bool           logOnTop = false;

  /// The currently targeted actor, if any.
  // TODO(bob): Need to handle target moving out of visibility. Should not
  // forget target: if the monster becomes visible again, it should remain
  // targeted. But if the user opens the target dialog or does "target last"
  // while the target is invisible, it should treat it as not being targeted.
  Actor target;

  /// The most recently used skill.
  Skill lastSkill;

  GameScreen(this.save, this.game)
  : effects = <Effect>[];

  bool handleInput(Keyboard keyboard) {
    var action;

    if (keyboard.shift && !keyboard.control && !keyboard.option) {
      switch (keyboard.lastPressed) {
      case KeyCode.F:
        ui.push(new ForfeitDialog(game));
        break;

      case KeyCode.L:
        game.hero.rest();
        break;

      case KeyCode.I:
        game.hero.run(Direction.NW);
        break;

      case KeyCode.O:
        game.hero.run(Direction.N);
        break;

      case KeyCode.P:
        game.hero.run(Direction.NE);
        break;

      case KeyCode.K:
        game.hero.run(Direction.W);
        break;

      case KeyCode.SEMICOLON:
        game.hero.run(Direction.E);
        break;

      case KeyCode.COMMA:
        game.hero.run(Direction.SW);
        break;

      case KeyCode.PERIOD:
        game.hero.run(Direction.S);
        break;

      case KeyCode.SLASH:
        game.hero.run(Direction.SE);
        break;
      }
    } else if (!keyboard.control && !keyboard.option) {
      switch (keyboard.lastPressed) {
      case KeyCode.Q:
        if (game.isQuestComplete) {
          save.copyFrom(game.hero);
          ui.pop(true);
        } else {
          game.log.add('You have not completed your quest yet.');
          dirty();
        }
        break;

      case KeyCode.C:
        closeDoor();
        break;

      case KeyCode.D:
        ui.push(new InventoryDialog(game, InventoryMode.DROP));
        break;

      case KeyCode.U:
        ui.push(new InventoryDialog(game, InventoryMode.USE));
        break;

      case KeyCode.G:
        action = new PickUpAction();
        break;

      case KeyCode.I:
        action = new WalkAction(Direction.NW);
        break;

      case KeyCode.O:
        action = new WalkAction(Direction.N);
        break;

      case KeyCode.P:
        action = new WalkAction(Direction.NE);
        break;

      case KeyCode.K:
        action = new WalkAction(Direction.W);
        break;

      case KeyCode.L:
        action = new WalkAction(Direction.NONE);
        break;

      case KeyCode.SEMICOLON:
        action = new WalkAction(Direction.E);
        break;

      case KeyCode.COMMA:
        action = new WalkAction(Direction.SW);
        break;

      case KeyCode.PERIOD:
        action = new WalkAction(Direction.S);
        break;

      case KeyCode.SLASH:
        action = new WalkAction(Direction.SE);
        break;

      case KeyCode.S:
        ui.push(new SelectSkillDialog(game));
        break;
      }
    } else if (!keyboard.shift && keyboard.option && !keyboard.control) {
      switch (keyboard.lastPressed) {
      case KeyCode.I:
        fireAt(game.hero.pos + Direction.NW);
        break;

      case KeyCode.O:
        fireAt(game.hero.pos + Direction.N);
        break;

      case KeyCode.P:
        fireAt(game.hero.pos + Direction.NE);
        break;

      case KeyCode.K:
        fireAt(game.hero.pos + Direction.W);
        break;

      case KeyCode.L:
        if (lastSkill == null) {
          // Haven't picked a skill yet, so select one.
          ui.push(new SelectSkillDialog(game));
        } else if (lastSkill.needsTarget) {
          // If we still have a visible target, use it.
          if (target != null && target.isAlive &&
              game.stage[target.pos].visible) {
            fireAt(target.pos);
          } else {
            // No current target, so ask for one.
            ui.push(new TargetDialog(this, game));
          }
        } else {
          useLastSkill(null);
        }
        break;

      case KeyCode.SEMICOLON:
        fireAt(game.hero.pos + Direction.E);
        break;

      case KeyCode.COMMA:
        fireAt(game.hero.pos + Direction.SW);
        break;

      case KeyCode.PERIOD:
        fireAt(game.hero.pos + Direction.S);
        break;

      case KeyCode.SLASH:
        fireAt(game.hero.pos + Direction.SE);
        break;
      }
    }

    if (action != null) {
      game.hero.setNextAction(action);
    }

    return true;
  }

  void closeDoor() {
    // See how many adjacent open doors there are.
    final doors = [];
    for (final direction in Direction.ALL) {
      final pos = game.hero.pos + direction;
      if (game.stage[pos].type.closesTo != null) {
        doors.add(pos);
      }
    }

    if (doors.length == 0) {
      game.log.add('You are not next to an open door.');
      dirty();
    } else if (doors.length == 1) {
      game.hero.setNextAction(new CloseDoorAction(doors[0]));
    } else {
      ui.push(new CloseDoorDialog(game));
    }
  }

  void fireAt(Vec pos) {
    if (lastSkill == null || !lastSkill.needsTarget) return;

    // If we aren't firing at the current target, see if there is a monster
    // in that direction that we can target. (In other words, if you fire in
    // a raw direction, target the monster in that direction for subsequent
    // shots).
    if (target == null || target.pos != pos) {
      for (var step in new Los(game.hero.pos, pos)) {
        // Stop if we hit a wall.
        if (!game.stage[step].isTransparent) break;

        // See if there is an actor there.
        final actor = game.stage.actorAt(step);
        if (actor != null) {
          target = actor;
          break;
        }
      }
    }

    useLastSkill(target.pos);
  }

  void useLastSkill(Vec target) {
    game.hero.setNextAction(
        lastSkill.getUseAction(game.hero.skills[lastSkill], game, target));
  }

  void activate(Screen popped, result) {
    if (popped is ForfeitDialog && result) {
      // Forfeiting, so exit.
      ui.pop(false);
    } else if (popped is SelectSkillDialog && result is Skill) {
      lastSkill = result;

      if (result.needsTarget) {
        ui.push(new TargetDialog(this, game));
      } else {
        useLastSkill(null);
      }
    } else if (popped is TargetDialog && result) {
      fireAt(target.pos);
    }
  }

  void update() {
    if (effects.length > 0) dirty();

    var result = game.update();

    // TODO(bob): Hack temp.
    if (game.hero.health.current == 0) {
      // TODO(bob): Should it save the game here?
      ui.pop(false);
      return;
    }

    for (final event in result.events) {
      // TODO(bob): Handle other event types.
      switch (event.type) {
        case EventType.BOLT:
          effects.add(new FrameEffect(event.value, '*',
              getColorForElement(event.element)));
          break;

        case EventType.HIT:
          effects.add(new HitEffect(event.actor));
          break;

        case EventType.KILL:
          effects.add(new HitEffect(event.actor));
          // TODO(bob): Make number of particles vary based on monster health.
          _spawnParticles(10, event.actor.pos, Color.RED);
          break;

        case EventType.HEAL:
          effects.add(new HealEffect(event.actor.pos.x, event.actor.pos.y));
          break;
      }
    }

    if (result.needsRefresh) dirty();

    effects = effects.filter((effect) => effect.update(game));
  }

  void render(Terminal terminal) {
    final black = new Glyph(' ');

    // TODO(bob): Hack. Clear out the help text from the previous screen.
    terminal.rect(0, terminal.height - 1, terminal.width, 1).clear();

    // Draw the stage.
    for (int y = 0; y < game.stage.height; y++) {
      for (int x = 0; x < game.stage.width; x++) {
        final tile = game.stage.get(x, y);
        var glyph;
        if (tile.isExplored) {
          glyph = tile.type.appearance[tile.visible ? 0 : 1];
        } else {
          glyph = black;
        }

        /*
        glyph = debugScent(x, y, tile, glyph);
        */

        terminal.writeAt(x, y, glyph.char, glyph.fore, glyph.back);
      }
    }

    // TODO(bob): Temp. Test A*.
    /*
    terminal.writeAt(40, 20, '!', Color.AQUA);
    final aStar = AStar.findPath(game.level, game.hero.pos, new Vec(40, 20), 15);
    if (aStar != null) {
      for (final pos in aStar.closed) {
        terminal.writeAt(pos.x, pos.y, '-', Color.RED);
      }
      for (final path in aStar.open) {
        terminal.writeAt(path.pos.x, path.pos.y, '?', Color.BLUE);
      }

      var path = aStar.path;
      while (path != null) {
        terminal.writeAt(path.pos.x, path.pos.y, '@', Color.ORANGE);
        path = path.parent;
      }
    }

    final d = AStar.findDirection(game.level, game.hero.pos, new Vec(40, 20), 15);
    final p = game.hero.pos + d;
    terminal.writeAt(p.x, p.y, '0', Color.YELLOW);
    */

    // Draw the items.
    for (final item in game.stage.items) {
      if (!game.stage[item.pos].isExplored) continue;
      terminal.drawGlyph(item.x, item.y, item.appearance);
    }

    var visibleMonsters = [];

    // Draw the actors.
    for (final actor in game.stage.actors) {
      if (!game.stage[actor.pos].visible) continue;
      final appearance = actor.appearance;
      var glyph = (appearance is Glyph) ? appearance : new Glyph('@', Color.WHITE);

      if (target == actor) {
        glyph = new Glyph(glyph.char, glyph.back, glyph.fore);
      }

      terminal.drawGlyph(actor.x, actor.y, glyph);

      if (actor is Monster) visibleMonsters.add(actor);
    }

    // Draw the effects.
    for (final effect in effects) {
      effect.render(terminal);
    }

    // Draw the log.
    var hero = game.hero;

    // If the log is overlapping the hero, flip it to the other side. Use 0.4
    // and 0.6 here to avoid flipping too much if the hero is wandering around
    // near the middle.
    if (logOnTop) {
      if (hero.y < terminal.height * 0.4) logOnTop = false;
    } else {
      if (hero.y > terminal.height * 0.6) logOnTop = true;
    }

    // Force the log to the bottom if a popup is open so it's still visible.
    if (!isTopScreen) logOnTop = false;

    var y = logOnTop ? 0 : terminal.height - game.log.messages.length;

    for (final message in game.log.messages) {
      terminal.writeAt(0, y, message.text);
      if (message.count > 1) {
        terminal.writeAt(message.text.length, y, ' (x${message.count})',
          Color.GRAY);
      }
      y++;
    }

    drawStat(terminal, 0, 'Health', hero.health.current, Color.RED,
        hero.health.max, Color.DARK_RED);

    drawStat(terminal, 1, 'Level', hero.level, Color.BLUE);
    // TODO(bob): Handle hero at max level.
    drawStat(terminal, 2, 'Exp', hero.experience, Color.AQUA,
        calculateLevelCost(hero.level + 1), Color.DARK_AQUA);
    drawStat(terminal, 3, 'Armor',
        '${(100 - getArmorMultiplier(hero.armor) * 100).toInt()}% ',
        Color.GREEN);
    drawStat(terminal, 4, 'Weapon', hero.getAttack(null).damage, Color.YELLOW);

    terminal.writeAt(81, 18, '@ hero', Color.WHITE);
    drawHealthBar(terminal, 19, hero);

    // Draw the nearby monsters.
    visibleMonsters.sort((a, b) {
      var aDistance = (a.pos - game.hero.pos).lengthSquared;
      var bDistance = (b.pos - game.hero.pos).lengthSquared;
      return aDistance.compareTo(bDistance);
    });

    for (var i = 0; i < 10; i++) {
      var y = 20 + i * 2;
      terminal.writeAt(81, y, '                    ');
      terminal.writeAt(81, y + 1, '                    ');

      if (i < visibleMonsters.length) {
        var monster = visibleMonsters[i];

        var glyph = monster.appearance;
        if (target == monster) {
          glyph = new Glyph(glyph.char, glyph.back, glyph.fore);
        }

        terminal.drawGlyph(81, y, glyph);
        terminal.writeAt(83, y, monster.breed.name,
            (target == monster) ? Color.YELLOW : Color.WHITE);

        drawHealthBar(terminal, y + 1, monster);
      }
    }
  }

  void drawStat(Terminal terminal, int y, String label, value,
      Color valueColor, [max, Color maxColor]) {
    terminal.writeAt(81, y, label, Color.GRAY);
    var valueString = value.toString();
    terminal.writeAt(88, y, valueString, valueColor);

    if (max != null) {
      terminal.writeAt(88 + valueString.length, y, ' / $max', maxColor);
    }
  }

  void drawHealthBar(Terminal terminal, int y, Actor actor) {
    var barWidth = 8 * actor.health.current ~/ actor.health.max;

    // Don't round down to an entirely empty bar.
    if (barWidth == 0) barWidth = 1;

    for (var x = 0; x < 8; x++) {
      var full = x < barWidth;
      terminal.writeAt(92 + x, y, full ? '|' : '•',
          full ? Color.RED : Color.DARK_RED);
    }
  }

  void targetActor(Actor actor) {
    if (actor != target) {
      target = actor;
      dirty();
    }
  }

  Color getColorForElement(Element element) {
    switch (element) {
      case Element.NONE: return Color.LIGHT_BROWN;
      case Element.AIR: return Color.LIGHT_AQUA;
      case Element.EARTH: return Color.BROWN;
      case Element.FIRE: return Color.RED;
      case Element.WATER: return Color.BLUE;
      case Element.ACID: return Color.GREEN;
      case Element.COLD: return Color.LIGHT_BLUE;
      case Element.LIGHTNING: return Color.YELLOW;
      case Element.POISON: return Color.DARK_GREEN;
      case Element.DARK: return Color.DARK_GRAY;
      case Element.LIGHT: return Color.LIGHT_YELLOW;
      case Element.SPIRIT: return Color.PURPLE;
    }
  }

  /// Visually debug the scent data.
  Glyph debugScent(int x, int y, Tile tile, Glyph glyph) {
    if (!tile.isPassable) return glyph;

    var scent = game.stage.getScent(x, y);
    var color;
    if (scent == 0) color = Color.DARK_GRAY;
    else if (scent < 0.02) color = Color.DARK_BLUE;
    else if (scent < 0.04) color = Color.BLUE;
    else if (scent < 0.06) color = Color.DARK_AQUA;
    else if (scent < 0.08) color = Color.AQUA;
    else if (scent < 0.1) color = Color.DARK_GREEN;
    else if (scent < 0.2) color = Color.GREEN;
    else if (scent < 0.3) color = Color.DARK_YELLOW;
    else if (scent < 0.4) color = Color.YELLOW;
    else if (scent < 0.5) color = Color.DARK_ORANGE;
    else if (scent < 0.6) color = Color.ORANGE;
    else if (scent < 0.7) color = Color.DARK_RED;
    else if (scent < 0.8) color = Color.RED;
    else if (scent < 0.9) color = Color.DARK_PURPLE;
    else color = Color.PURPLE;

    var best = 0;
    var char = 'O';
    compareScent(dir, c) {
      var neighbor = game.stage.getScent(x + dir.x, y + dir.y);
      if (neighbor > best) {
        best = neighbor;
        char = c;
      }
    }

    compareScent(Direction.N, '|');
    compareScent(Direction.NE, '/');
    compareScent(Direction.E, '-');
    compareScent(Direction.SE, '\\');
    compareScent(Direction.S, '|');
    compareScent(Direction.SW, '/');
    compareScent(Direction.W, '-');
    compareScent(Direction.NW, '\\');

    return new Glyph(char, color);
  }

  void _spawnParticles(int count, Vec pos, Color color) {
    for (var i = 0; i < count; i++) {
      effects.add(new ParticleEffect(pos.x, pos.y, color));
    }
  }
}

interface Effect {
  bool update(Game game);
  void render(Terminal terminal);
}

class FrameEffect implements Effect {
  final Vec pos;
  final String char;
  final Color color;
  int life = 4;

  FrameEffect(this.pos, this.char, this.color);

  bool update(Game game) {
    return --life >= 0;
  }

  void render(Terminal terminal) {
    terminal.writeAt(pos.x, pos.y, char, color);
  }
}

class HitEffect implements Effect {
  final int x;
  final int y;
  final int health;
  int frame = 0;

  static final NUM_FRAMES = 15;

  HitEffect(Actor actor)
  : x = actor.x,
    y = actor.y,
    health = 9 * actor.health.current ~/ actor.health.max;

  bool update(Game game) {
    return frame++ < NUM_FRAMES;
  }

  void render(Terminal terminal) {
    var back;
    switch (frame ~/ 5) {
      case 0: back = Color.RED;      break;
      case 1: back = Color.DARK_RED; break;
      case 2: back = Color.BLACK;    break;
    }
    terminal.writeAt(x, y, ' 123456789'[health], Color.BLACK, back);
  }
}

class ParticleEffect implements Effect {
  num x;
  num y;
  num h;
  num v;
  int life;
  final Color color;

  ParticleEffect(this.x, this.y, this.color) {
    final theta = rng.range(628) / 100; // TODO(bob): Ghetto.
    final radius = rng.range(30, 40) / 100;

    h = cos(theta) * radius;
    v = sin(theta) * radius;
    life = rng.range(7, 15);
  }

  bool update(Game game) {
    x += h;
    y += v;

    final pos = new Vec(x.toInt(), y.toInt());
    if (!game.stage.bounds.contains(pos)) return false;
    if (!game.stage[pos].isPassable) return false;

    return life-- > 0;
  }

  void render(Terminal terminal) {
    terminal.writeAt(x.toInt(), y.toInt(), '*', color);
  }
}

class HealEffect implements Effect {
  int x;
  int y;
  int frame = 0;

  HealEffect(this.x, this.y);

  bool update(Game game) {
    return frame++ < 24;
  }

  void render(Terminal terminal) {
    var back;
    switch ((frame ~/ 4) % 4) {
      case 0: back = Color.BLACK;       break;
      case 1: back = Color.DARK_AQUA;   break;
      case 2: back = Color.AQUA;        break;
      case 3: back = Color.LIGHT_AQUA;  break;
    }

    terminal.writeAt(x - 1, y, '-', back);
    terminal.writeAt(x + 1, y, '-', back);
    terminal.writeAt(x, y - 1, '|', back);
    terminal.writeAt(x, y + 1, '|', back);
  }
}