# magiteknician

## 0.3.0

### Minor Changes

- 707c5d3: The game can be played on a Mac. The download is for Macs with Apple silicon (M1 and later) on macOS 13 or later.

## 0.2.1

### Patch Changes

- a3caa57: Version 0.2.0 was never given out: its release could not be made. Everything listed under 0.2.0 comes with this version, and nothing else has changed.

## 0.2.0

### Minor Changes

- 903419e: A new cursor. While you cast it is a ring that aims with its centre and draws in when you strike, and it trails ink in the colour of the rune to strike next. In menus it is a drop of sap that points with its tip. The brush the game began with can be had back in the options, and the choice is kept.
- 93e35a0: A spell can be heard to land. A blow, a ward going up, taking a blow and breaking, mending, a chill, a broken cast and a fizzle each have a sound, heard as the thing is seen. A harder blow is louder and lower. A recording put in `magiteknician/assets/audio/spells/` takes the place of any of them.
- 7355f4a: In a duel between two players, a spell is shown landing on both screens. The host says what each cast did, and the guest shows it. Players on this version and the one before can still duel each other; the one on the older version sees the duel as they did.
- c72f199: A spell can be seen to land. It crosses to the foe as a streak in the colours of its runes, bursts where it gets through, and flares on a ward that stops it. The grade of a cast is written beside its caster. A ward is a ring round its caster that runs down with the ward's time, and a chill is icicles round the rim. How much a spell did is how big it is drawn.
- 5db36d3: While there is a rune to strike, the keys are read 500 times a second and not once a frame. A fast cast had been judged as less steady than it was: a hand good enough for the best grade every time got it little more than half the time at 60 frames a second. This works the machine harder, and can be turned off in the options.
- cc1d4e7: The options have a volume. It is heard as the slider moves, a rune chimes when the slider is let go, and the choice is kept.

### Patch Changes

- 8833d7e: Every button in the main menu has a tone of its own, and the tones go down the menu a semitone at a time. Continue and Practice had been sharing one, and Versus and Options another.

## 0.1.0

### Minor Changes

- 5c12127: The first playable build.
  
  - Cast spells by striking their runes in rhythm, at whatever tempo you choose.
  - A campaign of nine duels, from the academy's training sphere to the Arch-Magus.
  - A practice range that shows how each stroke was judged.
  - Duels against another player over a network.
  - Nine spells to learn.
- f29bf79: The main menu shows which version of the game you are playing, and each release comes with the game built for Windows and Linux.
