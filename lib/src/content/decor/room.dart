import '../tiles.dart';
import 'furnishing_builder.dart';

void roomDecor() {
  var tableCells = {
    "┌": applyOpen(Tiles.tableTopLeft),
    "─": applyOpen(Tiles.tableTop),
    "┐": applyOpen(Tiles.tableTopRight),
    "-": applyOpen(Tiles.tableCenter),
    "│": applyOpen(Tiles.tableSide),
    "╘": applyOpen(Tiles.tableBottomLeft),
    "═": applyOpen(Tiles.tableBottom),
    "╛": applyOpen(Tiles.tableBottomRight),
    "╞": applyOpen(Tiles.tableLegLeft),
    "╤": applyOpen(Tiles.tableLeg),
    "╡": applyOpen(Tiles.tableLegRight),
    "i": applyOpen(Tiles.candle),
  };

  // Counters.
  category(themes: "dungeon keep", cells: tableCells);
  furnishing(symmetry: Symmetry.mirrorHorizontal, template: """
    ?...
    #─┐.
    #-│.
    #╤╛.
    ?...""");

  furnishing(symmetry: Symmetry.mirrorHorizontal, template: """
    ?...
    #─┐.
    #i│.
    #╤╛.
    ?...""");

  furnishing(symmetry: Symmetry.mirrorHorizontal, template: """
    ?...
    #─┐.
    #-│.
    #-│.
    #╤╛.
    ?...""");

  furnishing(symmetry: Symmetry.mirrorHorizontal, template: """
    ?...
    #─┐.
    #i│.
    #i│.
    #╤╛.
    ?...""");

  furnishing(symmetry: Symmetry.mirrorHorizontal, template: """
    ?...
    #─┐.
    #-│.
    #-│.
    #-│.
    #╤╛.
    ?...""");

  furnishing(symmetry: Symmetry.mirrorHorizontal, template: """
    ?...
    #─┐.
    #-│.
    #i│.
    #-│.
    #╤╛.
    ?...""");

  furnishing(symmetry: Symmetry.mirrorHorizontal, template: """
    ?...
    #─┐.
    #i│.
    #-│.
    #i│.
    #╤╛.
    ?...""");

  furnishing(template: """
    .....
    .┌─┐.
    .│-│.
    ?###?""");

  furnishing(template: """
    .....
    .┌─┐.
    .│i│.
    ?###?""");

  furnishing(template: """
    ......
    .┌──┐.
    .│--│.
    ?####?""");

  furnishing(template: """
    ......
    .┌──┐.
    .│ii│.
    ?####?""");

  furnishing(template: """
    .......
    .┌───┐.
    .│---│.
    ?#####?""");

  furnishing(template: """
    .......
    .┌───┐.
    .│-i-│.
    ?#####?""");

  furnishing(template: """
    .......
    .┌───┐.
    .│i-i│.
    ?#####?""");

  furnishing(template: """
    ?###?
    .│-│.
    .╞═╡.
    .....""");

  furnishing(template: """
    ?###?
    .│i│.
    .╞═╡.
    .....""");

  furnishing(template: """
    ?####?
    .│--│.
    .╞══╡.
    ......""");

  furnishing(template: """
    ?####?
    .│ii│.
    .╞══╡.
    ......""");

  furnishing(template: """
    ?#####?
    .│---│.
    .╞═══╡.
    .......""");

  furnishing(template: """
    ?#####?
    .│-i-│.
    .╞═══╡.
    .......""");

  furnishing(template: """
    ?#####?
    .│i-i│.
    .╞═══╡.
    .......""");

  // Separating counters.
  category(themes: "dungeon keep", cells: tableCells);
  furnishing(template: """
    ?.....?
    #─┐.┌─#
    #╤╛.╘╤#
    ?.....?""");

  furnishing(template: """
    ?.......?
    #──┐.┌──#
    #═╤╛.╘╤═#
    ?.......?""");

  furnishing(template: """
    ?.........?
    #───┐.┌───#
    #══╤╛.╘╤══#
    ?.........?""");

  furnishing(template: """
    ?##?
    .││.
    .╞╡.
    ....
    .┌┐.
    .││.
    ?##?""");

  furnishing(template: """
    ?##?
    .││.
    .││.
    .╞╡.
    ....
    .┌┐.
    .││.
    .││.
    ?##?""");

  furnishing(template: """
    ?##?
    .││.
    .││.
    .││.
    .╞╡.
    ....
    .┌┐.
    .││.
    .││.
    .││.
    ?##?""");

  // Tables.
  category(themes: "dungeon keep", cells: tableCells);

  furnishing(template: """
    .....
    .┌─┐.
    .│-│.
    .╞═╡.
    .....""");

  furnishing(template: """
    .....
    .┌─┐.
    .│i│.
    .╞═╡.
    .....""");

  furnishing(template: """
    ......
    .┌──┐.
    .│--│.
    .╞══╡.
    ......""");

  furnishing(template: """
    ......
    .┌──┐.
    .│ii│.
    .╞══╡.
    ......""");

  furnishing(template: """
    .......
    .┌───┐.
    .│---│.
    .╘╤═╤╛.
    .......""");

  furnishing(template: """
    .......
    .┌───┐.
    .│-i-│.
    .╘╤═╤╛.
    .......""");

  furnishing(template: """
    .......
    .┌───┐.
    .│i-i│.
    .╘╤═╤╛.
    .......""");

  furnishing(template: """
    ........
    .┌────┐.
    .│----│.
    .╘╤══╤╛.
    ........""");

  furnishing(template: """
    ........
    .┌────┐.
    .│i--i│.
    .╘╤══╤╛.
    ........""");

  furnishing(template: """
    .........
    .┌─────┐.
    .│-----│.
    .╘╤═══╤╛.
    .........""");

  furnishing(template: """
    .........
    .┌─────┐.
    .│--i--│.
    .╘╤═══╤╛.
    .........""");

  furnishing(template: """
    .........
    .┌─────┐.
    .│-i-i-│.
    .╘╤═══╤╛.
    .........""");

  furnishing(template: """
    ..........
    .┌──────┐.
    .│------│.
    .╘╤════╤╛.
    ..........""");

  furnishing(template: """
    ..........
    .┌──────┐.
    .│-i--i-│.
    .╘╤════╤╛.
    ..........""");

  furnishing(template: """
    .....
    .┌─┐.
    .│-│.
    .│-│.
    .╞═╡.
    .....""");

  furnishing(template: """
    .....
    .┌─┐.
    .│i│.
    .│i│.
    .╞═╡.
    .....""");

  furnishing(template: """
    ......
    .┌──┐.
    .│--│.
    .│--│.
    .╞══╡.
    ......""");

  furnishing(symmetry: Symmetry.mirrorHorizontal, template: """
    ......
    .┌──┐.
    .│i-│.
    .│-i│.
    .╞══╡.
    ......""");

  furnishing(template: """
    .......
    .┌───┐.
    .│---│.
    .│---│.
    .╘╤═╤╛.
    .......""");

  furnishing(template: """
    .......
    .┌───┐.
    .│-i-│.
    .│-i-│.
    .╘╤═╤╛.
    .......""");

  furnishing(template: """
    .......
    .┌───┐.
    .│-i-│.
    .│i-i│.
    .╘╤═╤╛.
    .......""");

  furnishing(template: """
    .......
    .┌───┐.
    .│i-i│.
    .│-i-│.
    .╘╤═╤╛.
    .......""");

  furnishing(template: """
    ........
    .┌────┐.
    .│----│.
    .│----│.
    .╘╤══╤╛.
    ........""");

  furnishing(symmetry: Symmetry.mirrorHorizontal, template: """
    ........
    .┌────┐.
    .│i---│.
    .│---i│.
    .╘╤══╤╛.
    ........""");

  furnishing(template: """
    .........
    .┌─────┐.
    .│-----│.
    .│-----│.
    .╘╤═══╤╛.
    .........""");

  furnishing(template: """
    .........
    .┌─────┐.
    .│--i--│.
    .│-i-i-│.
    .╘╤═══╤╛.
    .........""");

  furnishing(template: """
    .........
    .┌─────┐.
    .│i---i│.
    .│--i--│.
    .╘╤═══╤╛.
    .........""");

  furnishing(template: """
    ..........
    .┌──────┐.
    .│------│.
    .│------│.
    .╘╤════╤╛.
    ..........""");

  furnishing(template: """
    ..........
    .┌──────┐.
    .│-i--i-│.
    .│-i--i-│.
    .╘╤════╤╛.
    ..........""");

  // TODO: More table sizes? Shapes?

  // Chairs.
  category(themes: "built", frequency: 2.0, cells: {
    "π": applyOpen(Tiles.chair),
  });

  furnishing(symmetry: Symmetry.mirrorBoth, template: """
    π.
    .┌""");

  furnishing(symmetry: Symmetry.mirrorBoth, template: """
    π.
    ┌?""");

  furnishing(symmetry: Symmetry.mirrorBoth, template: """
    ..
    π┌""");

  furnishing(symmetry: Symmetry.mirrorHorizontal, template: """
    .╞
    π.""");

  furnishing(symmetry: Symmetry.rotate90, template: """
    ?═?
    .π.""");

  furnishing(template: """
    ?╤?
    .π.""");

  furnishing(symmetry: Symmetry.rotate90, template: """
    π
    #""");

  furnishing(symmetry: Symmetry.rotate90, template: """
    π
    .
    #""");

  // TODO: Some fraction of the time, should place open barrels and chests.
  // Barrels.
  category(
      themes: "built",
      frequency: 0.7,
      cells: {"%": applyOpen(Tiles.closedBarrel)});

  furnishing(symmetry: Symmetry.rotate90, template: """
    ##?
    #%.
    ?.?""");

  furnishing(symmetry: Symmetry.rotate90, template: """
    ?.?
    .%.
    ?.?""");

  furnishing(symmetry: Symmetry.rotate90, template: """
    ###?
    #%%.
    ?..?""");

  furnishing(symmetry: Symmetry.rotate90, template: """
    ###?
    #%%.
    #%.?
    ?.??""");

  furnishing(symmetry: Symmetry.rotate90, template: """
    ?##?
    .%%.
    ?..?""");

  furnishing(symmetry: Symmetry.rotate90, template: """
    ?###?
    .%%%.
    ?...?""");

  // Chests.
  category(
      themes: "built",
      frequency: 0.5,
      cells: {"&": applyOpen(Tiles.closedChest)});

  furnishing(symmetry: Symmetry.rotate90, template: """
    ##?
    #&.
    ?.?""");

  furnishing(symmetry: Symmetry.rotate90, template: """
    ?#?
    .&.
    ?.?""");
}
