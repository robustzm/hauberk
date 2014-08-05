library hauberk.ui.select_level_screen;

import 'dart:math' as math;

import 'package:malison/malison.dart';

import '../debug.dart';
import '../engine.dart';
import 'game_screen.dart';
import 'home_screen.dart';
import 'input.dart';
import 'storage.dart';

class SelectLevelScreen extends Screen {
  final Content  content;
  final HeroSave save;
  final Storage storage;
  int selectedArea = 0;
  int selectedLevel = 0;

  /// Gets the number of areas that the Hero is allowed to enter.
  ///
  /// For an area to be open, at least one level must have been completed in
  /// the previous area.
  int get _openAreas {
    var i;
    for (i = 1; i < content.areas.length; i++) {
      if (getCompletedLevel(content.areas[i - 1]) == 0) break;
    }

    return i;
  }

  SelectLevelScreen(this.content, this.save, this.storage);

  bool handleInput(Input input) {
    switch (input) {
    case Input.W:
        _changeSelection(selectedArea, selectedLevel - 1);
        return true;

    case Input.E:
        _changeSelection(selectedArea, selectedLevel + 1);
        return true;

    case Input.N:
        _changeSelection(selectedArea - 1, selectedLevel);
        return true;

    case Input.S:
        _changeSelection(selectedArea + 1, selectedLevel);
        return true;

    case Input.OK:
      var game = new Game(content.areas[selectedArea], selectedLevel,
          content, save);
      ui.push(new GameScreen(save, game));
      return true;

    case Input.CANCEL:
      ui.pop();
      return true;
    }

    return false;
  }

  bool keyDown(int keyCode, {bool shift, bool alt}) {
    if (shift || alt) return false;

    switch (keyCode) {
      case KeyCode.H:
        ui.push(new HomeScreen(content, save));
        return true;
    }

    return false;
  }

  void render(Terminal terminal) {
    terminal.writeAt(0, 0, 'Greetings, ${save.name}, where shall you quest?');
    terminal.writeAt(0, terminal.height - 1,
        '[L] Select area, [↕] Select area, [↔] Select level, [H] Enter home',
        Color.GRAY);

    for (var i = 0; i < content.areas.length; i++) {
      final area = content.areas[i];

      write(int x, String text, int level) {
        var fore = Color.WHITE;
        var back = Color.BLACK;
        if ((i == selectedArea) &&
           ((level == selectedLevel) || (level == -1))) {
          fore = Color.BLACK;
          back = Color.YELLOW;
        }

        // Can only select one past the completed level.
        if (i >= _openAreas || level > getCompletedLevel(area)) {
          fore = Color.DARK_GRAY;
        }

        terminal.writeAt(x, 2 + i, text, fore, back);
      }

      write(0, area.name, -1);

      var completed = save.completedLevels[area.name];
      if (completed == null) completed = 0;

      for (var level = 0; level < area.levels.length; level++) {
        write(50 + level * 3, (level + 1).toString(), level);
      }
    }
  }

  void activate(Screen screen, result) {
    if (screen is GameScreen && result) {
      // Left successfully, so save.
      storage.save();
      Debug.exitLevel();
    } else if (screen is HomeScreen) {
      // Always save when leaving the home.
      storage.save();
    }
  }

  void _changeSelection(int area, int level) {
    if (area < 0) area = 0;
    if (area >= _openAreas) {
      area = _openAreas - 1;
    }

    selectedArea = area;

    var maxLevel = math.min(content.areas[selectedArea].levels.length,
                       getCompletedLevel(content.areas[selectedArea]) + 1);

    if (level < 0) level = 0;
    if (level >= maxLevel) level = maxLevel - 1;

    selectedLevel = level;
    dirty();
  }

  /// Gets the one-based index of the highest completed level in [area].
  /// Returns `0` if no levels have been completed.
  int getCompletedLevel(Area area) {
    var level = save.completedLevels[area.name];
    if (level == null) return 0;
    return level;
  }
}
