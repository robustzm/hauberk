import 'dart:math' as math;

import 'package:malison/malison.dart';
import 'package:malison/malison_web.dart';

import '../engine.dart';
import '../hues.dart';
import 'draw.dart';
import 'game_screen.dart';
import 'input.dart';
import 'item_view.dart';
import 'target_dialog.dart';

/// Modal dialog for letting the user perform an [Action] on an [Item]
/// accessible to the [Hero].
class ItemDialog extends Screen<Input> {
  final GameScreen _gameScreen;

  /// The command the player is trying to perform on an item.
  final _ItemCommand _command;

  /// The current location being shown to the player.
  ItemLocation _location = ItemLocation.inventory;

  /// If the player needs to select a quantity for an item they have already
  /// chosen, this will be the index of the item.
  Item _selectedItem;

  /// The number of items the player selected.
  int _count;

  /// Whether the shift key is currently pressed.
  bool _shiftDown = false;

  /// The current item being inspected or `null` if there is none.
  Item _inspected;

  bool get isTransparent => true;

  /// True if the item dialog supports tabbing between item lists.
  bool get canSwitchLocations => _command.allowedLocations.length > 1;

  ItemDialog.drop(this._gameScreen) : _command = _DropItemCommand();

  ItemDialog.use(this._gameScreen) : _command = _UseItemCommand();

  ItemDialog.toss(this._gameScreen) : _command = _TossItemCommand();

  ItemDialog.pickUp(this._gameScreen)
      : _command = _PickUpItemCommand(),
        _location = ItemLocation.onGround;

  ItemDialog.unequip(this._gameScreen)
      : _command = _UseItemCommand(),
        _location = ItemLocation.equipment;

  bool handleInput(Input input) {
    switch (input) {
      case Input.ok:
        if (_selectedItem != null) {
          _command.selectItem(this, _selectedItem, _count, _location);
          return true;
        }
        break;

      case Input.cancel:
        if (_selectedItem != null) {
          // Go back to selecting an item.
          _selectedItem = null;
          dirty();
        } else {
          ui.pop();
        }
        return true;

      case Input.n:
        if (_selectedItem != null) {
          if (_count < _selectedItem.count) {
            _count++;
            dirty();
          }
          return true;
        }
        break;

      case Input.s:
        if (_selectedItem != null) {
          if (_count > 1) {
            _count--;
            dirty();
          }
          return true;
        }
        break;
    }

    return false;
  }

  bool keyDown(int keyCode, {bool shift, bool alt}) {
    if (keyCode == KeyCode.shift) {
      _shiftDown = true;
      dirty();
      return true;
    }

    if (alt) return false;

    // Can't switch view or select an item while selecting a count.
    if (_selectedItem != null) return false;

    if (keyCode >= KeyCode.a && keyCode <= KeyCode.z) {
      _selectItem(keyCode - KeyCode.a);
      return true;
    }

    if (!shift && keyCode == KeyCode.tab && canSwitchLocations) {
      _advanceLocation();
      dirty();
      return true;
    }

    return false;
  }

  bool keyUp(int keyCode, {bool shift, bool alt}) {
    if (keyCode == KeyCode.shift) {
      _shiftDown = false;
      dirty();
      return true;
    }

    return false;
  }

