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
@export_group("Graphics")
## Used on desktop.
@export var desktop_graphics: GraphicsProfile
## Used in mobile browsers (Android/iOS web) and on touch-only web devices.
@export var mobile_graphics: GraphicsProfile
## Use the mobile profile everywhere (to test the phone look on a PC).
@export var force_mobile_graphics: bool = false
@export_group("")

@onready var hud: Hud = $Hud
@onready var perk_select: PerkSelect = $PerkSelect
@onready var title_screen: TitleScreen = $TitleScreen
@onready var end_screen: EndScreen = $EndScreen
@onready var level_slot: Node = $LevelSlot
@onready var touch_controls: TouchControls = $TouchControls
@onready var sfx: SfxPlayer = $SfxPlayer
@onready var music: MusicPlayer = $MusicPlayer
@onready var error_console: ErrorConsole = $ErrorConsole

var run: RunState
var stats: PlayerStats
var deck: PerkDeck
var level: Level
var rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _hand: Array[Perk] = []
var _runs_started: int = 0
var graphics: GraphicsProfile


func _ready() -> void:
	title_screen.start_requested.connect(_begin_run)
	graphics = _pick_graphics()
	end_screen.restart_requested.connect(start_run)
	perk_select.perk_chosen.connect(_on_perk_chosen)
	perk_select.redraw_requested.connect(_on_redraw)
	perk_select.skipped.connect(_on_skip)
	touch_controls.sprint_pressed.connect(_on_touch_sprint)
	title_screen.start_requested.connect(_play.bind(sfx.bank.run_start))
	touch_controls.first_touch.connect(func() -> void: touch_controls.set_gameplay_active(_gameplay_active()))
	touch_controls.set_gameplay_active(false)
	hud.visible = false
	if auto_start:
		start_run.call_deferred()


## From the title: let the "LOADING..." frame draw before the heavy level build.
func _begin_run() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	start_run()


func _pick_graphics() -> GraphicsProfile:
	var mobile_web: bool = OS.has_feature("web_android") or OS.has_feature("web_ios")
	var touch_web: bool = OS.has_feature("web") and DisplayServer.is_touchscreen_available()
	var mobile: bool = force_mobile_graphics or mobile_web or touch_web
	var profile: GraphicsProfile = mobile_graphics if mobile else desktop_graphics
	if profile == null:
		profile = GraphicsProfile.new()
	return profile


func start_run() -> void:
	_clear_level()
	_set_paused(false)
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
	if graphics != null:
		level.apply_graphics(graphics)
		get_viewport().scaling_3d_scale = graphics.render_scale
	hud.visible = true
	music.play_music()
	_refresh_hud()
	_runs_started += 1
	hud.show_banner("DAY %d\nKILL ZOMBIES TO GET XP AND UPGRADE YOUR CHARACTER" % (run.config.day_number + _runs_started - 1), 5.0)
	touch_controls.set_gameplay_active(_gameplay_active())
	run_started.emit()


func _on_touch_sprint() -> void:
	if level != null:
		level.toggle_sprint()


func _process(delta: float) -> void:
	if run == null or run.is_over() or get_tree().paused:
		return
	level.set_touch_input(touch_controls.move_vector, touch_controls.aim_vector, touch_controls.is_touching())
	run.tick(delta)


func _gameplay_active() -> bool:
	return run != null and not run.is_over() and not get_tree().paused


func _set_paused(paused: bool) -> void:
	get_tree().paused = paused
	touch_controls.set_gameplay_active(_gameplay_active())


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
	_connect_level_sfx()
	level.player_sprint_changed.connect(hud.set_sprinting)


func _connect_level_sfx() -> void:
	var bank: SfxBank = sfx.bank
	level.player_fired.connect(func(w: WeaponData) -> void: sfx.play_cue(w.fire_sound))
	level.zombie_hit.connect(_play.bind(bank.zombie_hit))
	level.zombie_killed.connect(func(_xp: float, _at: Vector3) -> void: sfx.play_cue(bank.zombie_die))
	level.player_damaged.connect(func(_a: float) -> void: sfx.play_cue(bank.player_hurt))
	level.gear_collected.connect(_play.bind(bank.pickup_gear))
	level.health_collected.connect(_play.bind(bank.pickup_health))
	level.prop_destroyed.connect(func(_at: Vector3, explosive: bool) -> void: sfx.play_cue(bank.prop_explode if explosive else bank.prop_break))


func _play(cue: SfxCue) -> void:
	sfx.play_cue(cue)


func _refresh_hud() -> void:
	hud.set_time(run.time_left)
	hud.set_gears(run.gears, run.config.gears_required)
	hud.set_xp(run.xp, run.xp_needed(), run.level)
	hud.set_kills(run.kills, run.streak)
	hud.set_health(level.player.health.current, level.player.health.max_health)
	hud.set_stamina(level.player.stamina.current, level.player.stamina.max_stamina)
	hud.set_weapon(level.player.weapon.current_weapon().display_name, 0.0)
	hud.set_sprinting(false)


func _on_zombie_killed(xp: float, _at: Vector3) -> void:
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
		sfx.play_cue(sfx.bank.extraction_denied)
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
	_set_paused(true)
	sfx.play_cue(sfx.bank.level_up)
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
	sfx.play_cue(sfx.bank.perk_pick)
	hud.show_message("%s!" % perk.display_name.to_upper())
	_after_choice()


func _on_redraw() -> void:
	if run.use_redraw():
		sfx.play_cue(sfx.bank.perk_redraw)
		_hand = deck.draw_hand(_perk_context(), run.config.hand_size)
		perk_select.open(_cards_for(_hand), run.redraws_left, run.pending_level_ups)


func _on_skip() -> void:
	sfx.play_cue(sfx.bank.perk_skip)
	_after_choice()


func _after_choice() -> void:
	run.consume_level_up()
	_hand.clear()
	if run.pending_level_ups > 0 and not run.is_over():
		_deal_hand()
		return
	perk_select.close()
	_set_paused(false)


# --- End of run ------------------------------------------------------------

func _on_run_ended(outcome: RunState.Outcome) -> void:
	music.stop_music()
	perk_select.close()
	_set_paused(true)
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
			sfx.play_cue(sfx.bank.run_extracted)
			end_screen.show_result("EXTRACTED", "You made it out before the nuclear makeover.", lines, true)
		RunState.Outcome.NUKED:
			sfx.play_cue(sfx.bank.run_nuked)
			end_screen.show_result("NUKED", "Time ran out. Freedom City got a nuclear makeover.", lines, false)
		_:
			sfx.play_cue(sfx.bank.run_killed)
			end_screen.show_result("YOU DIED", "Another brain-munching freak joins the horde.", lines, false)
	run_ended.emit(outcome)


func _clear_level() -> void:
	if level != null and is_instance_valid(level):
		level_slot.remove_child(level)
		level.queue_free()
	level = null
