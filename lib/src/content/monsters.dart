library hauberk.content.monsters;

import 'package:malison/malison.dart';

import '../engine.dart';
import 'builder.dart';

/// Builder class for defining [Monster] [Breed]s.
class Monsters extends ContentBuilder {
  static final Map<String, Breed> all = {};

  /// The default tracking for a breed that doesn't specify it.
  var _tracking;

  /// The default meander for a breed that doesn't specify it.
  var _meander;

  /// Default flags for the current group.
  var _flags;

  /// The current glyph. Any items defined will use this. Can be a string or
  /// a character code.
  var _glyph;

  void build() {
    // $  Creeping Coins
    // a  Arachnid/Scorpion   A  Ancient being
    // b  Giant Bat           B  Bird
    // c  Canine (Dog)        C  Canid (Dog-like humanoid)
    // d  Dragon              D  Ancient Dragon
    // e  Floating Eye        E  Elemental
    // f  Flying Insect       F  Feline (Cat)
    // g  Goblin              G  Golem
    // h  Humanoids           H  Hybrid
    // i  Insect              I  Insubstantial (ghost)
    // j  Jelly/Slime         J  (unused)
    // k  Kobold/Imp/Sprite   K  Kraken/Land Octopus
    // l  Lizard man          L  Lich
    // m  Mold/Mushroom       M  Multi-Headed Hydra
    // n  Naga                N  Demon
    // o  Orc                 O  Ogre
    // p  Human "person"      P  Giant "person"
    // q  Quadruped           Q  End boss ("quest")
    // r  Rodent/Rabbit       R  Reptile/Amphibian
    // s  Slug                S  Snake
    // t  Troglodyte          T  Troll
    // u  Minor Undead        U  Major Undead
    // v  Vine/Plant          V  Vampire
    // w  Worm or Worm Mass   W  Wight/Wraith
    // x  Skeleton            X  Xorn/Xaren
    // y  Yeek                Y  Yeti
    // z  Zombie/Mummy        Z  Serpent (snake-like dragon)
    // TODO(bob):
    // - Come up with something better than yeeks for "y".
    // - Don't use both "u" and "U" for undead?

    var categories = [
      arachnids,
      bats,
      birds,
      canines,
      eyes,
      flyingInsects,
      felines,
      goblins,
      humanoids,
      insects,
      jellies,
      kobolds,
      people,
      quadrupeds,
      rodents,
      reptiles,
      slugs,
      snakes,
      worms,
      skeletons
    ];

    for (var category in categories) {
      category();
    }
  }

  arachnids() {
    group("a", flags: "fearless");
    breed("garden spider", darkAqua, 2, [
      attack("bite[s]", 1, Element.POISON)
    ], drop: percent(3, "Stinger"),
        meander: 8, flags: "group");

    breed("brown spider", brown, 3, [
      attack("bite[s]", 2, Element.POISON)
    ], drop: percent(5, "Stinger"),
        meander: 8, flags: "group");

    breed("giant spider", darkBlue, 12, [
      attack("bite[s]", 3, Element.POISON)
    ], drop: percent(10, "Stinger"),
        meander: 5);
  }

  bats() {
    group("b");
    breed("little brown bat", lightBrown, 3, [
      attack("bite[s]", 3),
    ], meander: 6, speed: 2);

    breed("giant bat", lightBrown, 12, [
      attack("bite[s]", 8),
    ], meander: 4, speed: 2);
  }

  birds() {
    group("B");
    breed("robin", lightRed, 3, [
      attack("claw[s]", 1),
    ], drop: percent(25, "Red Feather"),
        meander: 4, speed: 2);

    breed("crow", darkGray, 4, [
      attack("bite[s]", 4),
    ], drop: percent(25, "Black Feather"),
        meander: 4, speed: 2, flags: "group");

    breed("raven", gray, 8, [
      attack("bite[s]", 6),
      attack("claw[s]", 5),
    ], drop: percent(20, "Black Feather"),
        meander: 1, flags: "protective");
  }

