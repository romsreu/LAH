extends RefCounted

# Look "técnico" de la simulación, parecido al sistema real y al render de
# Onshape: materiales limpios con los colores reales, luz neutra y líneas
# oscuras sobre las aristas de cada pieza (shaders/contornos.gdshader).
#
# El gabinete viene de Onshape: cada pieza trae un material cuyo color es el
# que se le asignó en el CAD. Acá se toma ese color original (no el override
# de la escena) y se lo reemplaza por el material real correspondiente.
# Se llama desde main.gd al arrancar.

# Color de Onshape (lineal, como está en el glTF) -> clave de material
const ONSHAPE := [
	[Color(0.600, 0.580, 0.529), "gabinete"],
	[Color(0.502, 0.486, 0.439), "gabinete_sombra"],
	[Color(0.263, 0.282, 0.302), "manguera"],
	[Color(0.918, 0.918, 0.918), "pvc"],
	[Color(0.902, 0.902, 0.902), "pvc"],
	[Color(0.702, 0.702, 0.702), "gris"],
	[Color(0.400, 0.400, 0.400), "soporte"],  # soporte blanco de los reservorios
	[Color(0.302, 0.302, 0.302), "estante"],  # en Onshape oscuros, en el real beige
	[Color(0.235, 0.235, 0.235), "estante"],
	[Color(0.122, 0.122, 0.122), "negro"],
	[Color(0.000, 0.000, 0.000), "negro"],
	[Color(0.937, 0.278, 0.012), "rojo"],
	[Color(0.596, 0.176, 0.051), "rojo_oscuro"],
	[Color(0.459, 0.106, 0.000), "rojo_oscuro"],
	[Color(0.616, 0.812, 0.929), "manguera"],
	[Color(0.396, 0.518, 1.000), "manguera"],
	[Color(0.086, 0.318, 0.690), "azul"],
]

# Materiales del sistema real (referencia: foto del gabinete)
# [color, rugosidad, metálico]
const PALETA := {
	"gabinete":        [Color(0.62, 0.61, 0.50), 0.60, 0.0],  # chapa pintada beige oliva
	"gabinete_sombra": [Color(0.54, 0.53, 0.44), 0.60, 0.0],
	"estante":         [Color(0.60, 0.59, 0.49), 0.55, 0.0],
	"fondo":           [Color(0.20, 0.20, 0.21), 0.75, 0.0],  # fondo interior gris oscuro
	"pvc":             [Color(0.90, 0.89, 0.86), 0.40, 0.0],  # caños y reservorios
	"soporte":         [Color(0.86, 0.86, 0.84), 0.50, 0.0],
	"gris":            [Color(0.45, 0.45, 0.46), 0.50, 0.0],
	"gris_oscuro":     [Color(0.25, 0.25, 0.26), 0.50, 0.0],
	"negro":           [Color(0.06, 0.06, 0.07), 0.50, 0.0],  # canastitas, ventiladores
	"rojo":            [Color(0.75, 0.06, 0.08), 0.30, 0.0],  # tanque de solución
	"rojo_oscuro":     [Color(0.52, 0.04, 0.05), 0.35, 0.0],
	"manguera":        [Color(0.80, 0.78, 0.60), 0.25, 0.0],  # manguera cristal amarillenta
	"azul":            [Color(0.12, 0.35, 0.75), 0.40, 0.0],
}

# Subárboles que no se tocan (tienen texturas propias) o se fuerzan a un material
const SIN_TOCAR := ["UVLights", "rs942", "PanelControl"]
const FORZAR := {"Fans": "negro", "Pots": "negro"}

# Mangueras de los minitanques al tanque principal (en Onshape tienen el mismo
# color que los estantes): van con material de manguera
const MANGUERAS_ADITIVOS := ["Part 162", "Part 144", "Part 163", "Part 148", "Part 135", "Part 125",
	"Part 14", "Part 138", "Part 130", "Part 117", "Part 153", "Part 150", "Part 141", "Part 128",
	"Part 167", "Part 129"]

# Malla del gabinete: sus caras interiores del fondo van en gris oscuro
const GABINETE := "Part 166"

# Aristas: se dibuja la línea si las caras que se juntan forman más de este ángulo
const ANGULO_ARISTA := 25.0

static var _materiales := {}
static var _cache_aristas := {}
static var _material_lineas: ShaderMaterial


