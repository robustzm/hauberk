import 'dart:convert';
import 'dart:html' as html;

import '../engine.dart';

/// The entrypoint for all persisted save data.
class Storage {
  final Content content;
  final List<HeroSave> heroes = <HeroSave>[];

  Storage(this.content) {
    _load();
  }

  void _load() {
    // TODO: For debugging. If the query is "?clear", then ditch saved heroes.
    if (html.window.location.search == '?clear') {
      save();
      return;
    }

    var storage = html.window.localStorage['heroes'];
    if (storage == null) return;

    var data = json.decode(storage) as Map<String, dynamic>;

    // TODO: Check version.

    for (var hero in data['heroes']) {
      try {
        var name = hero['name'] as String;
        var race = _loadRace(hero['race'] as Map<String, dynamic>);

        HeroClass heroClass;
        if (hero['class'] == null) {
          // TODO: Temp for characters before classes.
          heroClass = content.classes[0];
        } else {
          var name = hero['class'] as String;
          heroClass = content.classes.firstWhere((c) => c.name == name);
        }

        var inventoryItems = _loadItems(hero['inventory']);
        var inventory = Inventory(
            ItemLocation.inventory, Option.inventoryCapacity, inventoryItems);

        var equipment = Equipment();
        for (var item in _loadItems(hero['equipment'])) {
          // TODO: If there are multiple slots of the same type, this may
          // shuffle items around.
          equipment.equip(item);
        }

        var homeItems = _loadItems(hero['home']);
        var home = Inventory(ItemLocation.home, Option.homeCapacity, homeItems);

        var crucibleItems = _loadItems(hero['crucible']);
        var crucible = Inventory(
            ItemLocation.crucible, Option.crucibleCapacity, crucibleItems);

        // TODO: What if shops are added or changed?
        var shops = <Shop, Inventory>{};
        if (hero.containsKey('shops')) {
          content.shops.forEach((name, shop) {
            var shopData = hero['shops'][name] as List<dynamic>;
            if (shopData != null) {
              shops[shop] = shop.load(_loadItems(shopData));
            } else {
              print("No data for $name, so regenerating.");
              shops[shop] = shop.create();
            }
          });
        }

        // Clean up legacy heroes before item stacks.
        // TODO: Remove this once we don't need to worry about it anymore.
        inventory.countChanged();
        home.countChanged();
        crucible.countChanged();

        // Defaults are to support legacy saves.

        var experience = hero['experience'] as int;

        var levels = <Skill, int>{};
        var points = <Skill, int>{};
        var skills = hero['skills'] as Map<String, dynamic>;
        if (skills != null) {
          for (var name in skills.keys) {
            var skill = content.findSkill(name);
            // Handle old storage without points.
            // TODO: Remove when no longer needed.
            if (skills[name] is int) {
              levels[skill] = skills[name] as int;
              points[skill] = 0;
            } else {
              levels[skill] = skills[name]['level'] as int;
              points[skill] = skills[name]['points'] as int;
            }
          }
        }

        var skillSet = SkillSet.from(levels, points);

        var lore = _loadLore(hero['lore'] as Map<String, dynamic>);

        var gold = hero['gold'] as int;
        var maxDepth = hero['maxDepth'] as int ?? 0;

        var heroSave = HeroSave.load(
            name,
            race,
            heroClass,
            inventory,
            equipment,
            home,
            crucible,
            shops,
            experience,
            skillSet,
            lore,
            gold,
            maxDepth);
        heroes.add(heroSave);
      } catch (error, trace) {
        print("Could not load hero. Data:");
        print(json.encode(hero));
        print("Error:\n$error\n$trace");
      }
    }
  }

  RaceStats _loadRace(Map<String, dynamic> data) {
    // TODO: Temp to handle heros from before races.
    if (data == null) {
      return content.races.elementAt(4).rollStats();
    }

    var name = data['name'] as String;
    var race = content.races.firstWhere((race) => race.name == name);

    var statData = data['stats'] as Map<String, dynamic>;
    var stats = <Stat, int>{};

    for (var stat in Stat.all) {
      stats[stat] = statData[stat.name] as int;
    }

    // TODO: 1234 is temp for characters without seed.
    var seed = data['seed'] as int ?? 1234;

    return RaceStats(race, stats, seed);
  }

  List<Item> _loadItems(List<dynamic> data) {
    var items = <Item>[];
    for (var itemData in data) {
      var item = _loadItem(itemData as Map<String, dynamic>);
      if (item != null) items.add(item);
    }

    return items;
  }

