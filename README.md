# Magiteknician

A rhythm game about casting spells, set in the world of *Another Sorcerer's Root*.

You cast a spell by striking its runes in order, in rhythm. The rhythm is fixed; the tempo is yours. Cast as fast or as slowly as you like, and the closer you keep to the spell's rhythm at the tempo you chose, the stronger the spell. You duel other casters in real time, so finishing a spell sooner is its own reward, and a clean slow cast can still lose to a rough fast one.

Built with Godot 4.7 and GDScript.

![A duel against Rizzle Dram, part-way through a Fire Bolt](docs/images/duel.png)

## Playing

| | |
| :- | :- |
| **Strike a rune** | Hold the cursor over it and press the key for that rune |
| δ Development | `A` |
| θ Refraction | `S` |
| κ Persistence | `D` |
| λ Decay | `Q` |
| ρ Flow | `W` |
| φ Equivalence | `E` |
| σ Variability | `X` |
| **Choose a spell** | `1` to `9`, or click its slot |
| **Hear the spell** | `Space` |
| **Give up a cast** | `Esc` or the right mouse button |

A spell is laid out as ghosts of its runes, joined in order by flow lines. The rune to strike next is ringed. Each pip on a flow line is a tick of rest: no pip means the next rune falls on the next tick, one pip means wait a tick.

Your first two strokes set the tempo. From the third, a ring closes on the next rune and meets its edge when the rune falls due *at the tempo you set*. Strike each rune as its ring closes and the cast is perfect, however fast or slow the first gap was.

Pressing a rune's key anywhere but on the rune that is next is a stray, and strays weaken the cast.

### Modes

- **New Game / Continue**: the campaign. Nine duels, from the academy's training sphere to the Arch-Magus. You start with three spells and learn the rest by winning.
- **Practice**: cast any spell with nothing at stake, and see how each stroke was judged.
- **Versus**: duel another player. One of you hosts, the other joins by address.

![The practice range after a cast of Lightning](docs/images/practice.png)

The panel on the right shows the cast as a raster: the spell's train above, yours below, rescaled to the tempo you chose. A stroke directly under its tick was on the beat, and one to the right of it was late.

### Spells

| Spell | Runes | Chi | Does |
| :- | :- | :- | :- |
| Spark | ρ σ | 6 | 5 damage |
| Gust | ρ σ | 8 | Wears a ward down by 16, and 3 damage |
| Flinch | ρ σ | 10 | Breaks the cast the foe is part-way through |
| Ward | κ ρ σ | 14 | Soaks up 12 damage for 8 s |
| Fire Bolt | δ ρ λ | 16 | 16 damage |
| Frost Bolt | λ ρ | 16 | 12 damage, and chills for 6 s |
| Mend | δ ρ σ | 20 | Heals 12 |
| Bulwark | κ ρ θ σ | 26 | Soaks up 26 for 10 s and turns 30% of it back |
| Lightning | λ ρ σ | 28 | 32 damage |

Those are the amounts for a flawless cast. What a cast delivers is scaled by how well it was cast.

- Chi is paid when a cast begins and is not returned if the cast fizzles, is broken or is given up.
- A ward keeps an interruption out.
- While you are chilled, your strokes are judged more strictly. A flawless cast is untouched.
- A duel escalates after its first minute: damage climbs, and wards and mending do not.

## How a cast is judged

A spell's rhythm is written in **unscaled ticks**. "Strike at 0, 1 and 3" says the second gap is twice the first and nothing about how long either is.

1. **Find the tempo.** The least-squares line through (tick, time of stroke) gives the length of one tick at the tempo the caster was evidently casting at.
2. **Measure the deviation.** Each stroke's distance from that line, divided by the length of a tick, is how far off the beat it was, in ticks. It is a ratio, so it reads the same at any speed.
3. **Score each stroke** on a gaussian centred on the beat.
4. **Modify by aim.** Striking a rune off-centre takes a little off. Aim cannot rescue a cast with no rhythm.
5. **Subtract for strays.**

```
quality = rhythm × aim_factor − strays × penalty
```

Quality gives a grade (S, A, B, C, D or Fizzle) and the **potency** the spell takes effect at. Every number involved is in `CastTuning`.

In spike-train terms this is an edit distance in the manner of Victor and Purpura, taken after rescaling time to the caster's own tempo. Moving a spike costs more the further it moved, an extra spike has a fixed cost, and a missing spike costs the whole cast.

Rushing or dragging the *whole* cast is a tempo, not a mistake. Speed is harder only because the same error in milliseconds is a larger share of a shorter beat.

## Running it

Open the project in Godot 4.7 and press play.

### Tests

```sh
GODOT=/path/to/godot tests/run.sh
GODOT=/path/to/godot tests/run.sh --only=casting
```

