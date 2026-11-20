class_name Hud
extends CanvasLayer
## Heads-up display. Pure view: game flow pushes values in.

@onready var _health_bar: ProgressBar = %HealthBar
@onready var _stamina_bar: ProgressBar = %StaminaBar
@onready var _xp_bar: ProgressBar = %XpBar
@onready var _level_label: Label = %LevelLabel
@onready var _timer_label: Label = %TimerLabel
@onready var _gear_label: Label = %GearLabel
@onready var _streak_label: Label = %StreakLabel
@onready var _weapon_label: Label = %WeaponLabel
@onready var _message_label: Label = %MessageLabel
@onready var _banner_label: Label = %BannerLabel
@onready var _objective_label: Label = %ObjectiveLabel
@onready var _sprint_label: Label = %SprintLabel

var _message_time: float = 0.0
var _banner_time: float = 0.0


func _process(delta: float) -> void:
	if _message_time > 0.0:
		_message_time -= delta
		_message_label.modulate.a = clampf(_message_time, 0.0, 1.0)
	if _banner_time > 0.0:
		_banner_time -= delta
		_banner_label.modulate.a = clampf(_banner_time, 0.0, 1.0)


func set_health(current: float, maximum: float) -> void:
	_health_bar.max_value = maximum
	_health_bar.value = current
	(_health_bar.get_node("Text") as Label).text = "%d / %d" % [ceili(current), roundi(maximum)]


func set_stamina(current: float, maximum: float) -> void:
	_stamina_bar.max_value = maximum
	_stamina_bar.value = current


func set_sprinting(on: bool) -> void:
	_sprint_label.text = "SPRINT ON" if on else ""


func set_xp(xp: int, needed: int, level: int) -> void:
	_xp_bar.max_value = needed
	_xp_bar.value = xp
	_level_label.text = "LV %d" % level


func set_time(seconds_left: float) -> void:
	var s: int = ceili(seconds_left)
	_timer_label.text = "%02d:%02d" % [s / 60, s % 60]
	_timer_label.modulate = Color(1, 0.3, 0.3) if seconds_left < 60.0 else Color.WHITE


func set_gears(have: int, need: int) -> void:
	_gear_label.text = "⚙ %d/%d" % [have, need]
	_objective_label.text = "REACH THE HIGH-RISE" if have >= need else "COLLECT %d GEARS" % need


func set_kills(kills: int, streak: int) -> void:
	_streak_label.text = "KILLS %d   STREAK %d" % [kills, streak]


func set_weapon(weapon_name: String, seconds_left: float) -> void:
	if seconds_left > 0.0:
		_weapon_label.text = "%s  %ds" % [weapon_name.to_upper(), ceili(seconds_left)]
	else:
		_weapon_label.text = weapon_name.to_upper()


func show_message(text: String, seconds: float = 2.5) -> void:
	_message_label.text = text
	_message_time = seconds
	_message_label.modulate.a = 1.0


func show_banner(text: String, seconds: float = 4.0) -> void:
	_banner_label.text = text
	_banner_time = seconds
	_banner_label.modulate.a = 1.0


func message_text() -> String:
	return _message_label.text if _message_time > 0.0 else ""