static func aplicar(main: Node3D) -> void:
	var t0 := Time.get_ticks_msec()
	var armario := main.get_node_or_null("PivotArmario/Armario")
	if armario:
		_pintar(armario, "")
		var gabinete := armario.find_child(GABINETE, true, false) as MeshInstance3D
		if gabinete:
			load("res://scripts/panel_control.gd").construir(gabinete, armario)
		_canio_bomba(armario)
	_luz(main)
	print("Look técnico aplicado en %d ms" % (Time.get_ticks_msec() - t0))


static func _pintar(node: Node, forzado: String) -> void:
	var nombre := str(node.name)
	if nombre in SIN_TOCAR or nombre == "Aristas":
		return
	var clave_forzada: String = FORZAR.get(nombre, forzado)
	if node is MeshInstance3D and node.mesh:
		var mesh: Mesh = node.mesh
		for s in mesh.get_surface_count():
			var clave := clave_forzada if clave_forzada != "" else _clave(mesh.surface_get_material(s))
			if nombre == GABINETE and clave.begins_with("gabinete") and _es_fondo(mesh, s):
				clave = "fondo"
			if nombre in MANGUERAS_ADITIVOS and clave_forzada == "":
				clave = "manguera"
			if clave != "":
				node.set_surface_override_material(s, _material(clave))
		# las piezas negras no necesitan líneas (no se verían)
		if clave_forzada == "":
			_agregar_aristas(node)
	for hijo in node.get_children():
		_pintar(hijo, clave_forzada)


# Busca el color de Onshape más cercano; si la pieza tiene textura o un color
# que no es de la tabla, se deja como está.
static func _clave(mat: Material) -> String:
	if not (mat is BaseMaterial3D) or mat.albedo_texture:
		return ""
	# Godot pasa el color del glTF a sRGB al importar; la tabla está en lineal
	var c: Color = mat.albedo_color.srgb_to_linear()
	var mejor := ""
	var dist := 0.08
	for par in ONSHAPE:
		var o: Color = par[0]
		var d := Vector3(c.r - o.r, c.g - o.g, c.b - o.b).length()
		if d < dist:
			dist = d
			mejor = par[1]
	return mejor


# Caras interiores del gabinete (fondo, costados y techo): en el real son
# oscuras. El piso queda claro, como en la foto.
# Coordenadas del CAD (metros): X ancho, Y profundidad (frente en y = -0.022),
# Z alto. El hueco interior va de x -0.051 a 0.784 y de z 0.102 a 1.644.
static func _es_fondo(mesh: Mesh, s: int) -> bool:
	var arr := mesh.surface_get_arrays(s)
	var vs: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
	var ns: PackedVector3Array = arr[Mesh.ARRAY_NORMAL]
	var bb := AABB(vs[0], Vector3.ZERO)
	var n := Vector3.ZERO
	for i in vs.size():
		bb = bb.expand(vs[i])
		n += ns[i]
	n = n.normalized()
	var fin := bb.end
	var adentro := bb.position.x > -0.0525 and fin.x < 0.7855 \
		and bb.position.z > 0.1005 and fin.z < 1.6455
	var es_piso := n.z > 0.5
	return adentro and not es_piso


static func _material(clave: String) -> StandardMaterial3D:
	if not _materiales.has(clave):
		var p: Array = PALETA[clave]
		var m := StandardMaterial3D.new()
		m.resource_name = clave
		m.albedo_color = p[0]
		m.roughness = p[1]
		m.metallic = p[2]
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
		_materiales[clave] = m
	return _materiales[clave]


# ── Líneas de aristas ────────────────────────────────────────────────────

static func _agregar_aristas(mi: MeshInstance3D) -> void:
	var lineas := _aristas(mi.mesh)
	if lineas == null:
		return
	if _material_lineas == null:
		_material_lineas = ShaderMaterial.new()
		_material_lineas.shader = load("res://shaders/contornos.gdshader")
	var nodo := MeshInstance3D.new()
	nodo.name = "Aristas"
	nodo.mesh = lineas
	nodo.material_override = _material_lineas
	nodo.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.add_child(nodo)


