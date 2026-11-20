class_name GraphicsProfile
extends Resource
## Rendering budget for a class of device. Game flow picks one at start (mobile browsers get the cheap one)
## and the level applies it. Tune in the Inspector.

@export var display_name: String = "Desktop"
## Sun/moon shadow maps.
@export var shadows: bool = true
@export var glow: bool = true
@export var fog: bool = true
## 3D resolution relative to the window (UI stays sharp). 0.5 = half resolution.
@export_range(0.25, 1.0, 0.05) var render_scale: float = 1.0
## How many static lights (lamps, neon, fires, car beams) stay on, nearest to the player first. 0 = no limit.
@export_range(0, 128) var max_static_lights: int = 0
## Seconds between re-picking the nearest static lights.
@export_range(0.05, 2.0, 0.05) var light_refresh_seconds: float = 0.3