  canines() {
    group("c", tracking: 20, meander: 3, flags: "few");
    breed("mangy cur", yellow, 7, [
      attack("bite[s]", 4),
    ], drop: percent(20, "Fur Pelt"));

    breed("wild dog", gray, 9, [
      attack("bite[s]", 5),
    ], drop: percent(20, "Fur Pelt"));

    breed("mongrel", orange, 16, [
      attack("bite[s]", 7),
    ], drop: percent(20, "Fur Pelt"));
  }

  eyes() {
    group("e", flags: "immobile");
    breed("floating eye", yellow, 16, [
      attack("touch[es]", 4),
      lightBolt(cost: 10, damage: 8),
      teleport(cost: 40, range: 7)
    ]);

    // baleful eye, malevolent eye, murderous eye
  }

  flyingInsects() {
    group("f", tracking: 5, meander: 8);
    breed("butterfl[y|ies]", lightPurple, 1, [
      attack("tickle[s] on", 1),
    ], drop: percent(20, "Insect Wing"),
        speed: 2, flags: "few fearless");

    breed("bee", yellow, 1, [
      attack("sting[s]", 2),
    ], drop: percent(40, "Honeycomb"),
        speed: 1, flags: "group protective");

    breed("wasp", brown, 1, [
      attack("sting[s]", 2, Element.POISON),
    ], drop: percent(30, "Stinger"),
        speed: 2, flags: "berzerk");
  }

  felines() {
    group("F");
    breed("stray cat", lightOrange, 5, [
      attack("bite[s]", 4),
      attack("scratch[es]", 3),
    ], drop: percent(10, "Fur Pelt"),
        meander: 3, speed: 1);
  }

  goblins() {
    group("g", meander: 1, flags: "open-doors");
    breed("goblin peon", lightBrown, 16, [
      attack("stab[s]", 6)
    ],
    drop: [
      percent(10, "spear", 3),
      percent(5, "healing", 2),
    ], meander: 2, flags: "few");

    breed("goblin archer", green, 14, [
      attack("stab[s]", 3),
      arrow(cost: 8, damage: 4)
    ],
    drop: [
      percent(20, "bow", 1),
      percent(10, "dagger", 2),
      percent(5, "healing", 3),
    ], flags: "few");

    breed("goblin fighter", brown, 24, [
      attack("stab[s]", 8)
    ], drop: [
      percent(15, "spear", 5),
      percent(5, "healing", 3),
    ]);

    breed("goblin warrior", gray, 32, [
      attack("stab[s]", 14)
    ], drop: [
      percent(20, "spear", 6),
      percent(5, "healing", 3),
    ], flags: "protective");

    breed("goblin mage", blue, 20, [
      attack("bash[es]", 14),
      fireBolt(cost: 16, damage: 6),
      sparkBolt(cost: 16, damage: 8),
    ], drop: [
      percent(10, "equipment", 3),
      percent(20, "magic", 6),
    ]);
  }

  humanoids() {
  }

  insects() {
    group("i", tracking: 3, meander: 8, flags: "fearless");
    breed("giant cockroach[es]", darkBrown, 12, [
      attack("crawl[s] on", 1),
    ], drop: percent(10, "Insect Wing"),
        speed: 3);

    breed("giant centipede", red, 12, [
      attack("crawl[s] on", 3),
      attack("bite[s]", 6),
    ], speed: 2);
  }

  jellies() {
    group("j", tracking: 2, meander: 4, flags: "few fearless");
    breed("green slime", green, 10, [
      attack("crawl[s] on", 3, Element.POISON)
    ]);

    breed("blue slime", blue, 12, [
      attack("crawl[s] on", 4, Element.COLD)
    ]);

    breed("red slime", blue, 14, [
      attack("crawl[s] on", 6, Element.FIRE)
    ]);
  }

