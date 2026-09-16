extends Node3D

@export var orbit_speed: float = 0.3

var is_dragging: bool = false

func _input(event):
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		is_dragging = event.pressed

	if event is InputEventMouseMotion and is_dragging:
		rotate(Vector3.UP, deg_to_rad(-event.relative.x * orbit_speed))
		rotate(transform.basis.x.normalized(), deg_to_rad(-event.relative.y * orbit_speed))
