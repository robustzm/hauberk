# Hauberk Player's Guide

Welcome! I see you have an adventurous spirit! Not because you wish to venture into dungeons filled with beasts and untolds horrors, but because you have the fortitude to try out a game while it's still under development. Well, some of the former too.

A caution for the unwary: **The game is not done, or balanced, or complete, or bug-free.** You can help!

## Input

Hauberk is played using your keyboard. A lot of input is directional. Arrow keys work for that, but that don't cover diagonal moves. Instead, you're better off using the numpad on your keyboard if you have one:

    .---.---.---.          .---.---.---.
    | 7 | 8 | 9 |          | \ | ^ | / |
    |---+---+---|          |---+---+---|
    | 4 | 5 | 6 | maps to: |<- |   | ->|
    |---+---+---|          |---+---+---|
    | 7 | 8 | 9 |          | / | v | \ |
    '---'---'---'          '---'---'---'

If you don't have a numpad, but do have a US layout keyboard, you can also use:

    .---.---.---.          .---.---.---.
    | I | O | P |          | \ | ^ | / |
    '---+---+---+          '---+---+---+
     | K | L | ; | maps to: |<- |   | ->|
     '---+---+---+          '---+---+---+
      | , | . | / |          | / | v | \ |
      '---'---'---'          '---'---'---'

The `5` and `L` buttons in the middle are "stand". They're also used like an "OK" button to accept a selection on menu screens. `Escape` is used to go back in menu screens and exit dialogs.

(Note that all keys are shown uppercase here but are typed lower case. `L` means a lowercase "l". An uppercase one will be `Shift-L`.)

## A Hero Awakens

To start playing, first you need to create a character. On the Main Menu Screen, type `N` to create a new hero. Enter a name (or use the default suggested one) and hit `Enter`.

*There isn't much to specify at character creation time right now, but eventually you'll pick a class, race, and maybe some other stuff. Currently, warrior is the only class.*

Your hero is saved in your browser's [local storage][]. This means you can return to the game later and your hero will still be there. If you switch browsers, though, your heroes won't be in the new browser. Heroes are saved every time you leave a level, or exit your home.

[local storage]: https://developer.mozilla.org/en-US/docs/Web/Guide/API/DOM/Storage#localStorage

*Because the game is still in active development, new releases may not be savefile compatible with previous ones. Your heroes may get deleted if they don't work with the latest code.*

### The hero screen

Once you create or choose a hero, you're taken to the *hero screen*. This is sort of like the "town" in other games. It's the safe place where you can tinker with your hero and enter the game.

### Your home

From the hero screen, press `H` to enter your home. This gives you a place where you can stash loot you don't want to carry around. You can also move items between your *inventory* (stuff you carry in your backpack) and your *equipment* (weapons and armor you are currently wearing or holding).

### The Crucible

The most interesting facet of your home is the *Crucible*. This is the place where you can *craft*&mdash;make new items from existing ones. You place items into the Crucible just like you can your home or inventory. However, it only allows items that are part of a *recipe*.

A recipe is a set of items that can be turned into something else. When you place all of the required items for a recipe in the crucible, it will tell you. Press `Space` and it will magically transmute them into something new.

The set of recipes is still highly in flux, but try dropping a few healing potions in there.

## The Dungeon Awaits

Now that your hero is alive and ready, it's time to slay some beasts.

### Areas and levels

Unlike other roguelikes, Hauberk doesn't have a single monolithic dungeon. Instead, there are a number of *areas*. Each area has its own "flavor"&mdash;it's own kind of monsters, difficulty, appearance, etc. Each area is in turn divided into a series of *levels*, each more difficult than the last.

From the hero screen, you can select which area and level you want to play. You can only choose an area if you've beaten at least one level from the previous area. Likewise, you much beat a level to unlock the next one.

Since you just created a hero, you can only play the first level of the Training Grounds, so just type `L` to enter it. Later, when you unlock stuff, use the directional keys to select an area and level. You can replay a level as many times as you want.

### Quests, victory, and defeat

Every level is randomly generated (of course) and populated with monsters and treasure. Each level has a *quest*. This is a goal you must fulfill before you're allowed to leave the level. After completing the quest, type `Q` to leave the level and return to the safety of your home. All experience and items gained in the level will be saved henceforth and forever more.

If you *die* in the level, you lose everything you gained while in that level. It isn't quite permadeath, but it's pretty damn annoying to lose that experience and whatever hot loot you picked up.

If you want to give up and leave the level before completing the quest, you can *forfeit* by typing `Shift-F`. Like dying, doing this sacrifices anything you've gained since entering the level.

### Navigating the level

Your avatar in the game is represented by a `@`. Floor tiles are usually `.`, and impassible barriers and walls look like `#`, or other hopefully obvious solid looking tiles.

You can walk around using the directional keys. Pressing the stand key (`5` or `L`) makes your hero stand still for a turn. That's useful to let a monster take a step closer so you can attack the next turn.

If you hold down `Shift` and press a directional key, your hero will *run* in that direction. They will repeatedly walk in that direction until *disturbed* by reaching an obstacle, a fork in the path, or seeing a monster. When not in combat, running is the most user-friendly way to get from point A to point B.

Closed doors look like `+`. You can open them (which takes a turn) by simply walking into them. An open door looks like `-`. You can close a door by pressing `C` while standing next to one.

### Combat!

Monsters in the game are represented using letters. You attack by trying to walk into the tile where a monster is standing. On the right side of the screen you can see your health along with some of the nearby monsters. Try to get theirs to zero before your does!

When you kill a monster, you are granted some *experience points*. Earn enough of those, and your hero will increase in *experience level*. That increases your maximum health and does some other good stuff.

Meanwhile, monsters will be attacking you. You are outnumbered, so try not to let them surround you. Attacking from the safety of a narrow corridor helps.

### Resting

After a scirmish, your hero has likely lost some health. That can be regained by imbibing magic potions, but those are in short supply. Instead, they'll have to rest.

Resting requires *food*, which your hero silently automatically discovers as they explore the level. Every turn that you stand still will consume a bit of food and regain a point of health. Instead of mashing down the stand key, if you press `Shift-Stand`, your hero will repeatedly rest until they run out of food, fully regain their health, or are disturbed by a nearby monster.

If you don't have any food, resting accomplishes nothing. To get food, you *must* explore new parts of the level. No resting on your laurels or wandering through familiar passages!

**TODO: Archery. Items.**
