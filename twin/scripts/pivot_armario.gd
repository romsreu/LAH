extends Node3D

@export var orbit_speed: float = 0.3
@export var zoom_speed: float = 0.01
@export var min_zoom: float = 0.3
@export var max_zoom: float = 1.5

var is_dragging: bool = false
var last_touch_positions: Dictionary = {}
var last_pinch_distance: float = 0.0

func _input(event):
	# — Desktop (mouse) —
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT:
		is_dragging = event.pressed

	if event is InputEventMouseMotion and is_dragging:
		_apply_rotation(event.relative.x, event.relative.y)

	# — Mobile (touch) —
	if event is InputEventScreenTouch:
		if event.pressed:
			last_touch_positions[event.index] = event.position
		else:
			last_touch_positions.erase(event.index)
			last_pinch_distance = 0.0

	if event is InputEventScreenDrag:
		last_touch_positions[event.index] = event.position
		if last_touch_positions.size() == 1:
			_apply_rotation(event.relative.x, event.relative.y)
		elif last_touch_positions.size() == 2:
			var positions = last_touch_positions.values()
			var current_distance = positions[0].distance_to(positions[1])
			if last_pinch_distance > 0.0:
				var delta = current_distance - last_pinch_distance
				_apply_zoom(delta * zoom_speed)
			last_pinch_distance = current_distance

func _apply_rotation(dx: float, dy: float):
	# Yaw en eje Y global → rotación horizontal consistente
	rotate_y(deg_to_rad(dx * orbit_speed))
	# Pitch en eje X local → después del yaw coincide con el horizontal de pantalla
	rotate_object_local(Vector3.RIGHT, deg_to_rad(dy * orbit_speed))

func _apply_zoom(amount: float):
	var new_scale = scale.x + amount
	new_scale = clamp(new_scale, min_zoom, max_zoom)
	scale = Vector3.ONE * new_scale