```powershell
$env:GODOT = 'C:\path\to\godot.exe'
tests\run.ps1
```

There are two parts, and both run headless, on every pull request.

- **The tests** live under `tests/`, in files named `test_*.gd` that extend `TestCase`. Each checks one thing on its own. A script error during a test fails the test. They take under half a minute.
- **The play-through** (`tests/play_through.tscn`) starts at the main menu and plays: a new game, a duel won, progress saved, and a visit to every other screen. It follows the game through real changes of scene, which the tests cannot. It takes about as long again, most of it spent waiting for fades.

With `--only`, the play-through is left out.

## How the code is laid out

```
magiteknician/
  engine/
    components/   Rune, and the trains: ExpectedTrain (the ghosts to follow)
                  and ActualTrain (the marks where strokes landed)
    casting/      RhythmFit, CastScorer, CastResult, CastTuning, SpellCircle
    spells/       Spell, RuneStroke, SpellEffect, Spellbook, SpellLibrary
    combat/       Duelist, Duel, SpellResolver, Opponent, and the casters:
                  Caster, NpcCaster, NpcBrain, CasterProfile, CastPlan
    campaign/     Campaign, CampaignStage, SaveGame
    net/          DuelProtocol, NetLink, StrokeSender, RemoteCaster,
                  DuelHost, DuelGuest, DuelMirror
  hud/            The duel's HUD and its parts
  levels/         The practice range, the duel arena, the versus arena
  menus/          The main, campaign, versus and options menus
  spells/         One .tres for each spell
  opponents/      One .tres for each opponent
  campaigns/      One .tres for each campaign
  session.gd      What one scene tells the next, and the player's progress
tests/
```

Three ideas hold it together.

**Every stroke goes through `SpellCircle.strike()`.** The keyboard, an NPC, a test and a player on another machine all make strokes the same way and are judged by the same code.

**Spells, opponents and campaigns are data.** Each is a resource in a file. Nothing about a particular spell is written in code.

**The rules have no nodes behind them.** `Duelist`, `CastScorer` and `SpellResolver` are plain objects and pure functions. Time passes only when `advance()` is called, so a whole duel can be played out in a test, or simulated thirty times to try the balance of an opponent.

### Adding a spell

In the editor:

1. Add a node with the `ExpectedTrain` script to a scene. Its origin is the centre of the spell circle.
2. Add runes under it (`engine/components/runes/*.tscn`), place them, and set each one's **Unscaled Ticks**. The first is on tick 0 and each later one on a later tick.
3. Set **Spell Path** to `res://magiteknician/spells/<id>.tres` and press **Save runes to spell file**.
4. Open the new `.tres` and give it a name, a description, a school, a rank, a chi cost and its effects.

The spell is now in the library and shows up in the practice range. To put it in the campaign, add its id to a stage's rewards or to an opponent's spells.

A spell wants at least three strokes. Any two points fit a line, so a spell of two strokes cannot be off the beat.

### Adding an opponent

Duplicate a file in `magiteknician/opponents/` and change it. What makes an opponent hard is mostly two numbers in its profile: **Timing Error**, the jitter of its strokes around the beat in ticks, and **Usec Per Tick**, its tempo. An opponent is never told how well to cast. It is given hands, and how well it casts follows.

| Timing error | Fire Bolt most often comes out | Mean potency |
| :- | :- | :- |
| 0.02 | S (85% of casts) | 97% |
| 0.06 | A (58%) | 91% |
| 0.10 | B (42%) | 82% |
| 0.16 | C (40%) | 67% |

`DuelSimulation` plays duels between two opponents with nobody at the keyboard. Use it to see how a new opponent fares before anyone has to play them.

![The campaign menu](docs/images/campaign.png)

## The world

The runes, the spells and the people are from *Another Sorcerer's Root*. The campaign is the sparring match of its fifth chapter, seen from the visitors' side: every few years the rune crafters of Ännerung Academy send a delegation to spar with the mages of Gratiswiesel, and they have never won.

| Rune | Name | In a spell it |
| :- | :- | :- |
| ρ | Flow | pushes, throws, gives a direction |
| δ | Development | builds up, combines |
| λ | Decay | breaks down, chills |
| θ | Refraction | turns aside, bends light |
| κ | Persistence | makes an effect last |
| σ | Variability | evaluates a gaussian, centred on intention |
| φ | Equivalence | reads or rewrites a state |

## What is not done

- No spell uses φ yet.
- The numbers have been tuned by simulation and not yet by people.
- Timing is read once a frame, so it is good to about 16 ms at 60 frames a second.
- The options menu has a Back button and nothing else.
- Versus has no list of hosts, no rematch, and a fixed port.
