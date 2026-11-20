class_name GameFlow
extends Node
## Main scene. Owns the run rules (RunState, PlayerStats, PerkDeck), instantiates the level and wires it to the UI.
## World and UI never talk to each other directly. See ADR feature-folder-module-layout.

signal run_started
signal run_ended(outcome: RunState.Outcome)

@export var level_scene: PackedScene
@export var run_config: RunConfig
@export var player_config: PlayerConfig
@export var perk_pool: PerkPool
## Skip the title screen (used by tests and quick iteration).
@export var auto_start: bool = false
## Fixed RNG seed for reproducible runs; 0 = random.
@export var seed_value: int = 0

@onready var hud: Hud = $Hud
@onready var perk_select: PerkSelect = $PerkSelect
@onready var title_screen: TitleScreen = $TitleScreen
@onready var end_screen: EndScreen = $EndScreen
@onready var level_slot: Node = $LevelSlot

var run: RunState
var stats: PlayerStats
var deck: PerkDeck
var level: Level
var rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _hand: Array[Perk] = []


func _ready() -> void:
	title_screen.start_requested.connect(start_run)
	end_screen.restart_requested.connect(start_run)
	perk_select.perk_chosen.connect(_on_perk_chosen)
	perk_select.redraw_requested.connect(_on_redraw)
	perk_select.skipped.connect(_on_skip)
	hud.visible = false
	if auto_start:
		start_run.call_deferred()


func start_run() -> void:
	_clear_level()
	get_tree().paused = false
	title_screen.visible = false
	end_screen.visible = false
	perk_select.close()
	if seed_value != 0:
		rng.seed = seed_value
	else:
		rng.randomize()
	run = RunState.new(run_config)
	stats = PlayerStats.new(player_config)
	var perks: Array[Perk] = perk_pool.perks if perk_pool != null else ([] as Array[Perk])
	var deck_rng: RandomNumberGenerator = RandomNumberGenerator.new()
	deck_rng.seed = rng.randi()
	deck = PerkDeck.new(perks, deck_rng)
	_connect_run()
	level = level_scene.instantiate() as Level
	level_slot.add_child(level)
	_connect_level()
	level.start(stats, run.config, rng, func() -> float: return run.elapsed)
	hud.visible = true
	_refresh_hud()
	hud.show_banner("DAY %d\nKILL ZOMBIES TO GET XP AND UPGRADE YOUR CHARACTER" % run.config.day_number, 5.0)
	run_started.emit()


func _process(delta: float) -> void:
	if run == null or run.is_over() or get_tree().paused:
		return
	run.tick(delta)


func _connect_run() -> void:
	run.time_changed.connect(hud.set_time)
	run.gears_changed.connect(_on_gears_changed)
	run.xp_changed.connect(hud.set_xp)
	run.kills_changed.connect(hud.set_kills)
	run.level_up_pending.connect(_on_level_up_pending)
	run.ended.connect(_on_run_ended)


func _connect_level() -> void:
	level.zombie_killed.connect(_on_zombie_killed)
	level.gear_collected.connect(run.add_gear)
	level.player_damaged.connect(func(_a: float) -> void: run.register_damage())
	level.player_health_changed.connect(hud.set_health)
	level.player_stamina_changed.connect(hud.set_stamina)
	level.player_died.connect(func() -> void: run.finish(RunState.Outcome.KILLED))
	level.weapon_changed.connect(hud.set_weapon)
	level.extraction_entered.connect(_on_extraction_entered)
	level.player_sprint_changed.connect(hud.set_sprinting)


func _refresh_hud() -> void:
	hud.set_time(run.time_left)
	hud.set_gears(run.gears, run.config.gears_required)
	hud.set_xp(run.xp, run.xp_needed(), run.level)
	hud.set_kills(run.kills, run.streak)
	hud.set_health(level.player.health.current, level.player.health.max_health)
	hud.set_stamina(level.player.stamina.current, level.player.stamina.max_stamina)
	hud.set_weapon(level.player.weapon.current_weapon().display_name, 0.0)
	hud.set_sprinting(false)


