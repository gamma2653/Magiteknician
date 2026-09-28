class_name DuelSimulation
extends Node
## Plays duels between two NPCs with nobody at the keyboard and no clock
## but its own. It answers questions of balance: can a caster this steady
## beat that opponent, and how long does it take them?
##
## A simulation needs to be in the scene tree, because spell circles are
## nodes. It frees everything it makes. Its methods are coroutines: a duel
## queues a great many redraws and frees, and the engine only gets to deal
## with them between frames.

## The length of one step of simulated time, in seconds.
const STEP_SECONDS := 1.0 / 30.0
## A duel that has not ended after this long is called a draw.
const TIME_LIMIT_SECONDS := 240.0
## Simulated seconds played between one frame and the next.
const SECONDS_PER_FRAME := 20.0


## The outcome of a run of duels.
class Tally:
	var duels: int = 0
	var wins: int = 0
	var losses: int = 0
	var draws: int = 0
	var total_seconds: float = 0.0

	func win_rate() -> float:
		return 0.0 if duels == 0 else float(wins) / duels

	func mean_seconds() -> float:
		return 0.0 if duels == 0 else total_seconds / duels

	func _to_string() -> String:
		return "%d won, %d lost, %d drawn, %.0f s a duel" % [wins, losses, draws, mean_seconds()]


## Plays one duel between `challenger` and `opponent` and returns it,
## finished or timed out. The caller frees the duel, which frees the rest.
func play(challenger: Opponent, opponent: Opponent, rng_seed: int) -> Duel:
	var duel := Duel.new()
	add_child(duel)
	duel.set_process(false)

	var circles: Array[SpellCircle] = []
	var casters: Array[NpcCaster] = []
	for side in [challenger, opponent]:
		var circle := SpellCircle.new()
		duel.add_child(circle)
		circle.set_process(false)
		# Nobody is watching, so there is nothing to draw.
		circle.hide()
		circles.append(circle)
		var caster := NpcCaster.new()
		duel.add_child(caster)
		caster.profile = side.profile
		# Each side draws from its own sequence, so changing one side's
		# spells does not change the other side's luck.
		caster.rng.seed = hash([rng_seed, casters.size()])
		casters.append(caster)

	duel.setup(challenger.make_duelist(), opponent.make_duelist(), circles[0], circles[1], casters[1], casters[0])
	duel.begin()
	var steps := ceili(TIME_LIMIT_SECONDS / STEP_SECONDS)
	var steps_per_frame := ceili(SECONDS_PER_FRAME / STEP_SECONDS)
	for step in steps:
		if duel.is_over():
			break
		duel.advance(STEP_SECONDS)
		if step % steps_per_frame == steps_per_frame - 1:
			await get_tree().process_frame
	return duel


## Plays `count` duels and tallies them from the challenger's side.
func play_many(challenger: Opponent, opponent: Opponent, count: int, first_seed: int = 1) -> Tally:
	var tally := Tally.new()
	for i in count:
		var duel: Duel = await play(challenger, opponent, first_seed + i)
		tally.duels += 1
		tally.total_seconds += duel.elapsed_seconds
		if not duel.is_over():
			tally.draws += 1
		elif duel.player_won():
			tally.wins += 1
		else:
			tally.losses += 1
		remove_child(duel)
		duel.queue_free()
		await get_tree().process_frame
	return tally