  kobolds() {
    group("k", flags: "open-doors");
    breed("forest sprite", lightGreen, 6, [
      attack("scratch[es]", 4),
      teleport(range: 6)
    ], drop: [
      percent(10, "food", 1),
      percent(20, "magic", 1)
    ], meander: 4, flags: "cowardly");

    breed("house sprite", lightBlue, 6, [
      attack("stab[s]", 8),
      teleport(range: 6)
    ], drop: [
      percent(10, "food", 3),
      percent(20, "magic", 6)
    ], meander: 4, flags: "cowardly");

    breed("scurrilous imp", lightRed, 14, [
      attack("club[s]", 6),
      insult(),
      haste()
    ], drop: [
      percent(10, "club", 1),
      percent(5, "speed", 1),
    ], meander: 4, flags: "cowardly");

    breed("vexing imp", purple, 12, [
      attack("scratch[es]", 5),
      insult(),
      sparkBolt(cost: 10, damage: 6)
    ], drop: percent(10, "teleportation", 1),
        meander: 4, speed: 1, flags: "cowardly");

    breed("kobold", blue, 8, [
      attack("poke[s]", 4),
      teleport(cost: 20, range: 6)
    ], drop: [
      percent(10, "food", 3),
      percent(30, "magic", 7)
    ], meander: 4, flags: "group");

    breed("imp incanter", lightPurple, 16, [
      attack("scratch[es]", 5),
      insult(),
      fireBolt(cost: 10, damage: 10)
    ], drop: percent(10, "magic", 1),
        meander: 4, speed: 1, flags: "cowardly");

    breed("imp warlock", darkPurple, 20, [
      attack("stab[s]", 6),
      iceBolt(cost: 7, damage: 12),
      fireBolt(cost: 7, damage: 12)
    ], drop: percent(10, "magic", 4),
        meander: 3, speed: 1, flags: "cowardly");
  }

  people() {
    group("p", tracking: 14, flags: "open-doors");

    /*
    breed("debug meander", purple, 6, [
      attack("stab[s]", 1),
    ], meander: 2);

    breed("debug archer", green, 12, [
      attack("stab[s]", 4),
      arrow(cost: 10, damage: 2)
    ], meander: 2);
    */

    breed("simpering knave", orange, 6, [
      attack("hit[s]", 2),
      attack("stab[s]", 4)
    ], drop: [
      percent(30, "dagger", 1),
      percent(20, "body", 1),
      percent(10, "boots", 2),
      percent(10, "magic", 1),
    ], meander: 3, flags: "cowardly");

    breed("decrepit mage", purple, 6, [
      attack("hit[s]", 2),
      sparkBolt(cost: 30, damage: 8)
    ], drop: [
      percent(20, "magic", 3),
      percent(15, "dagger", 1),
      percent(15, "staff", 1),
      percent(40, "robe", 2),
      percent(10, "boots", 2)
    ], meander: 2);

    breed("unlucky ranger", green, 10, [
      attack("stab[s]", 2),
      arrow(cost: 10, damage: 2)
    ], drop: [
      percent(10, "potion", 3),
      percent(4, "bow", 4),
      percent(10, "dagger", 3),
      percent(8, "body", 3)
    ], meander: 2);

    breed("drunken priest", aqua, 9, [
      attack("hit[s]", 3),
      heal(cost: 30, amount: 8)
    ], drop: [
      percent(10, "scroll", 3),
      percent(7, "club", 2),
      percent(7, "robe", 2)
    ], meander: 4, flags: "fearless");
  }

  quadrupeds() {
    group("q");
    breed("fox", orange, 12, [
      attack("bite[s]", 7),
      attack("scratch[es]", 4)
    ], drop: "Fox Pelt",
        meander: 1, speed: 1);
  }

  rodents() {
    group("r", meander: 4);
    breed("field [mouse|mice]", lightBrown, 3, [
      attack("bite[s]", 3),
      attack("scratch[es]", 2)
    ], speed: 1);

    breed("fuzzy bunn[y|ies]", lightBlue, 10, [
      attack("bite[s]", 3),
      attack("kick[s]", 2)
    ], meander: 2);

    breed("vole", darkGray, 5, [
      attack("bite[s]", 4)
    ], speed: 1);

    breed("white [mouse|mice]", white, 6, [
      attack("bite[s]", 5),
      attack("scratch[es]", 3)
    ], speed: 1);

    breed("sewer rat", darkGray, 6, [
      attack("bite[s]", 4),
      attack("scratch[es]", 3)
    ], meander: 3, speed: 1, flags: "group");

    breed("plague rat", darkGreen, 7, [
      attack("bite[s]", 5, Element.POISON),
      attack("scratch[es]", 3)
    ], speed: 1, flags: "group");
  }