# Arma una malla de líneas con las aristas "vivas" de la malla: bordes abiertos
# y uniones entre caras con más de ANGULO_ARISTA grados. Las caras de un
# cilindro facetado o una cara plana partida en triángulos no generan líneas.
# Se cachea por malla: piezas repetidas comparten el resultado.
static func _aristas(mesh: Mesh) -> ArrayMesh:
	if _cache_aristas.has(mesh):
		return _cache_aristas[mesh]
	var cos_lim := cos(deg_to_rad(ANGULO_ARISTA))
	var ids := {}                      # posición cuantizada -> id
	var pos := PackedVector3Array()    # id -> posición
	var aristas := {}                  # clave de arista -> normal de la 1ra cara, o false si ya se resolvió
	var salida := PackedVector3Array()
	const K := 4194304

	for s in mesh.get_surface_count():
		# las primitivas (BoxMesh, CylinderMesh...) siempre son triángulos
		if mesh is ArrayMesh and mesh.surface_get_primitive_type(s) != Mesh.PRIMITIVE_TRIANGLES:
			continue
		var arr := mesh.surface_get_arrays(s)
		var vs: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
		var idx = arr[Mesh.ARRAY_INDEX]
		var vid := PackedInt32Array()
		vid.resize(vs.size())
		for i in vs.size():
			var q := Vector3i((vs[i] * 20000.0).round())
			var id: int = ids.get(q, -1)
			if id == -1:
				id = pos.size()
				ids[q] = id
				pos.append(vs[i])
			vid[i] = id
		var tri: PackedInt32Array = idx if idx != null else PackedInt32Array(range(vs.size()))
		for t in range(0, tri.size() - 2, 3):
			var a := vid[tri[t]]
			var b := vid[tri[t + 1]]
			var c := vid[tri[t + 2]]
			var nrm := (pos[b] - pos[a]).cross(pos[c] - pos[a])
			if nrm.length_squared() < 1e-20:
				continue
			nrm = nrm.normalized()
			for par in [[a, b], [b, c], [c, a]]:
				var lo: int = mini(par[0], par[1])
				var hi: int = maxi(par[0], par[1])
				var clave := lo * K + hi
				var previo = aristas.get(clave)
				if previo == null:
					aristas[clave] = nrm
				elif previo is Vector3:
					if absf(previo.dot(nrm)) < cos_lim:
						salida.append(pos[lo])
						salida.append(pos[hi])
					aristas[clave] = false

	# las que quedaron con una sola cara son bordes abiertos
	for clave in aristas:
		if aristas[clave] is Vector3:
			salida.append(pos[clave / K])
			salida.append(pos[clave % K])

	var resultado: ArrayMesh = null
	if salida.size() > 0:
		resultado = ArrayMesh.new()
		var arr_l := []
		arr_l.resize(Mesh.ARRAY_MAX)
		arr_l[Mesh.ARRAY_VERTEX] = salida
		resultado.add_surface_from_arrays(Mesh.PRIMITIVE_LINES, arr_l)
	_cache_aristas[mesh] = resultado
	return resultado


# ── Cañería de la bomba ─────────────────────────────────────────────────

# En el CAD falta el tramo entre el pico de la bomba sumergible (rs942) y el
# caño que sale por la tapa del tanque. Se agrega un caño con un codo: sale
# del pico y sube hasta encastrar en la boca inferior de ese caño.
static func _canio_bomba(armario: Node) -> void:
	var puntos := puntos_canio_bomba(armario)
	if puntos.is_empty():
		return
	var mi := MeshInstance3D.new()
	mi.name = "CanioBomba"
	mi.mesh = malla_tubo(puntos, 0.03, 16, 0.07)
	mi.material_override = _material("pvc")
	# los puntos están en coordenadas de mundo: no hereda la escala del armario
	mi.top_level = true
	armario.add_child(mi)
	mi.global_transform = Transform3D.IDENTITY
	_agregar_aristas(mi)


# Recorrido (mundo) del pico de la bomba a la boca del caño de la tapa
static func puntos_canio_bomba(armario: Node) -> Array:
	var bomba := armario.get_node_or_null("rs942")
	var boca := boca_canio_tapa(armario)
	if bomba == null or boca == Vector3.INF:
		return []
	var mb := bomba.find_children("*", "MeshInstance3D", true, false)
	if mb.is_empty():
		return []
	var cb: AABB = mb[0].global_transform * mb[0].mesh.get_aabb()
	# el pico sale por el costado +X, a ~3/4 de la altura de la bomba
	var pico := Vector3(cb.end.x, cb.position.y + cb.size.y * 0.735, cb.get_center().z)
	return [
		pico - Vector3(0.01, 0, 0),
		Vector3(boca.x, pico.y, boca.z),
		boca + Vector3(0, 0.03, 0),   # entra un poco en el caño
	]


