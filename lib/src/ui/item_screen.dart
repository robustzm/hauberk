import 'dart:math' as math;

import 'package:malison/malison.dart';
import 'package:malison/malison_web.dart';

import '../engine.dart';
import '../hues.dart';
import 'input.dart';
import 'item_view.dart';

// TODO: Support inspecting items.
/// A screen where the hero can manage their items outside of the levels.
///
/// Lets them transfer between their inventory, equipment, crucible, and home.
/// Allows buying and selling from shops.
class ItemScreen extends Screen<Input> {
  final Content _content;
  final HeroSave _save;

  /// Whether the left hand side is showing the inventory or equipment.
  bool _showingInventory = true;

  /// The collection of items on the hero's person being shown.
  ItemCollection get _heroItems =>
      _showingInventory ? _save.inventory : _save.equipment;

  /// The place whose items are being interacted with.
  final _Place _place;

  Mode _mode = Mode.view;

  /// If the crucible contains a complete recipe, this will be it. Otherwise,
  /// this will be `null`.
  Recipe completeRecipe;

  String _error;

  ItemScreen.crucible(this._content, this._save) : _place = _Place.crucible;

  ItemScreen.home(this._content, this._save) : _place = _Place.home;

  ItemScreen.shop(this._content, this._save, Inventory shop)
      : _place = _ShopPlace(shop);

  bool handleInput(Input input) {
    if (_mode.handleInput(input, this)) return true;

    if (input == Input.cancel) {
      ui.pop();
      return true;
    }

    return false;
  }

  bool keyDown(int keyCode, {bool shift, bool alt}) {
    if (_error != null) {
      _error = null;
      dirty();
    }

    if (shift || alt) return false;

    if (keyCode == KeyCode.tab) {
      _showingInventory = !_showingInventory;
      dirty();
      return true;
    }

    if (_mode.keyDown(keyCode, this)) return true;

    if (keyCode == KeyCode.space && completeRecipe != null) {
      _save.crucible.clear();
      completeRecipe.result.spawnDrop(_save.crucible.tryAdd);
      refreshRecipe();

      // The player probably wants to get the item out of the crucible.
      _mode = Mode.get;
      dirty();
      return true;
    }

    return false;
  }

  void render(Terminal terminal) {
    _mode.render(this, terminal);

    var heroGold = formatMoney(_save.gold);
    terminal.writeAt(63, 0, "Gold:", UIHue.text);
    terminal.writeAt(79 - heroGold.length - 1, 0, "\$", persimmon);
    terminal.writeAt(79 - heroGold.length, 0, heroGold, gold);

    terminal.writeAt(
        0, terminal.height - 1, "${_mode.helpText(this)}", UIHue.helpText);

    _drawHero(terminal, 0);
    _drawPlace(terminal, 40);

    if (completeRecipe != null) {
      terminal.writeAt(59, 2, "Press [Space] to forge item!", UIHue.selection);

      var itemCount = _place.items(this).length;
      for (var i = 0; i < completeRecipe.produces.length; i++) {
        terminal.writeAt(50, itemCount + i + 4,
            completeRecipe.produces.elementAt(i), UIHue.text);
      }
    }

    if (_error != null) {
      terminal.writeAt(10, 30, _error, brickRed);
    }
  }

  void _drawHero(Terminal terminal, int x) {
    bool isSelectable(Item item) {
      if (!_mode.selectingFromHero) return false;
      return _mode.canSelectItem(this, item);
    }

    var canSelect = _mode.selectingFromHero || _mode.selectingFromPlace
        ? isSelectable
        : null;

    drawItems(
        terminal, x, _showingInventory ? _save.inventory : _save.equipment,
        getPrice: _place.putPrice, canSelect: canSelect);
  }

  void _drawPlace(Terminal terminal, int x) {
    // TODO: How does the shop name get shown?
    var items = _place.items(this);
    if (_mode.selectingFromHero || _mode.selectingFromPlace) {
      drawItems(terminal, x, items, getPrice: _place.getPrice,
          canSelect: (item) {
        if (!_mode.selectingFromPlace) return false;
        return _mode.canSelectItem(this, item);
      });
    } else {
      drawItems(terminal, x, items, getPrice: _place.getPrice);
    }
  }

  /// Sees if the crucible currently contains a complete recipe.
  void refreshRecipe() {
    for (var recipe in _content.recipes) {
      if (recipe.isComplete(_save.crucible)) {
        completeRecipe = recipe;
        return;
      }
    }

    completeRecipe = null;
  }

  /// The verb to use for transferring in the given direction.
  String _verb(bool toHero) => toHero ? _place.getVerb : _place.putVerb;

