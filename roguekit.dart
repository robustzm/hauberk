#library('roguekit');

#import('dart:html');

#source('action.dart');
#source('actor.dart');
#source('array2d.dart');
#source('chain.dart');
#source('game.dart');
#source('level.dart');
#source('terminal.dart');
#source('vec.dart');

DomTerminal terminal;
Game        game;

bool _running = false;

bool get running() => _running;
void set running(bool value) {
  if (_running != value) {
    _running = value;
    if (_running) {
      window.webkitRequestAnimationFrame(tick, document);
    }
  }
}

main() {
  game = new Game();
  terminal = new DomTerminal(90, 30, document.query('#terminal'));

  render();

  document.on.click.add((event) => running = !running, true);

  window.webkitRequestAnimationFrame(tick, document);
  document.on.keyDown.add(keyPress);
}

class KeyCode {
  static final LEFT = 37;
  static final UP = 38;
  static final RIGHT = 39;
  static final DOWN = 40;
}

tick(time) {
  game.update();
  render();

  if (running) window.webkitRequestAnimationFrame(tick, document);
}

keyPress(event) {
  switch (event.keyCode) {
    case KeyCode.UP:
      game.hero.nextAction = new MoveAction(new Vec(0, -1));
      break;
    case KeyCode.DOWN:
      game.hero.nextAction = new MoveAction(new Vec(0, 1));
      break;
    case KeyCode.LEFT:
      game.hero.nextAction = new MoveAction(new Vec(-1, 0));
      break;
    case KeyCode.RIGHT:
      game.hero.nextAction = new MoveAction(new Vec(1, 0));
      break;
  }

  render();
}

render() {
  // Draw the level.
  for (int y = 0; y < game.level.height; y++) {
    for (int x = 0; x < game.level.width; x++) {
      var char;
      var color;
      switch (game.level.get(x, y).type) {
        case TileType.FLOOR: char = '.'; color = Color.DARK_GRAY; break;
        case TileType.WALL:  char = '#'; color = Color.WHITE; break;
      }
      terminal.writeAt(x, y, char, color);
    }
  }

  for (final actor in game.actors) {
    final color = (actor is Hero) ? Color.YELLOW : Color.GRAY;
    terminal.writeAt(actor.x, actor.y, '@', color);
  }

  terminal.render();
}

colorTest() {
  var colors = [
    Color.WHITE,
    Color.BLACK,
    Color.GRAY,
    Color.RED,
    Color.ORANGE,
    Color.YELLOW,
    Color.GREEN,
    Color.AQUA,
    Color.BLUE,
    Color.PURPLE,
    Color.DARK_GRAY,
    Color.DARK_RED,
    Color.DARK_ORANGE,
    Color.DARK_YELLOW,
    Color.DARK_GREEN,
    Color.DARK_AQUA,
    Color.DARK_BLUE,
    Color.DARK_PURPLE
  ];

  for (var y = 0; y < colors.length; y++) {
    for (var x = 0; x < colors.length; x++) {
      terminal.writeAt(x + 4, y + 2, '#', colors[y], colors[x]);
    }
  }
  /*
  terminal.writeAt(4,  3, 'white',  color: Color.WHITE);

  terminal.writeAt(4,  4, 'gray',   color: Color.GRAY);
  terminal.writeAt(4,  5, 'red',    color: Color.RED);
  terminal.writeAt(4,  6, 'orange', color: Color.ORANGE);
  terminal.writeAt(4,  7, 'yellow', color: Color.YELLOW);
  terminal.writeAt(4,  8, 'green',  color: Color.GREEN);
  terminal.writeAt(4,  9, 'aqua',   color: Color.AQUA);
  terminal.writeAt(4, 10, 'blue',   color: Color.BLUE);
  terminal.writeAt(4, 11, 'purple', color: Color.PURPLE);

  terminal.writeAt(14,  4, 'dark gray',   color: Color.DARK_GRAY);
  terminal.writeAt(14,  5, 'dark red',    color: Color.DARK_RED);
  terminal.writeAt(14,  6, 'dark orange', color: Color.DARK_ORANGE);
  terminal.writeAt(14,  7, 'dark yellow', color: Color.DARK_YELLOW);
  terminal.writeAt(14,  8, 'dark green',  color: Color.DARK_GREEN);
  terminal.writeAt(14,  9, 'dark aqua',   color: Color.DARK_AQUA);
  terminal.writeAt(14, 10, 'dark blue',   color: Color.DARK_BLUE);
  terminal.writeAt(14, 11, 'dark purple', color: Color.DARK_PURPLE);
  */
}

rand(int max) {
  return (Math.random() * max).toInt();
}

randRange(int min, int max) {
  return ((Math.random() * (max - min)) + min).toInt();
}
