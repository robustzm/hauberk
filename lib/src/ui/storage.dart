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

    var data = JSON.decode(storage);

    // TODO: Check version.

    for (final hero in data['heroes']) {
      var name = hero['name'];

      var items = <Item>[];
      for (var itemData in hero['inventory']) {
        var item = _loadItem(itemData);
        if (item != null) items.add(item);
      }
      var inventory = new Inventory(Option.inventoryCapacity, items);

      var equipment = new Equipment();
      for (var itemData in hero['equipment']) {
        var item = _loadItem(itemData);
        // TODO: If there are multiple slots of the same type, this may
        // shuffle items around.
        if (item != null) equipment.equip(item);
      }

      items = [];
      for (var itemData in hero['home']) {
        var item = _loadItem(itemData);
        if (item != null) items.add(item);
      }
      var home = new Inventory(Option.homeCapacity, items);

      items = [];
      for (var itemData in hero['crucible']) {
        var item = _loadItem(itemData);
        if (item != null) items.add(item);
      }
      var crucible = new Inventory(Option.crucibleCapacity, items);

      // Clean up legacy heroes before item stacks.
      // TODO: Remove this once we don't need to worry about it anymore.
      inventory.countChanged();
      home.countChanged();
      crucible.countChanged();

      // Defaults are to support legacy saves.

      var experience = hero['experience'];

      var heroAttributes = hero['attributes'];
      var attributes = <Attribute, int>{};
      if (heroAttributes != null) {
        for (var attribute in Attribute.all) {
          attributes[attribute] = heroAttributes[attribute.name] ?? 10;
        }
      } else {
        // TODO: Remove this when no longer care about old pre-attribute saves.
        for (var attribute in Attribute.all) {
          attributes[attribute] = 10;
        }
      }

      var attributePoints = hero['attributePoints'] ?? 0;

      var gold = hero['gold'];

      var maxDepth = hero['maxDepth'] ?? 0;

      // TODO: Remove.
//      HeroClass heroClass;
//      switch (hero['class']['name']) {
//        case 'warrior':
//          heroClass = _loadWarrior(hero['class']);
//          break;
//        default:
//          throw 'Unknown hero class "${hero['class']['name']}".';
//      }

      var heroSave = new HeroSave.load(
          name,
          inventory,
          equipment,
          home,
          crucible,
          experience,
          attributes,
          attributePoints,
          gold,
          maxDepth);
      heroes.add(heroSave);
    }
  }

  Item _loadItem(Map data) {
    var type = content.tryFindItem(data['type']);
    if (type == null) {
      print("Couldn't find item type \"${data['type']}\", discarding item.");
      return null;
    }

    var count = 1;
    // Existing save files don't store count, so allow it to be missing.
    if (data.containsKey('count')) {
      count = data['count'];
    }

    Affix prefix;
    if (data.containsKey('prefix')) {
      // TODO: Older save from back when affixes had types.
      if (data['prefix'] is Map) {
        prefix = content.findAffix(data['prefix']['name']);
      } else {
        prefix = content.findAffix(data['prefix']);
      }
    }

    Affix suffix;
    if (data.containsKey('suffix')) {
      // TODO: Older save from back when affixes had types.
      if (data['suffix'] is Map) {
        suffix = content.findAffix(data['suffix']['name']);
      } else {
        suffix = content.findAffix(data['suffix']);
      }
    }

    return new Item(type, count, prefix, suffix);
  }

//  HeroClass _loadWarrior(Map data) {
//    return new Warrior.load(
//        fighting: data['fighting'],
//        combat: data['combat'],
//        toughness: data['toughness'],
//        masteries: data['masteries'] as Map<String, int>);
//  }

  void save() {
    var heroData = [];
    for (var hero in heroes) {
      var inventory = [];
      for (var item in hero.inventory) {
        inventory.add(_saveItem(item));
      }

      var equipment = [];
      for (var item in hero.equipment) {
        equipment.add(_saveItem(item));
      }

      var home = [];
      for (var item in hero.home) {
        home.add(_saveItem(item));
      }

      var crucible = [];
      for (var item in hero.crucible) {
        crucible.add(_saveItem(item));
      }

      // TODO: Remove.
//      var heroClass = {};
//      if (hero.heroClass is Warrior) {
//        heroClass['name'] = 'warrior';
//        _saveWarrior(hero.heroClass, heroClass);
//      }

      var attributes = {};
      for (var attribute in Attribute.all) {
        attributes[attribute.name] = hero.attributes[attribute];
      }

      heroData.add({
        'name': hero.name,
//        'class': heroClass,
        'inventory': inventory,
        'equipment': equipment,
        'home': home,
        'crucible': crucible,
        'experience': hero.experienceCents,
        'attributePoints': hero.attributePoints,
        'attributes': attributes,
        'gold': hero.gold,
        'maxDepth': hero.maxDepth
      });
    }

    // TODO: Version.
    var data = {'heroes': heroData};

    html.window.localStorage['heroes'] = JSON.encode(data);
    print('Saved.');
  }

  Map _saveItem(Item item) {
    var itemData = <String, dynamic>{
      'type': item.type.name,
      'count': item.count
    };

    if (item.prefix != null) {
      itemData['prefix'] = item.prefix.name;
    }

    if (item.suffix != null) {
      itemData['suffix'] = item.suffix.name;
    }

    return itemData;
  }

//  void _saveWarrior(Warrior warrior, Map data) {
//    data['fighting'] = warrior.fighting.count;
//    data['combat'] = warrior.combat.count;
//    data['toughness'] = warrior.toughness.count;
//
//    var masteries = {};
//    warrior.masteries.forEach((name, stat) {
//      masteries[name] = stat.count;
//    });
//
//    data['masteries'] = masteries;
//  }
}