  Item _loadItem(Map<String, dynamic> data) {
    var type = content.tryFindItem(data['type'] as String);
    if (type == null) {
      print("Couldn't find item type \"${data['type']}\", discarding item.");
      return null;
    }

    var count = 1;
    // Existing save files don't store count, so allow it to be missing.
    if (data.containsKey('count')) {
      count = data['count'] as int;
    }

    Affix prefix;
    if (data.containsKey('prefix')) {
      // TODO: Older save from back when affixes had types.
      if (data['prefix'] is Map) {
        prefix = content.findAffix(data['prefix']['name'] as String);
      } else {
        prefix = content.findAffix(data['prefix'] as String);
      }
    }

    Affix suffix;
    if (data.containsKey('suffix')) {
      // TODO: Older save from back when affixes had types.
      if (data['suffix'] is Map) {
        suffix = content.findAffix(data['suffix']['name'] as String);
      } else {
        suffix = content.findAffix(data['suffix'] as String);
      }
    }

    return Item(type, count, prefix, suffix);
  }

  Lore _loadLore(Map<String, dynamic> data) {
    var seenBreeds = <Breed, int>{};
    var slain = <Breed, int>{};
    var foundItems = <ItemType, int>{};
    var foundAffixes = <Affix, int>{};
    var usedItems = <ItemType, int>{};

    // TODO: Older saves before lore.
    if (data != null) {
      var seenMap = data['seen'] as Map<String, dynamic>;
      if (seenMap != null) {
        seenMap.forEach((breedName, dynamic count) {
          var breed = content.tryFindBreed(breedName);
          if (breed != null) seenBreeds[breed] = count as int;
        });
      }

      var slainMap = data['slain'] as Map<String, dynamic>;
      if (slainMap != null) {
        slainMap.forEach((breedName, dynamic count) {
          var breed = content.tryFindBreed(breedName);
          if (breed != null) slain[breed] = count as int;
        });
      }

      var foundItemMap = data['foundItems'] as Map<String, dynamic>;
      if (foundItemMap != null) {
        foundItemMap.forEach((itemName, dynamic count) {
          var itemType = content.tryFindItem(itemName);
          if (itemType != null) foundItems[itemType] = count as int;
        });
      }

      var foundAffixMap = data['foundAffixes'] as Map<String, dynamic>;
      if (foundAffixMap != null) {
        foundAffixMap.forEach((affixName, dynamic count) {
          var affix = content.findAffix(affixName);
          if (affix != null) foundAffixes[affix] = count as int;
        });
      }

      var usedItemMap = data['usedItems'] as Map<String, dynamic>;
      if (usedItemMap != null) {
        usedItemMap.forEach((itemName, dynamic count) {
          var itemType = content.tryFindItem(itemName);
          if (itemType != null) usedItems[itemType] = count as int;
        });
      }
    }

    return Lore.from(seenBreeds, slain, foundItems, foundAffixes, usedItems);
  }

  void save() {
    var heroData = <dynamic>[];
    for (var hero in heroes) {
      var raceStats = <String, dynamic>{};
      for (var stat in Stat.all) {
        raceStats[stat.name] = hero.race.max(stat);
      }

      var race = {
        'name': hero.race.name,
        'seed': hero.race.seed,
        'stats': raceStats
      };

      var inventory = _saveItems(hero.inventory);
      var equipment = _saveItems(hero.equipment);
      var home = _saveItems(hero.home);
      var crucible = _saveItems(hero.crucible);

      var shops = <String, dynamic>{};
      hero.shops.forEach((shop, inventory) {
        shops[shop.name] = _saveItems(inventory);
      });

      var skills = <String, dynamic>{};
      for (var skill in hero.skills.discovered) {
        skills[skill.name] = {
          'level': hero.skills.level(skill),
          'points': hero.skills.points(skill)
        };
      }

      var seen = <String, dynamic>{};
      var slain = <String, dynamic>{};
      var lore = {'seen': seen, 'slain': slain};
      for (var breed in content.breeds) {
        var count = hero.lore.seenBreed(breed);
        if (count != 0) seen[breed.name] = count;

        count = hero.lore.slain(breed);
        if (count != 0) slain[breed.name] = count;
      }

      heroData.add({
        'name': hero.name,
        'race': race,
        'class': hero.heroClass.name,
        'inventory': inventory,
        'equipment': equipment,
        'home': home,
        'crucible': crucible,
        'shops': shops,
        'experience': hero.experience,
        'skills': skills,
        'lore': lore,
        'gold': hero.gold,
        'maxDepth': hero.maxDepth
      });
    }

    // TODO: Version.
    var data = {'heroes': heroData};

    html.window.localStorage['heroes'] = json.encode(data);
    print('Saved.');
  }

  List _saveItems(Iterable<Item> items) {
    return <dynamic>[for (var item in items) _saveItem(item)];
  }

  Map _saveItem(Item item) {
    var itemData = <String, dynamic>{
      'type': item.type.name,
      'count': item.count,
      if (item.prefix != null) 'prefix': item.prefix.name,
      if (item.suffix != null) 'suffix': item.suffix.name,
    };

    return itemData;
  }
}
