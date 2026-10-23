# 0014 — Member tiles are Liquid Glass

- **Status**: accepted
- **Date**: 2026-10-23
- **Amends**: [0006](0006-native-ipados-26.md)

## Context
[ADR 0006](0006-native-ipados-26.md) put Liquid Glass on the control layer only
and kept content opaque: member tiles, lists and cards were white on the grouped
background, following the iOS 26 guidance that glass belongs to what floats
above content.

On the home screen that line is blurry. A member tile is not something to read;
it is the button that starts or stops someone's hours, and the whole screen is
made of them. Seen on a device, the opaque tiles read as a list of names rather
than as things to tap, and the project owner asked for glass tiles.

## Decision
Member tiles on the home screen are interactive Liquid Glass
(`.glassEffect(.regular.interactive())`): they lift and shimmer under a finger
like any other iOS 26 control. The running timers sit in the same tiles in a
"Working now" section at the top of the list, with a faint green tint on their
glass.

Everything else in ADR 0006 stands. Lists, stat cards and the rows on the
close-day and sync screens are content and stay opaque.

## Consequences
- The tiles carry text on glass. On the flat grouped background that is
  legible; the contrast numbers in `docs/design.md` were measured on white and
  hold only approximately here, so the tiles need a look in a bright hangar.
- Many glass views in one scrolling grid cost more to render than white
  rectangles. A club has tens of members, not thousands, so this is accepted;
  if a large club scrolls badly, opaque tiles are the fallback.

## Alternatives considered
- Opaque tiles with a stronger pressed state: keeps ADR 0006 intact, but does
  not change how the screen reads at rest.
- Glass only on the running tiles: marks them out, but makes the rest of the
  grid look like a different kind of thing.