func _on_zombie_killed(xp: float, _at: Vector2) -> void:
	run.register_kill()
	run.add_xp(xp * stats.get_value(PlayerStats.Stat.XP_GAIN))


func _on_gears_changed(have: int, need: int) -> void:
	hud.set_gears(have, need)
	level.set_extraction_unlocked(have >= need)
	if have >= need:
		hud.show_banner("ALL GEARS COLLECTED\nREACH THE HIGH-RISE", 4.0)
	else:
		hud.show_message("GEAR %d/%d" % [have, need])


func _on_extraction_entered() -> void:
	if run.can_extract():
		run.finish(RunState.Outcome.EXTRACTED)
	else:
		hud.show_message("THE HIGH-RISE NEEDS %d MORE GEAR%s" % [run.gears_missing(), "" if run.gears_missing() == 1 else "S"])


# --- Perks -----------------------------------------------------------------

func _perk_context() -> PerkContext:
	return PerkContext.new(run, stats, level.equip_temporary_weapon)


func _on_level_up_pending(_count: int) -> void:
	if not perk_select.is_open() and not run.is_over():
		_deal_hand.call_deferred()


func _deal_hand() -> void:
	if run.is_over() or run.pending_level_ups <= 0:
		return
	_hand = deck.draw_hand(_perk_context(), run.config.hand_size)
	if _hand.is_empty():
		run.consume_level_up()
		return
	get_tree().paused = true
	perk_select.open(_cards_for(_hand), run.redraws_left, run.pending_level_ups)


func _cards_for(perks: Array[Perk]) -> Array[Dictionary]:
	var ctx: PerkContext = _perk_context()
	var cards: Array[Dictionary] = []
	for p: Perk in perks:
		cards.append({
			"category": p.category_name(),
			"title": p.display_name,
			"rare": p.rarity == Perk.Rarity.RARE,
			"lines": p.describe(ctx),
			"flavour": p.flavour,
		})
	return cards


func _on_perk_chosen(index: int) -> void:
	if index < 0 or index >= _hand.size():
		return
	var perk: Perk = _hand[index]
	perk.apply(_perk_context())
	hud.show_message("%s!" % perk.display_name.to_upper())
	_after_choice()


func _on_redraw() -> void:
	if run.use_redraw():
		_hand = deck.draw_hand(_perk_context(), run.config.hand_size)
		perk_select.open(_cards_for(_hand), run.redraws_left, run.pending_level_ups)


func _on_skip() -> void:
	_after_choice()


func _after_choice() -> void:
	run.consume_level_up()
	_hand.clear()
	if run.pending_level_ups > 0 and not run.is_over():
		_deal_hand()
		return
	perk_select.close()
	get_tree().paused = false


# --- End of run ------------------------------------------------------------

func _on_run_ended(outcome: RunState.Outcome) -> void:
	perk_select.close()
	get_tree().paused = true
	var minutes: int = floori(run.elapsed / 60.0)
	var seconds: int = floori(run.elapsed) % 60
	var lines: PackedStringArray = [
		"Time survived: %02d:%02d" % [minutes, seconds],
		"Gears: %d/%d" % [run.gears, run.config.gears_required],
		"Kills: %d   Best streak: %d" % [run.kills, run.best_streak],
		"Level reached: %d" % run.level,
	]
	match outcome:
		RunState.Outcome.EXTRACTED:
			end_screen.show_result("EXTRACTED", "You made it out before the nuclear makeover.", lines, true)
		RunState.Outcome.NUKED:
			end_screen.show_result("NUKED", "Time ran out. Freedom City got a nuclear makeover.", lines, false)
		_:
			end_screen.show_result("YOU DIED", "Another brain-munching freak joins the horde.", lines, false)
	run_ended.emit(outcome)


func _clear_level() -> void:
	if level != null and is_instance_valid(level):
		level_slot.remove_child(level)
		level.queue_free()
	level = null
