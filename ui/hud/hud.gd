class_name Hud
extends CanvasLayer
## Heads-up display laid out like the original: portrait, level badge and bars top-left with the kill streak below,
## countdown top centre, gears and weapon panel top-right. Pure view: game flow pushes values in.

## Streaks below this are not shown.
@export_range(1, 50) var streak_min_shown: int = 5

@onready var _health_bar: ProgressBar = %HealthBar
@onready var _stamina_bar: ProgressBar = %StaminaBar
@onready var _xp_bar: ProgressBar = %XpBar
@onready var _level_badge: Label = %LevelBadge
@onready var _xp_level: Label = %XpLevel
@onready var _timer_label: Label = %TimerLabel
@onready var _gear_label: Label = %GearLabel
@onready var _streak_box: Control = %StreakBox
@onready var _streak_number: Label = %StreakNumber
@onready var _weapon_label: Label = %WeaponLabel
@onready var _weapon_time: Label = %WeaponTime
@onready var _message_label: Label = %MessageLabel
@onready var _banner_label: Label = %BannerLabel
@onready var _objective_label: Label = %ObjectiveLabel

var _message_time: float = 0.0
var _banner_time: float = 0.0
var _stamina_style: StyleBoxFlat


func _ready() -> void:
	_stamina_style = (_stamina_bar.get_theme_stylebox("fill") as StyleBoxFlat).duplicate() as StyleBoxFlat
	_stamina_bar.add_theme_stylebox_override("fill", _stamina_style)
	_streak_box.visible = false


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


func set_stamina(current: float, maximum: float) -> void:
	_stamina_bar.max_value = maximum
	_stamina_bar.value = current


func set_sprinting(on: bool) -> void:
	_stamina_style.bg_color = Color(1.0, 0.95, 0.45) if on else Color(0.9, 0.78, 0.15)


func set_xp(xp: int, needed: int, level: int) -> void:
	_xp_bar.max_value = needed
	_xp_bar.value = xp
	_level_badge.text = "LV\n%d" % level
	_xp_level.text = "LV.%d" % (level + 1)


func set_time(seconds_left: float) -> void:
	var s: int = ceili(seconds_left)
	_timer_label.text = "%02d:%02d" % [s / 60, s % 60]
	_timer_label.modulate = Color(1, 0.3, 0.3) if seconds_left < 60.0 else Color.WHITE


func set_gears(have: int, need: int) -> void:
	_gear_label.text = "%d/%d" % [have, need]
	_objective_label.text = "REACH THE HIGH-RISE" if have >= need else "COLLECT %d GEARS" % need


func set_kills(_kills: int, streak: int) -> void:
	_streak_box.visible = streak >= streak_min_shown
	_streak_number.text = str(streak)


func set_weapon(weapon_name: String, seconds_left: float) -> void:
	_weapon_label.text = weapon_name.to_upper()
	_weapon_time.text = "%ds" % ceili(seconds_left) if seconds_left > 0.0 else ""


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