  void render(Terminal terminal) {
    _renderHelp(terminal);

    // TODO: Position the query near the item list.
    if (_selectedItem == null) {
      if (_shiftDown) {
        terminal.writeAt(1, 0, "Inspect which item?", UIHue.selection);
      } else {
        terminal.writeAt(1, 0, _command.query(_location), UIHue.selection);
      }
    } else {
      var query = _command.queryCount(_location);
      terminal.writeAt(1, 0, query, UIHue.text);
      terminal.writeAt(query.length + 2, 0, _count.toString(), UIHue.selection);
    }

    var itemCount = 0;
    switch (_location) {
      case ItemLocation.inventory:
        itemCount = Option.inventoryCapacity;
        break;
      case ItemLocation.equipment:
        itemCount = _gameScreen.game.hero.equipment.slots.length;
        break;
      case ItemLocation.onGround:
        itemCount = _getItems().length;
        break;
    }

    int itemsLeft;
    int itemsTop;
    if (_gameScreen.itemPanelVisible) {
      switch (_location) {
        case ItemLocation.inventory:
          itemsTop = _gameScreen.game.hero.equipment.slots.length + 2;
          break;
        case ItemLocation.equipment:
          itemsTop = 0;
          break;
        case ItemLocation.onGround:
          // TODO: Better Y? Make a panel for this?
          itemsTop = 0;
          break;
      }

      itemsLeft = terminal.width - 46;
    } else {
      itemsLeft = _gameScreen.stagePanelBounds.right - 46;
      itemsTop = _gameScreen.stagePanelBounds.y;
    }

    // TODO: Handle the item panel being wider than 46.
    var itemView = _ItemDialogItemView(this);
    itemView.render(terminal.rect(itemsLeft, itemsTop, 46, itemCount + 2));

    if (_inspected != null) {
      var y = itemsTop + itemView.itemY(_inspected) + 1;
      y = y.clamp(0, terminal.height - 20);
      drawInspector(terminal.rect(itemsLeft - 34, y, 34, 20),
          _gameScreen.game.hero.save, _inspected);
    }
  }

  void _renderHelp(Terminal terminal) {
    var helpKeys = <String, String>{};
    if (_selectedItem == null) {
      if (_shiftDown) {
        helpKeys["A-Z"] = "Inspect item";
      } else {
        helpKeys["A-Z"] = "Select item";
        helpKeys["Shift"] = "Inspect";
      }
    } else {
      helpKeys["↕"] = "Change quantity";
    }

    if (canSwitchLocations) {
      helpKeys["Tab"] = "Switch view";
    }

    Draw.helpKeys(terminal, helpKeys);
  }

  bool _canSelect(Item item) {
    if (_shiftDown) return true;

    if (_selectedItem != null) return item == _selectedItem;
    return _command.canSelect(item);
  }

  void _selectItem(int index) {
    var items = _getItems().slots.toList();
    if (index >= items.length) return;

    // Can't select an empty equipment slot.
    if (items[index] == null) return;

    if (_shiftDown) {
      _inspected = items[index];
      dirty();
    } else {
      if (!_command.canSelect(items[index])) return;

      if (items[index].count > 1 && _command.needsCount) {
        _selectedItem = items[index];
        _count = _selectedItem.count;
        dirty();
      } else {
        // Either we don't need a count or there's only one item.
        _command.selectItem(this, items[index], 1, _location);
      }
    }
  }

  ItemCollection _getItems() {
    switch (_location) {
      case ItemLocation.inventory:
        return _gameScreen.game.hero.inventory;
      case ItemLocation.equipment:
        return _gameScreen.game.hero.equipment;
      case ItemLocation.onGround:
        return _gameScreen.game.stage.itemsAt(_gameScreen.game.hero.pos);
    }

    throw "unreachable";
  }

  /// Rotates through the viewable locations the player can select an item from.
  void _advanceLocation() {
    var index = _command.allowedLocations.indexOf(_location);
    _location = _command
        .allowedLocations[(index + 1) % _command.allowedLocations.length];
  }
}

class _ItemDialogItemView extends ItemView {
  final ItemDialog _dialog;

  ItemCollection get items => _dialog._getItems();

  bool get canSelectAny => true;

  bool get capitalize => _dialog._shiftDown;

  Item get inspectedItem => _dialog._inspected;

  bool canSelect(Item item) => _dialog._canSelect(item);

  _ItemDialogItemView(this._dialog);

  void render(Terminal terminal) {
    Draw.frame(
        terminal, 0, 0, terminal.width, terminal.height, UIHue.selection);
    terminal.writeAt(2, 0, " ${items.name} ", UIHue.selection);

    super.render(terminal.rect(1, 1, terminal.width - 2, terminal.height - 2));
  }
}

