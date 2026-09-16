extends Node3D
@onready var camera_3d: Camera3D = $Camera3D

# — Zoom —
@export var zoom_speed: float = 1.0
@export var min_fov: float = 20.0
@export var max_fov: float = 90.0
@export var zoom_tween_duration: float = 0.2
@export var pinch_zoom_speed: float = 0.1

# — Órbita —
@export var orbit_speed: float = 0.3

# — Snap de vistas —
@export var snap_tween_duration: float = 0.4


@export var zoom_offset_strength: float = 0.3  # cuánto se desplaza verticalmente


var zoom_tween: Tween
var snap_tween: Tween
var is_dragging: bool = false
var last_touch_positions: Dictionary = {}
var last_pinch_distance: float = 0.0

# Yaw / Pitch en grados para cada vista
# Vector2(yaw, pitch)  → rotación del Pivot
const VIEWS := {
	KEY_1: Vector2(0.0,   0),   # frontal
	KEY_2: Vector2(90.0,  0),   # lateral izquierda
	KEY_3: Vector2(-90.0, 0),   # lateral derecha
	KEY_4: Vector2(180.0, 0),   # trasera
	KEY_5: Vector2(0.0,   -89.0),   # superior
}

func _ready():
	pass

func _input(event):
	# — Snap de vistas con teclado numérico —
	if event is InputEventKey and event.pressed and not event.echo:
		if VIEWS.has(event.keycode):
			_snap_to_view(VIEWS[event.keycode])

	# — Desktop: zoom con rueda —
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_tween_zoom(-zoom_speed)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_tween_zoom(zoom_speed)
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			is_dragging = event.pressed

	# — Desktop: órbita con click derecho —
	if event is InputEventMouseMotion and is_dragging:
		_orbit(event.relative.x, event.relative.y)

	# — Mobile: touch —
	if event is InputEventScreenTouch:
		if event.pressed:
			last_touch_positions[event.index] = event.position
		else:
			last_touch_positions.erase(event.index)
			last_pinch_distance = 0.0

	if event is InputEventScreenDrag:
		last_touch_positions[event.index] = event.position
		if last_touch_positions.size() == 1:
			_orbit(event.relative.x, event.relative.y)
		elif last_touch_positions.size() == 2:
			var positions = last_touch_positions.values()
			var current_distance = positions[0].distance_to(positions[1])
			if last_pinch_distance > 0.0:
				var delta = current_distance - last_pinch_distance
				_tween_zoom(-delta * pinch_zoom_speed)
			last_pinch_distance = current_distance

func _orbit(dx: float, dy: float):
	rotate_y(deg_to_rad(-dx * orbit_speed))
	rotate_object_local(Vector3.RIGHT, deg_to_rad(-dy * orbit_speed))

func _snap_to_view(target: Vector2):
	# target.x = yaw final, target.y = pitch final (en grados)
	if snap_tween:
		snap_tween.kill()
	snap_tween = create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	snap_tween.tween_property(
		self, "rotation_degrees",
		Vector3(target.y, target.x, 0.0),
		snap_tween_duration
	)

func _tween_zoom(delta_fov: float):
	var target_fov = clamp(camera_3d.fov + delta_fov, min_fov, max_fov)
	if zoom_tween:
		zoom_tween.kill()
	zoom_tween = create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	zoom_tween.tween_property(camera_3d, "fov", target_fov, zoom_tween_duration)
