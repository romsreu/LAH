extends Node3D

@onready var helix_fan: Node3D = $HelixFan

var spin_speed := 5.0

func _process(delta: float) -> void:
	helix_fan.rotate_y(spin_speed * delta)

func fan_on() -> void:
	set_process(true)

func fan_off() -> void:
	set_process(false)

func _ready() -> void:
	set_process(true)  
