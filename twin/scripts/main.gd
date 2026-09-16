extends Node3D

func _ready() -> void:
	_convert_pots_to_multimesh()

# The 30 pots under PivotArmario/Armario/Pots are identical scene instances,
# each costing its own draw call. This merges them into one (or a few, if the
# pot scene has more than one mesh part) MultiMeshInstance3D at runtime, using
# each part's engine-resolved global_transform so no matrix math is hand-authored.
func _convert_pots_to_multimesh() -> void:
	var pots := get_node_or_null("PivotArmario/Armario/Pots") as Node3D
	if pots == null or pots.get_child_count() < 2:
		return

	var pot_instances := pots.get_children()
	var groups := {}
	var pots_inverse := pots.global_transform.affine_inverse()

	for pot in pot_instances:
		for mi in _get_mesh_instances(pot):
			if mi.mesh == null:
				continue
			var key := str(pot.get_path_to(mi))
			var surface_count := mi.mesh.get_surface_count()
			if not groups.has(key):
				groups[key] = {"mesh": mi.mesh, "surface_count": surface_count, "surface_overrides": {}, "conflict": false, "transforms": []}
			var group: Dictionary = groups[key]
			var surface_overrides: Dictionary = group["surface_overrides"]
			for s in surface_count:
				var mat := mi.get_surface_override_material(s)
				# Every pot instance shares the same template, so the same surface
				# should always report the same override; if it doesn't, something
				# genuinely varies per-instance and we must not collapse it.
				if surface_overrides.has(s) and surface_overrides[s] != mat:
					group["conflict"] = true
				else:
					surface_overrides[s] = mat
			group["transforms"].append(pots_inverse * mi.global_transform)

	if groups.is_empty():
		return

	# MultiMeshInstance3D only takes one material_override for the whole part
	# (no per-surface overrides like MeshInstance3D). Only safe to apply when
	# a single material is overridden identically across every surface.
	for key in groups:
		var group: Dictionary = groups[key]
		var surface_overrides: Dictionary = group["surface_overrides"]
		var distinct_materials := {}
		for s in surface_overrides:
			var mat = surface_overrides[s]
			if mat != null:
				distinct_materials[mat] = true
		var ok: bool = (not (group["conflict"] as bool)) and distinct_materials.size() <= 1
		if ok and distinct_materials.size() == 1 and surface_overrides.size() != group["surface_count"]:
			ok = false
		if not ok:
			push_warning("No se pudo optimizar Pots con MultiMesh: '%s' tiene materiales por superficie mixtos." % key)
			return
		group["override"] = null
		if distinct_materials.size() == 1:
			group["override"] = distinct_materials.keys()[0]

	for pot in pot_instances:
		pot.queue_free()

	var group_index := 0
	for key in groups:
		var group: Dictionary = groups[key]
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = group["mesh"]
		mm.instance_count = group["transforms"].size()
		for i in group["transforms"].size():
			mm.set_instance_transform(i, group["transforms"][i])

		var mmi := MultiMeshInstance3D.new()
		mmi.name = "PotsMultiMesh_%d" % group_index
		mmi.multimesh = mm
		if group["override"] != null:
			mmi.material_override = group["override"]
		pots.add_child(mmi)
		group_index += 1

	print("Pots optimizados: %d instancias -> %d MultiMeshInstance3D" % [pot_instances.size(), groups.size()])

func _get_mesh_instances(node: Node) -> Array[MeshInstance3D]:
	var result: Array[MeshInstance3D] = []
	if node is MeshInstance3D:
		result.append(node)
	for child in node.get_children():
		result.append_array(_get_mesh_instances(child))
	return result