  reptiles() {
    group("R");
    breed("frog", green, 4, [
      attack("hop[s] on", 2),
    ], meander: 4, speed: 1);

    breed("salamander", red, 10, [
      attack("bite[s]", 22, Element.FIRE),
    ], meander: 3);

    // TODO: Drop scales?
    breed("lizard guard", yellow, 20, [
      attack("claw[s]", 10),
      attack("bite[s]", 14),
    ], meander: 1, flags: "fearless");

    breed("lizard protector", darkYellow, 26, [
      attack("claw[s]", 12),
      attack("bite[s]", 17),
    ], meander: 1, flags: "fearless");

    breed("armored lizard", gray, 36, [
      attack("claw[s]", 13),
      attack("bite[s]", 20),
    ], meander: 1, flags: "fearless");
  }

  slugs() {
    group("s", tracking: 2, flags: "fearless");
    breed("giant slug", green, 12, [
      attack("crawl[s] on", 5, Element.POISON),
    ], meander: 1, speed: -3);
  }

  snakes() {
    group("S", meander: 4);
    breed("garter snake", gold, 4, [
      attack("bite[s]", 1),
    ]);

    breed("tree snake", lightGreen, 12, [
      attack("bite[s]", 8),
    ]);
  }

  worms() {
    group("w", meander: 4, flags: "fearless");
    breed("giant earthworm", lightRed, 16, [
      attack("crawl[s] on", 8),
    ], speed: -2);

    breed("blood worm", red, 4, [
      attack("crawl[s] on", 5),
    ], flags: "swarm");

    breed("giant cave worm", white, 36, [
      attack("crawl[s] on", 8, Element.ACID),
    ], speed: -2);
  }

  skeletons() {

  }

  void group(glyph, {int meander, int tracking, String flags}) {
    _glyph = glyph;
    _meander = meander != null ? meander : 0;
    _tracking = tracking != null ? tracking : 10;
    _flags = flags;
  }

  Breed breed(String name, Glyph appearance(char), int health, List actions, {
      drop, int tracking, int meander, int speed: 0,
      String flags}) {
    if (tracking == null) tracking = _tracking;
    if (meander == null) meander = _meander;

    var attacks = <Attack>[];
    var moves = <Move>[];

    for (final action in actions) {
      if (action is Attack) attacks.add(action);
      if (action is Move) moves.add(action);
    }

    if (drop is List) {
      drop = dropAllOf(drop);
    } else if (drop is Drop) {
      drop = dropAllOf([drop]);
    } else if (drop is String) {
      drop = parseDrop(drop);
    } else {
      // Non-null way of dropping nothing.
      drop = dropAllOf([]);
    }

    var flagSet = new Set<String>();
    if (_flags != null) flagSet.addAll(_flags.split(" "));
    if (flags != null) flagSet.addAll(flags.split(" "));

    final breed = new Breed(name, Pronoun.IT, appearance(_glyph), attacks,
        moves, drop, maxHealth: health, tracking: tracking, meander: meander,
        speed: speed, flags: flagSet);
    Monsters.all[breed.name] = breed;
    return breed;
  }

  Move heal({int cost, int amount}) => new HealMove(cost, amount);

  Move arrow({int cost: 20, int damage}) =>
      new BoltMove(cost, new Attack("hits", damage, Element.NONE,
          new Noun("the arrow"), 8));

  Move sparkBolt({int cost: 20, int damage}) =>
      new BoltMove(cost, new Attack("zaps", damage, Element.LIGHTNING,
          new Noun("the spark"), 8));

  Move iceBolt({int cost: 20, int damage}) =>
      new BoltMove(cost, new Attack("freezes", damage, Element.COLD,
          new Noun("the ice"), 8));

  Move fireBolt({int cost: 20, int damage}) =>
      new BoltMove(cost, new Attack("burns", damage, Element.FIRE,
          new Noun("the flame"), 8));

  Move lightBolt({int cost: 20, int damage}) =>
      new BoltMove(cost, new Attack("sears", damage, Element.LIGHT,
          new Noun("the light"), 10));

  Move insult({int cost: 20}) => new InsultMove(cost);

  Move haste({int cost: 20, int duration: 10, int speed: 1}) =>
      new HasteMove(cost, duration, speed);

  Move teleport({int cost: 20, int range: 10}) =>
      new TeleportMove(cost, range);
}