/// The action the user wants to perform on the selected item.
abstract class _ItemCommand {
  /// Locations of items that can be used with this command. When a command
  /// allows multiple locations, players can switch between them.
  List<ItemLocation> get allowedLocations => const [
        ItemLocation.inventory,
        ItemLocation.equipment,
        ItemLocation.onGround
      ];

  /// If the player must select how many items in a stack, returns `true`.
  bool get needsCount;

  /// The query shown to the user when selecting an item in this mode from
  /// [view].
  String query(ItemLocation location);

  /// The query shown to the user when selecting a quantity for an item in this
  /// mode from [view].
  String queryCount(ItemLocation location) => null;

  /// Returns `true` if [item] is a valid selection for this command.
  bool canSelect(Item item);

  /// Called when a valid item has been selected.
  void selectItem(
      ItemDialog dialog, Item item, int count, ItemLocation location);
}

class _DropItemCommand extends _ItemCommand {
  List<ItemLocation> get allowedLocations =>
      const [ItemLocation.inventory, ItemLocation.equipment];

  bool get needsCount => true;

  String query(ItemLocation location) {
    switch (location) {
      case ItemLocation.inventory:
        return 'Drop which item?';
      case ItemLocation.equipment:
        return 'Unequip and drop which item?';
    }

    throw "unreachable";
  }

  String queryCount(ItemLocation location) => 'Drop how many?';

  bool canSelect(Item item) => true;

  void selectItem(
      ItemDialog dialog, Item item, int count, ItemLocation location) {
    dialog._gameScreen.game.hero
        .setNextAction(DropAction(location, item, count));
    dialog.ui.pop();
  }
}

class _UseItemCommand extends _ItemCommand {
  bool get needsCount => false;

  String query(ItemLocation location) {
    switch (location) {
      case ItemLocation.inventory:
        return 'Use or equip which item?';
      case ItemLocation.equipment:
        return 'Unequip which item?';
      case ItemLocation.onGround:
        return 'Pick up and use which item?';
    }

    throw "unreachable";
  }

  bool canSelect(Item item) => item.canUse || item.canEquip;

  void selectItem(
      ItemDialog dialog, Item item, int count, ItemLocation location) {
    dialog._gameScreen.game.hero.setNextAction(UseAction(location, item));
    dialog.ui.pop();
  }
}

class _TossItemCommand extends _ItemCommand {
  bool get needsCount => false;

  String query(ItemLocation location) {
    switch (location) {
      case ItemLocation.inventory:
        return 'Throw which item?';
      case ItemLocation.equipment:
        return 'Unequip and throw which item?';
      case ItemLocation.onGround:
        return 'Pick up and throw which item?';
    }

    throw "unreachable";
  }

  bool canSelect(Item item) => item.canToss;

  void selectItem(
      ItemDialog dialog, Item item, int count, ItemLocation location) {
    // Create the hit now so range modifiers can be calculated before the
    // target is chosen.
    var hit = item.toss.attack.createHit();
    dialog._gameScreen.game.hero.modifyHit(hit, HitType.toss);

    // Now we need a target.
    dialog.ui.goTo(TargetDialog(dialog._gameScreen, hit.range, (target) {
      dialog._gameScreen.game.hero
          .setNextAction(TossAction(location, item, hit, target));
    }));
  }
}

class _PickUpItemCommand extends _ItemCommand {
  List<ItemLocation> get allowedLocations => const [ItemLocation.onGround];

  bool get needsCount => true;

  String query(ItemLocation location) => 'Pick up which item?';

  String queryCount(ItemLocation location) => 'Pick up how many?';

  bool canSelect(Item item) => true;

  void selectItem(
      ItemDialog dialog, Item item, int count, ItemLocation location) {
    // Pick up item and return to the game
    dialog._gameScreen.game.hero.setNextAction(PickUpAction(item));
    dialog.ui.pop();
  }
}
