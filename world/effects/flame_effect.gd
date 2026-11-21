class_name FlameEffect
extends Node3D
## A looping fire: flame tongues, rising embers and a little smoke (three child VfxBurst loops, tune each in the
## Inspector). The particles pause while the fire is off screen so a street full of fires costs almost nothing.

## Stop emitting while no camera sees the fire.
@export var pause_off_screen: bool = true

@onready var _notifier: VisibleOnScreenNotifier3D = $VisibleOnScreenNotifier3D


func _ready() -> void:
	if pause_off_screen:
		_notifier.screen_entered.connect(_set_emitting.bind(true))
		_notifier.screen_exited.connect(_set_emitting.bind(false))


func _set_emitting(on: bool) -> void:
	for child: Node in get_children():
		var burst: VfxBurst = child as VfxBurst
		if burst != null:
			burst.emitting = on