# Boca inferior del caño que atraviesa la tapa del tanque (superficies de PVC
# del tanque, Part 17): el tramo vertical que baja dentro del tanque.
static func boca_canio_tapa(armario: Node) -> Vector3:
	var tanque := armario.find_child("Part 17", true, false) as MeshInstance3D
	if tanque == null:
		return Vector3.INF
	var pvc := _material("pvc")
	var bb := AABB()
	var hay := false
	var todo := AABB()
	var hay_todo := false
	for s in tanque.mesh.get_surface_count():
		if tanque.get_surface_override_material(s) != pvc:
			continue
		var vs: PackedVector3Array = tanque.mesh.surface_get_arrays(s)[Mesh.ARRAY_VERTEX]
		for v in vs:
			var g: Vector3 = tanque.global_transform * v
			todo = todo.expand(g) if hay_todo else AABB(g, Vector3.ZERO)
			hay_todo = true
	if not hay_todo:
		return Vector3.INF
	# el tramo vertical es lo que queda debajo del tramo horizontal de la tapa
	var y_corte := todo.end.y - 0.09
	for s in tanque.mesh.get_surface_count():
		if tanque.get_surface_override_material(s) != pvc:
			continue
		var vs: PackedVector3Array = tanque.mesh.surface_get_arrays(s)[Mesh.ARRAY_VERTEX]
		for v in vs:
			var g: Vector3 = tanque.global_transform * v
			if g.y < y_corte:
				bb = bb.expand(g) if hay else AABB(g, Vector3.ZERO)
				hay = true
	if not hay:
		return Vector3.INF
	return Vector3(bb.get_center().x, bb.position.y, bb.get_center().z)


# Tubo a lo largo de una polilínea con las esquinas redondeadas. La
# coordenada UV.x es la distancia recorrida desde el inicio (en unidades de
# mundo): la usa el shader del agua para crecer y marcar la dirección.
static func malla_tubo(puntos: Array, radio: float, lados := 16, redondeo := 0.06) -> ArrayMesh:
	var curva := Curve3D.new()
	curva.bake_interval = 0.02
	for i in puntos.size():
		var p: Vector3 = puntos[i]
		var h_in := Vector3.ZERO
		var h_out := Vector3.ZERO
		if i > 0 and i < puntos.size() - 1:
			var a: Vector3 = puntos[i - 1]
			var b: Vector3 = puntos[i + 1]
			var r := minf(redondeo, minf(p.distance_to(a), p.distance_to(b)) * 0.45)
			h_in = (a - p).normalized() * r
			h_out = (b - p).normalized() * r
		curva.add_point(p, h_in, h_out)
	var pts := curva.get_baked_points()
	if pts.size() < 2:
		return null
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var normal := Vector3.ZERO
	var dist := 0.0
	var anillos := []
	for i in pts.size():
		if i > 0:
			dist += pts[i].distance_to(pts[i - 1])
		var tan: Vector3 = (pts[mini(i + 1, pts.size() - 1)] - pts[maxi(i - 1, 0)]).normalized()
		if normal == Vector3.ZERO or absf(normal.dot(tan)) > 0.99:
			normal = Vector3.UP if absf(tan.dot(Vector3.UP)) < 0.9 else Vector3.RIGHT
		normal = (normal - tan * normal.dot(tan)).normalized()
		var bn := tan.cross(normal)
		var anillo := []
		for k in lados + 1:
			var ang := TAU * k / lados
			var dir := normal * cos(ang) + bn * sin(ang)
			anillo.append([pts[i] + dir * radio, dir, Vector2(dist, float(k) / lados)])
		anillos.append(anillo)
	for i in anillos.size() - 1:
		for k in lados:
			for v in [anillos[i][k], anillos[i + 1][k], anillos[i + 1][k + 1], anillos[i][k], anillos[i + 1][k + 1], anillos[i][k + 1]]:
				st.set_normal(v[1])
				st.set_uv(v[2])
				st.add_vertex(v[0])
	return st.commit()


# ── Luz ──────────────────────────────────────────────────────────────────

# Luces de cultivo ultravioleta: violeta, pero con intensidad moderada para
# que no tiñan todo el gabinete. También se baja la luz general para no
# quemar los colores.
static func _luz(main: Node3D) -> void:
	var uv := main.get_node_or_null("PivotArmario/Armario/UVLights")
	if uv:
		for hijo in uv.get_children():
			if hijo is OmniLight3D:
				hijo.light_color = Color(0.62, 0.22, 1.0)
				hijo.light_energy = 0.9
				# solo capa 1: no iluminan el panel de control de afuera (capa 2)
				hijo.light_cull_mask = 1
	var ambiente := main.get_node_or_null("Ambient")
	if ambiente:
		for hijo in ambiente.get_children():
			if hijo is DirectionalLight3D:
				hijo.light_energy = 0.55
			elif hijo is WorldEnvironment and hijo.environment:
				hijo.environment.ambient_light_energy = 0.6
				hijo.environment.tonemap_exposure = 1.0
