extends Node3D

@export var open_angle: float = 110
@export var duration: float = 0.5

var is_open: bool = false
var tween: Tween
var closed_rotation: Vector3

func _ready():
	closed_rotation = rotation

func _open_door() -> void:
	is_open = !is_open
	var target = closed_rotation
	if is_open:
		target.y = closed_rotation.y + deg_to_rad(open_angle)

	if tween:
		tween.kill()

	tween = create_tween()
	tween.tween_property(self, "rotation", target, duration)\
		.set_ease(Tween.EASE_IN_OUT)\
		.set_trans(Tween.TRANS_CUBIC)

func _on_input_puerta_derecha_input_event(_camera: Node, event: InputEvent, _event_position: Vector3, _normal: Vector3, _shape_idx: int) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			_open_door()
