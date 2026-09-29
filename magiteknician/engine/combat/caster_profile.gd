@tool
class_name CasterProfile
extends Resource
## How an NPC casts: how fast, how steadily, and what it reaches for.
##
## An NPC is not given a quality to cast at. It is given hands, with jitter
## in them, and its strokes are judged by the same scorer as the player's.
## How good it is follows from how steady its hands are.

@export_group("Hands")
## Length of one tick at the tempo this caster likes, in microseconds.
## Smaller is faster.
@export_range(80_000, 1_500_000, 5_000) var usec_per_tick: int = 420_000
## How much the tempo varies from one cast to the next, as a share of it.
@export_range(0.0, 0.5, 0.01) var tempo_spread: float = 0.08
## Spread of each stroke around the beat, in ticks. This is the jitter of
## the caster's spike train, and it decides how well they cast.
@export_range(0.0, 0.5, 0.005) var timing_error: float = 0.1
## Spread of each stroke around the centre of its rune, as a share of the
## rune's radius.
@export_range(0.0, 1.0, 0.01) var aim_error: float = 0.35
## Chance that any one stroke is preceded by a stray.
@export_range(0.0, 1.0, 0.01) var stray_chance: float = 0.03
## Chance that the caster goes on in the beat of their last cast, where
## they have one: at the same tempo, and beginning on a beat. They are as
## steady about the beat they begin on as about any other. See Cadence.
@export_range(0.0, 1.0, 0.01) var cadence: float = 0.0

@export_group("Mind")
## Shortest and longest pause between one cast and the next, in seconds.
@export_range(0.0, 10.0, 0.05) var think_seconds_min: float = 0.8
@export_range(0.0, 10.0, 0.05) var think_seconds_max: float = 1.6
## How readily the caster wards when it sees an attack coming. 0 never
## bothers; 1 nearly always does.
@export_range(0.0, 1.0, 0.01) var caution: float = 0.5
## The caster looks to heal once its health falls below this share.
@export_range(0.0, 1.0, 0.01) var heal_below: float = 0.4


static func make(
	usec_per_tick_: int,
	timing_error_: float,
	aim_error_: float = 0.35,
	stray_chance_: float = 0.03
) -> CasterProfile:
	var profile := CasterProfile.new()
	profile.usec_per_tick = usec_per_tick_
	profile.timing_error = timing_error_
	profile.aim_error = aim_error_
	profile.stray_chance = stray_chance_
	return profile
