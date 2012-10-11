#library('roguekit');

#import('dart:html', prefix: 'html');

#import('content.dart');
#import('engine.dart');
#import('ui.dart');
#import('util.dart');

main() {
  final content = createContent();

//  final terminal = new DomTerminal(100, 40, html.document.query('#terminal'));
  final terminal = new CanvasTerminal(100, 40, html.query('canvas'));
  final keyboard = new Keyboard(html.document);
  final ui = new UserInterface(keyboard, terminal);

  ui.push(new MainMenuScreen(content));

  final element = html.document.query('pre');

  tick(time) {
    ui.tick();
    html.window.requestAnimationFrame(tick);
  }

  html.window.requestAnimationFrame(tick);
}

class Fps {
  Fps() : ticks = new List(NUM_TICKS) {
    for (var i = 0; i < NUM_TICKS; i++) ticks[i] = 0;
  }

  tick(time) {
    // Get the duration between the oldest and newest ticks in the buffer.
    final start = ticks[head];
    final end = time;
    print((end - start) / NUM_TICKS);

    // Add it to the buffer.
    ticks[head] = time;
    head = (head + 1) % NUM_TICKS;
  }

  static final NUM_TICKS = 100;
  /// Circular buffer of past frame times.
  final List ticks;
  int head = 0;
}