  bool _transfer(Item item, int count, {bool toHero}) {
    ItemCollection from;
    ItemCollection to;
    if (toHero) {
      from = _place.items(this);
      to = _heroItems;
    } else {
      from = _heroItems;
      to = _place.items(this);
    }

    if (!to.canAdd(item)) {
      _error = "Not enough room for ${item.clone(count)}.";
      return false;
    }

    if (count == item.count) {
      // Moving the entire stack.
      to.tryAdd(item);
      from.remove(item);
    } else {
      // Splitting the stack.
      to.tryAdd(item.splitStack(count));
      from.countChanged();
    }

    if (_place is _ShopPlace) {
      if (toHero) {
        // Pay for purchased item.
        _save.gold -= _place.getPrice(item) * count;
      } else {
        // Get paid for sold item.
        _save.gold += _place.putPrice(item) * count;
      }
    } else if (_place == _Place.crucible) {
      refreshRecipe();
    }
    return true;
  }
}

/// A source of items not on the hero's person.
class _Place {
  static const home = _Place();
  static const crucible = _CruciblePlace();

  const _Place();

  String get getVerb => "Get";

  String get putVerb => "Put";

  int get getKeyCode => KeyCode.g;

  int get putKeyCode => KeyCode.p;

  /// Gets the list of items from this place.
  ItemCollection items(ItemScreen screen) => screen._save.home;

  bool canGet(ItemScreen screen, Item item) => true;

  bool canPut(ItemScreen screen, Item item) => true;

  /// How much it costs to get the item from this place, or `null` if there is
  /// no cost.
  int getPrice(Item item) => null;

  /// How much it costs to put the item into this place, or `null` if there is
  /// no cost.
  int putPrice(Item item) => null;
}

class _CruciblePlace extends _Place {
  const _CruciblePlace();

  ItemCollection items(ItemScreen screen) => screen._save.crucible;

  bool canPut(ItemScreen screen, Item item) {
    // TODO: Should not allow a greater count of items than the recipe permits,
    // since the extras will be lost when the item is forged.

    // Can only put items in the crucible if they fit a recipe.
    var ingredients = items(screen).toList();
    ingredients.add(item);
    return screen._content.recipes.any((recipe) => recipe.allows(ingredients));
  }
}

class _ShopPlace implements _Place {
  final Inventory _shop;

  String get getVerb => "Buy";

  String get putVerb => "Sell";

  int get getKeyCode => KeyCode.b;

  int get putKeyCode => KeyCode.s;

  _ShopPlace(this._shop);

  ItemCollection items(ItemScreen screen) => _shop;

  /// Must have enough gold to buy at least one of it.
  bool canGet(ItemScreen screen, Item item) =>
      getPrice(item) <= screen._save.gold;

  /// Can only sell things that have a price.
  bool canPut(ItemScreen screen, Item item) => putPrice(item) > 0;

  int getPrice(Item item) => item.price;

  int putPrice(Item item) => (item.price * 0.75).floor();
}

/// What the user is currently doing on the item screen.
abstract class Mode {
  static final view = const ViewMode();
  static final put = SelectMode(toHero: false);
  static final get = SelectMode(toHero: true);

  const Mode();

  /// Whether the hero's items should be shown as selectable.
  bool get selectingFromHero => false;

  /// Whether the place's items should be shown as selectable.
  bool get selectingFromPlace => false;

  void render(ItemScreen screen, Terminal terminal) {
    terminal.writeAt(0, 0, message(screen), UIHue.selection);
  }

  String message(ItemScreen screen) => throw "Unused";

  String helpText(ItemScreen screen);

  /// If [item] can be selected.
  bool canSelectItem(ItemScreen screen, Item item) => false;

  bool handleInput(Input input, ItemScreen screen) => false;

  bool keyDown(int keyCode, ItemScreen screen) => false;
}

// TODO: Add a mode to equip/unequip an item.

/// Mode for selecting a quantity of some item to get or put.
class CountMode extends Mode {
  /// Whether the item is being transferred to or from the hero.
  final bool _toHero;

  final Item _item;
  int _count;

  CountMode(ItemScreen screen, this._item, {bool toHero}) : _toHero = toHero {
    if (screen._place is _ShopPlace) {
      // Default to buying one item.
      _count = 1;
    } else {
      // Default to picking up the whole stack.
      _count = _maxCount(screen);
    }
  }

  bool get selectingFromHero => !_toHero;

  bool get selectingFromPlace => _toHero;

  /// Highlight the item the user already selected.
  bool canSelectItem(ItemScreen screen, Item item) => item == _item;

