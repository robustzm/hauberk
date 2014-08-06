library hauberk.content.drops;

import 'package:piecemeal/piecemeal.dart';

import '../engine.dart';
import 'affixes.dart';
import 'items.dart';

Drop parseDrop(String name, [int level]) {
  if (level == null) return _itemDrop(name);

  // Find an item in this category so we can figure out the full path
  // to it.
  var categories;
  for (var item in Items.all.values) {
    if (item.categories.contains(name)) {
      categories = item.categories;
      break;
    }
  }

  // Only keep the prefix of the path up to the given category.
  categories = categories.take(categories.indexOf(name) + 1).toList();

  if (categories == null) throw 'Could not find category "$name".';
  return new _CategoryDrop(categories, level);
}

/// Creates a single drop [Frequency].
///
/// This should be used to create a list of frequencies which are in turn
/// passed to [parseDrop].
Frequency frequency(int frequency, String name, [int level]) {
  return new Frequency(frequency, parseDrop(name, level));
}

/// Creates a [Drop] that has a [chance]% chance of dropping [drop].
Drop percent(int chance, drop, [int level]) {
  return new _PercentDrop(chance, parseDrop(drop, level));
}

/// Creates a [Drop] that drops all of [drops].
Drop dropAllOf(List<Drop> drops) => new _AllOfDrop(drops);

/// Creates a [Drop] that has a chance to drop one of [drops] each with its
/// own [Frequency].
Drop dropOneOf(List<Frequency> drops) => new _FrequencyDrop(drops);

class Frequency {
  final int _frequency;
  final Drop _drop;

  Frequency(this._frequency, this._drop);
}

Drop _itemDrop(String name) {
  var itemType = Items.all[name];
  if (itemType == null) throw 'Could not find item type "$name".';

  // See if the item is in a group.
  return new _ItemDrop(itemType);
}

/// Drops an item of a given type.
class _ItemDrop implements Drop {
  final ItemType _type;

  _ItemDrop(this._type);

  void spawnDrop(AddItem addItem) {
    addItem(Affixes.createItem(_type));
  }
}

/// Drops a randomly selected item near a level from a category.
class _CategoryDrop implements Drop {
  /// The path to the category to choose from.
  final List<String> _category;

  /// The average level of the drop.
  final int _level;

  _CategoryDrop(this._category, this._level);

  void spawnDrop(AddItem addItem) {
    // Possibly choose from the parent category.
    var categoryDepth = _category.length - 1;
    if (categoryDepth > 1 && rng.oneIn(10)) categoryDepth--;

    // Chance of out-of-depth items.
    var level = _level;
    if (rng.oneIn(1000)) {
      level += rng.range(20, 100);
    } else if (rng.oneIn(100)) {
      level += rng.range(5, 20);
    } else if (rng.oneIn(10)) {
      level += rng.range(1, 5);
    }

    // Find all of the items at or below the max level and in the category.
    var category = _category[categoryDepth];
    var items = Items.all.values
        .where((item) => item.level <= level &&
                         item.categories.contains(category)).toList();

    if (items.isEmpty) return;

    // TODO: Item rarity?

    // Pick an item. Try a few times and take the best.
    var itemType = rng.item(items);
    for (var i = 0; i < 3; i++) {
      var thisType = rng.item(items);
      if (thisType.level > itemType.level) itemType = thisType;
    }

    // Compare the item's actual level to the original desired level. If the
    // item is below that level, it increases the chances of an affix. (A weaker
    // item deeper in the dungeon is more likely to be magic.) Likewise, an
    // already-out-of-depth item is less likely to also be special.
    var levelOffset = itemType.level - _level;

    addItem(Affixes.createItem(itemType, levelOffset));
  }
}

/// Chooses a single [Drop] from a list of possible options with a percentage
/// chance for each. If the odds don"t add up to 100%, no item may be dropped.
class _FrequencyDrop implements Drop {
  final List<Frequency> _drops;
  final int _total;

  _FrequencyDrop(List<Frequency> drops)
      : _drops = drops,
        _total = drops.fold(0, (total, drop) => total + drop._frequency);

  void spawnDrop(AddItem addItem) {
    var roll = rng.range(_total);

    for (var i = 0; i < _drops.length; i++) {
      roll -= _drops[i]._frequency;
      if (roll > 0) continue;
      _drops[i]._drop.spawnDrop(addItem);
    }
  }
}

/// A [Drop] that will create an inner drop some random percentage of the time.
class _PercentDrop implements Drop {
  final int _chance;
  final Drop _drop;

  _PercentDrop(this._chance, this._drop);

  void spawnDrop(AddItem addItem) {
    if (rng.range(100) >= _chance) return;
    _drop.spawnDrop(addItem);
  }
}

/// A [Drop] that drops all of a list of child drops.
class _AllOfDrop implements Drop {
  final List<Drop> _drops;

  _AllOfDrop(this._drops);

  void spawnDrop(AddItem addItem) {
    for (var drop in _drops) drop.spawnDrop(addItem);
  }
}
