library dngn.content;

import 'engine.dart';

import 'content/areas.dart';
import 'content/items.dart';
import 'content/monsters.dart';
import 'content/powers.dart';
import 'content/recipes.dart';
import 'content/tiles.dart';

Content createContent() {
  // Note: The order is significant here. For example, monster drops will
  // reference items, which need to have already been created.
  new Tiles().build();
  new Items().build();
  new Monsters().build();
  new Areas().build();
  new Recipes().build();
  Powers.build();

  // The items that a new hero starts with.
  final heroItems = [
    Items.all["Short Bow"],
    Items.all["Loaf of Bread"],
    Items.all["Loaf of Bread"],
    Items.all["Mending Salve"],
    Items.all["Scroll of Sidestepping"]
  ];

  return new Content(Areas.all, Monsters.all, Items.all, Recipes.all,
      heroItems);
}