  bool handleInput(Input input, ItemScreen screen) {
    switch (input) {
      case Input.ok:
        screen._transfer(_item, _count, toHero: _toHero);
        screen._mode = Mode.view;
        screen.dirty();
        return true;

      case Input.cancel:
        screen._mode = Mode.view;
        screen.dirty();
        return true;

      case Input.n:
        if (_count < _maxCount(screen)) {
          _count++;
          screen.dirty();
        }
        return true;

      case Input.s:
        if (_count > 1) {
          _count--;
          screen.dirty();
        }
        return true;
    }

    return false;
  }

  String helpText(ItemScreen screen) {
    if (_maxCount(screen) == 1) {
      return '[OK] ${screen._verb(_toHero)}, [Esc] Cancel';
    }

    return '[OK] ${screen._verb(_toHero)}, [↕] Change quantity, [Esc] Cancel';
  }

  void render(ItemScreen screen, Terminal terminal) {
    var x = 0;
    terminal.writeAt(x, 0, screen._verb(_toHero));
    x += screen._verb(_toHero).length + 1;

    var itemText = _item.clone(_count).toString();
    terminal.writeAt(x, 0, itemText, UIHue.selection);
    x += itemText.length;

    if (screen._place is _ShopPlace) {
      terminal.writeAt(x, 0, " for ");
      x += 5;

      var priceString = formatMoney(_itemPrice(screen) * _count);
      terminal.writeAt(x, 0, priceString, gold);
      x += priceString.length;

      terminal.writeAt(x, 0, " gold");
      x += 5;
    }

    terminal.writeAt(x, 0, "?");
  }

  int _maxCount(ItemScreen screen) {
    var maxCount = _item.count;

    // Don't allow buying more than the hero can afford.
    if (screen._place is _ShopPlace) {
      maxCount = math.min(maxCount, screen._save.gold ~/ _itemPrice(screen));
    }

    return maxCount;
  }

  int _itemPrice(ItemScreen screen) =>
      _toHero ? screen._place.getPrice(_item) : screen._place.putPrice(_item);
}

/// A mode for selecting an item.
class SelectMode extends Mode {
  /// If true, a place item is being selected, otherwise a hero item is.
  final bool _toHero;

  const SelectMode({bool toHero}) : _toHero = toHero;

  bool get selectingFromPlace => _toHero;

  bool get selectingFromHero => !_toHero;

  String message(ItemScreen screen) => "${screen._verb(_toHero)} which item?";

  String helpText(ItemScreen screen) => '[A-Z] Choose item, [Esc] Cancel';

  bool handleInput(Input input, ItemScreen screen) {
    if (input == Input.cancel) {
      screen._mode = Mode.view;
      screen.dirty();
      return true;
    }

    return false;
  }

  bool keyDown(int keyCode, ItemScreen screen) {
    if (keyCode < KeyCode.a || keyCode > KeyCode.z) return false;

    if (selectItem(screen, keyCode - KeyCode.a)) {
      // Switch back to viewing after a successful action.
      screen._mode = Mode.view;
      screen.dirty();
    }

    return true;
  }

  bool canSelectItem(ItemScreen screen, Item item) {
    if (_toHero) {
      return screen._place.canGet(screen, item);
    } else {
      return screen._place.canPut(screen, item);
    }
  }

  bool selectItem(ItemScreen screen, int index) {
    ItemCollection from;
    if (_toHero) {
      from = screen._place.items(screen);
    } else {
      from = screen._heroItems;
    }

    if (index >= from.length) return false;
    var item = from[index];
    if (!canSelectItem(screen, item)) return false;

    // Prompt the user for a count if the item is a stack.
    if (item.count > 1) {
      screen._mode = CountMode(screen, item, toHero: _toHero);
      screen.dirty();
      return false;
    }

    screen._transfer(item, 1, toHero: _toHero);
    return true;
  }
}

/// The default mode. Lets users switch which item lists are being shown on the
/// left and right sides, and choose an action to perform.
class ViewMode extends Mode {
  const ViewMode();

  String message(ItemScreen screen) => 'Which items do you want to look at?';

  String helpText(ItemScreen screen) {
    var tab = screen._showingInventory
        ? "Switch to equipment"
        : "Switch to inventory";

    return "[Tab] $tab, "
        "[${screen._place.getVerb[0]}] ${screen._place.getVerb}, "
        "[${screen._place.putVerb[0]}] ${screen._place.putVerb}, "
        "[Esc] Exit";
  }

  bool keyDown(int keyCode, ItemScreen screen) {
    if (keyCode == screen._place.getKeyCode) {
      screen._mode = Mode.get;
    } else if (keyCode == screen._place.putKeyCode) {
      screen._mode = Mode.put;
    } else {
      return false;
    }

    screen.dirty();
    return true;
  }
}
