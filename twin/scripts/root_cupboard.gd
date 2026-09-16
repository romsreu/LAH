extends Node3D

@onready var part_17: MeshInstance3D = $"Sistema/occurrence of Part 17/Part 17" # depósito principal
@onready var part_119: MeshInstance3D = $"Sistema/occurrence of Part 119/Part 119" # mini depósitos

var deposito_principal_transparente := false
var mini_depositos_transparentes := false

func _input(event):
	if event is InputEventKey and event.pressed and not event.echo:
		
		if event.keycode == KEY_T:
			toggle_deposito_principal()
		
		if event.keycode == KEY_Y:
			toggle_mini_depositos()


func toggle_deposito_principal():
	deposito_principal_transparente = !deposito_principal_transparente

	set_material_alpha(
		part_17.get_surface_override_material(38),
		0.5 if deposito_principal_transparente else 1.0
	)


func toggle_mini_depositos():
	mini_depositos_transparentes = !mini_depositos_transparentes

	set_material_alpha(
		part_119.get_surface_override_material(16),
		0.5 if mini_depositos_transparentes else 1.0
	)


func set_material_alpha(material: Material, alpha: float):
	if material == null:
		return

	if material is StandardMaterial3D:
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA

		var color = material.albedo_color
		color.a = alpha
		material.albedo_color = color
