extends Node3D

# Modo "cómo funciona": cuando en la web se toca una etapa del ciclo, la
# simulación la muestra.
#   deposito   -> tanque transparente llenándose de solución
#   bomba      -> el agua sube a los canales, recorre y vuelve al tanque
#   canal      -> canales con agua, raíces y plantas
#   retorno    -> reservorios con aditivos que viajan al tanque
#   telemetria -> la cámara va al costado derecho y el LCD muestra los valores
# La web manda {sensor: "<etapa>"} por postMessage; null vuelve a la vista normal.
# Para probar sin la web: F1..F5 y Esc.

const Look = preload("res://scripts/look_tecnico.gd")
const PanelControl = preload("res://scripts/panel_control.gd")

const TITULOS := {
	"deposito": "Preparación de la solución nutritiva",
	"bomba": "Distribución hacia los canales",
	"canal": "Nutrición de las plantas",
	"retorno": "Dosificación automática de aditivos",
	"telemetria": "Monitoreo y control",
}
const TECLAS := {KEY_F1: "deposito", KEY_F2: "bomba", KEY_F3: "canal", KEY_F4: "retorno", KEY_F5: "telemetria"}

const COLOR_AGUA := Color(0.08, 0.45, 1.0)
const VEL_BOMBA := 1.9     # velocidad del agua (unidades de mundo por segundo)
const VEL_CANAL := 0.45
const NIVEL_TANQUE := 0.62  # nivel lleno, como fracción del alto del tanque
const COLORES_ADITIVOS := [Color(0.98, 0.72, 0.15), Color(0.35, 0.80, 0.30), Color(0.70, 0.35, 0.95), Color(0.25, 0.75, 1.0)]

var _main: Node3D
var _tanque: AABB
var _reservorios: AABB
var _canales: Array[AABB] = []      # ordenados: primero los de arriba
var _macetas: Array[AABB] = []      # caja de cada maceta (mundo)
var _efectos: Node3D
var _flujos: Array = []             # [PathFollow3D, velocidad, espera]
var _circuito: Curve3D              # recorrido del agua por los caños (mundo)
var _puntos_circuito: Array = []
var _frentes: Array = []            # [ShaderMaterial, velocidad, largo] del agua que avanza
const SHADER_AGUA = preload("res://shaders/agua_flujo.gdshader")
var _paso := ""
var _mats_originales := {}
var _cartel: PanelContainer
var _texto_cartel: Label
var _cam_original := {}
var _t_lcd := 0.0
var _valores := {"ph": 6.12, "ec": 1.92, "t_sup": 21.4, "t_inf": 21.1, "t_ext": 24.1, "t_int": 23.8, "hr_ext": 55.0, "hr_int": 61.0}
const SEG_PANTALLA := 5.0     # cada pantalla del LCD dura 5 s
const LETRAS_POR_SEG := 55.0  # velocidad de escritura del LCD
var _pantalla := 0
var _t_pantalla := 0.0
var _js_cb


func setup(main: Node3D) -> void:
	_main = main
	name = "ModoPasos"
	_efectos = Node3D.new()
	_efectos.name = "Efectos"
	add_child(_efectos)
	_medir_piezas()
	_armar_circuito()
	_crear_cartel()
	if OS.has_feature("web"):
		_js_cb = JavaScriptBridge.create_callback(_on_mensaje_web)
		JavaScriptBridge.get_interface("window").addEventListener("message", _js_cb)


func _on_mensaje_web(args: Array) -> void:
	var ev = args[0]
	var data = ev.data
	if typeof(data) != TYPE_OBJECT or data == null:
		return
	var s = data.sensor
	if typeof(s) == TYPE_STRING and TITULOS.has(s):
		mostrar(s)
	else:
		mostrar("")


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if TECLAS.has(event.keycode):
			mostrar("" if _paso == TECLAS[event.keycode] else TECLAS[event.keycode])
		elif event.keycode == KEY_ESCAPE:
			mostrar("")


# ── Geometría ────────────────────────────────────────────────────────────

func _aabb_global(mi: MeshInstance3D) -> AABB:
	return mi.global_transform * mi.mesh.get_aabb()


func _medir_piezas() -> void:
	var armario := _main.get_node("PivotArmario/Armario")
	var tanque := armario.find_child("Part 17", true, false) as MeshInstance3D
	if tanque:
		_tanque = _aabb_global(tanque)
	var res := armario.find_child("Part 119", true, false) as MeshInstance3D
	if res:
		_reservorios = _aabb_global(res)
	# canales NFT: caños largos y finos de PVC
	for mi in armario.find_children("Part *", "MeshInstance3D", true, false):
		var bb := _aabb_global(mi)
		if bb.size.x > 1.5 and bb.size.y < 0.4 and bb.size.z < 0.4:
			_canales.append(bb)
	_canales.sort_custom(func(a, b): return a.get_center().y > b.get_center().y)
	# macetas (ya unidas en un MultiMesh por main.gd)
	var pots := armario.get_node_or_null("Pots")
	if pots:
		for mmi in pots.get_children():
			if mmi is MultiMeshInstance3D:
				var mm: MultiMesh = mmi.multimesh
				var caja := mm.mesh.get_aabb()
				for i in mm.instance_count:
					var xf: Transform3D = mmi.global_transform * mm.get_instance_transform(i)
					# el modelo de la maceta tiene otro eje "arriba": se usa la caja
					# ya transformada al mundo para ubicar el centro y el borde
					_macetas.append(xf * caja)


# ── Cambio de etapa ──────────────────────────────────────────────────────

func mostrar(paso: String) -> void:
	_limpiar()
	_paso = paso
	if paso == "":
		_cartel_visible(false)
		_camara_normal()
		return
	_cartel_visible(true, "Mostrando: " + TITULOS[paso])
	match paso:
		"deposito":
			_camara_normal()
			_transparente("rojo", 0.12)
			_transparente("rojo_oscuro", 0.12)
			_agua_tanque(1.0, 0.02)
		"bomba":
			_camara_normal()
			_transparente("rojo", 0.12)
			_transparente("rojo_oscuro", 0.12)
			_transparente("pvc", 0.22)
			_circulacion(VEL_BOMBA, true)
		"canal":
			_camara_normal()
			_transparente("pvc", 0.22)
			_circulacion(VEL_CANAL, false)
			_plantas()
		"retorno":
			_camara_normal()
			_transparente("rojo", 0.12)
			_transparente("rojo_oscuro", 0.12)
			_transparente("pvc", 0.22)
			_agua_tanque(0.7)
			_aditivos()
		"telemetria":
			_camara_lcd()
			if PanelControl.lcd:
				PanelControl.lcd.visible = true
				_pantalla = 0
				_t_pantalla = 0.0
				_dibujar_lcd()


func _limpiar() -> void:
	for hijo in _efectos.get_children():
		hijo.queue_free()
	_flujos.clear()
	_frentes.clear()
	for m in _mats_originales:
		var o: Dictionary = _mats_originales[m]
		m.transparency = o["transparency"]
		m.albedo_color = o["color"]
		m.depth_draw_mode = o["depth"]
	_mats_originales.clear()
	if PanelControl.lcd:
		PanelControl.lcd.visible = false


func _process(delta: float) -> void:
	for f in _flujos:
		var seguidor: PathFollow3D = f[0]
		if f[2] > 0.0:
			f[2] -= delta
			if f[2] > 0.0:
				continue
			seguidor.visible = true
		seguidor.progress += f[1] * delta
	for f in _frentes:
		if f[2] < f[3]:
			f[2] += f[1] * delta
			(f[0] as ShaderMaterial).set_shader_parameter("avance", f[2])
	if _paso == "telemetria":
		_t_lcd += delta
		if _t_lcd > 1.0:
			_t_lcd = 0.0
			_actualizar_valores()
		_t_pantalla += delta
		if _t_pantalla >= SEG_PANTALLA:
			_t_pantalla = 0.0
			_pantalla = (_pantalla + 1) % 4
		_dibujar_lcd()


# ── Materiales ───────────────────────────────────────────────────────────

func _transparente(clave: String, alfa: float) -> void:
	var m: StandardMaterial3D = Look._material(clave)
	if _mats_originales.has(m):
		return
	_mats_originales[m] = {"transparency": m.transparency, "color": m.albedo_color, "depth": m.depth_draw_mode}
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	var c := m.albedo_color
	c.a = alfa
	m.albedo_color = c


func _liquido(color: Color, alfa := 0.7) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(color, alfa)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.emission_enabled = true
	m.emission = color
	m.emission_energy_multiplier = 0.6
	m.roughness = 0.1
	return m


func _emisivo(color: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.emission_enabled = true
	m.emission = color
	m.emission_energy_multiplier = 1.6
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	return m


func _caja(centro: Vector3, tam: Vector3, mat: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var m := BoxMesh.new()
	m.size = tam
	mi.mesh = m
	mi.material_override = mat
	mi.position = centro
	_efectos.add_child(mi)
	return mi


# ── Etapas ───────────────────────────────────────────────────────────────

# Agua dentro del tanque. Devuelve el pivote (en el fondo del tanque) para
# poder animar el nivel con su escala en Y. desde/hasta: nivel relativo.
func _agua_tanque(hasta: float, desde := -1.0, duracion := 2.5) -> Node3D:
	if _tanque.size == Vector3.ZERO:
		return null
	var base := _tanque.position
	var tam := _tanque.size
	var alto := tam.y * NIVEL_TANQUE
	var pivote := Node3D.new()
	pivote.position = Vector3(base.x + tam.x / 2.0, base.y + tam.y * 0.04, base.z + tam.z / 2.0)
	_efectos.add_child(pivote)
	var agua := MeshInstance3D.new()
	var caja := BoxMesh.new()
	caja.size = Vector3(tam.x * 0.86, alto, tam.z * 0.84)
	agua.mesh = caja
	agua.material_override = _liquido(COLOR_AGUA, 0.82)
	agua.position.y = alto / 2.0
	pivote.add_child(agua)
	# superficie del agua, más clara
	var sup := MeshInstance3D.new()
	var plano := BoxMesh.new()
	plano.size = Vector3(tam.x * 0.86, 0.012, tam.z * 0.84)
	sup.mesh = plano
	sup.material_override = _liquido(Color(0.55, 0.85, 1.0), 0.9)
	sup.position.y = alto
	pivote.add_child(sup)
	if desde >= 0.0:
		pivote.scale.y = maxf(desde, 0.01)
		var tw := create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		tw.tween_property(pivote, "scale:y", hasta, duracion)
	else:
		pivote.scale.y = hasta
	return pivote


# Recorrido real del agua, pasando por el centro de cada caño del CAD:
#   bomba del tanque -> caño vertical izquierdo trasero (Part 111) -> estante
#   de arriba en zigzag (atrás →, medio ←, adelante →; codos Part 142 y 151)
#   -> caño largo de la derecha (Part 112) -> estante de abajo en zigzag
#   (adelante ←, medio →, atrás ←; codos Part 136 y 19) -> caño corto
#   izquierdo (Part 147) -> tanque.
func _armar_circuito() -> void:
	if _canales.size() < 6 or _tanque.size == Vector3.ZERO:
		return
	var armario := _main.get_node("PivotArmario/Armario")
	var subida := _canio_vertical(armario, "Part 111")
	var bajada := _canio_vertical(armario, "Part 112")
	var retorno := _canio_vertical(armario, "Part 147")
	if subida.size.y == 0.0 or bajada.size.y == 0.0 or retorno.size.y == 0.0:
		return
	# canales: 3 arriba y 3 abajo, ordenados de atrás (z menor) hacia adelante
	var arriba := _canales.slice(0, 3)
	var abajo := _canales.slice(3, 6)
	arriba.sort_custom(func(a, b): return a.get_center().z < b.get_center().z)
	abajo.sort_custom(func(a, b): return a.get_center().z < b.get_center().z)
	var x_izq: float = arriba[0].position.x
	var x_der: float = arriba[0].end.x
	var codo_izq := x_izq - 0.07     # centro de los codos en U de la izquierda
	var codo_der := x_der + 0.05
	var y_arr: float = arriba[0].get_center().y - 0.05   # el agua va por el fondo del canal
	var y_aba: float = abajo[0].get_center().y - 0.05
	var z := func(c: AABB) -> float: return c.get_center().z

	var xs := subida.get_center().x
	var zs := subida.get_center().z
	var xb := bajada.get_center().x
	var zb := bajada.get_center().z
	var xr := retorno.get_center().x
	var zr := retorno.get_center().z
	var codo_manguera := _pieza(armario, "Part 122")
	var canio_bomba: Array = Look.puntos_canio_bomba(armario)
	if canio_bomba.is_empty() or codo_manguera.size == Vector3.ZERO:
		return
	var manguera := _pieza(armario, "Part 154")
	var y_manguera: float = manguera.get_center().y
	var z_manguera: float = manguera.get_center().z
	var x_codo := codo_manguera.get_center().x
	var boca: Vector3 = canio_bomba[canio_bomba.size() - 1]
	# codos arriba del caño de subida y conector al canal (dentro del Sistema:
	# hay otras piezas con el mismo nombre en las puertas)
	var sistema := armario.get_node_or_null("Sistema")
	var codo_arriba := _pieza(sistema, "Part 146")
	var conector := _pieza(sistema, "Part 12")
	if codo_arriba.size == Vector3.ZERO or conector.size == Vector3.ZERO:
		return
	var y_codo := codo_arriba.end.y - 0.03
	var z_con := conector.get_center().z
	var y_con := conector.position.y + 0.032
	var x_con := conector.end.x

	var p: Array[Vector3] = []
	# de la bomba por el caño nuevo hasta la boca del caño de la tapa
	for q in canio_bomba:
		p.append(q)
	p.append_array([
		# sube por el caño de la tapa y sigue por su tramo horizontal
		Vector3(boca.x, y_manguera, boca.z),
		Vector3(manguera.end.x, y_manguera, z_manguera),
		# manguera y codos del CAD hasta el pie del caño de subida
		Vector3(x_codo, y_manguera, z_manguera),
		Vector3(x_codo, y_manguera, zs),
		Vector3(xs, y_manguera, zs),
		# sube por el caño izquierdo trasero, sigue los codos de arriba
		# (Part 146 hacia adelante, Part 123 hacia abajo) y entra al canal de
		# atrás por el conector Part 12
		Vector3(xs, y_codo, zs),
		Vector3(xs, y_codo, z_con),
		Vector3(xs, y_con, z_con),
		Vector3(x_con, y_con, z_con),
		Vector3(x_con + 0.06, y_arr, z.call(arriba[0])),
		# estante de arriba en zigzag
		Vector3(x_der, y_arr, z.call(arriba[0])),
		Vector3(codo_der, y_arr, z.call(arriba[0])),
		Vector3(codo_der, y_arr, z.call(arriba[1])),
		Vector3(x_izq, y_arr, z.call(arriba[1])),
		Vector3(codo_izq, y_arr, z.call(arriba[1])),
		Vector3(codo_izq, y_arr, z.call(arriba[2])),
		Vector3(x_der, y_arr, z.call(arriba[2])),
		# baja por el caño largo de la derecha
		Vector3(xb, y_arr, zb),
		Vector3(xb, y_aba, zb),
		# estante de abajo en zigzag
		Vector3(x_der, y_aba, z.call(abajo[2])),
		Vector3(x_izq, y_aba, z.call(abajo[2])),
		Vector3(codo_izq, y_aba, z.call(abajo[2])),
		Vector3(codo_izq, y_aba, z.call(abajo[1])),
		Vector3(x_der, y_aba, z.call(abajo[1])),
		Vector3(codo_der, y_aba, z.call(abajo[1])),
		Vector3(codo_der, y_aba, z.call(abajo[0])),
		Vector3(x_izq, y_aba, z.call(abajo[0])),
		# cae por el caño corto de la izquierda al tanque
		Vector3(xr, y_aba, zr),
		Vector3(xr, _tanque.position.y + _tanque.size.y * 0.45, zr),
	])
	_puntos_circuito = p
	_circuito = Curve3D.new()
	_circuito.bake_interval = 0.02
	for punto in p:
		_circuito.add_point(punto)


# Caja de un caño vertical con X/Z en el eje real del caño: se toman las
# superficies que recorren más de la mitad del alto (el cuerpo recto), porque
# la caja completa incluye codos y accesorios y corre el centro.
func _canio_vertical(raiz: Node, nombre: String) -> AABB:
	var mi := raiz.find_child(nombre, true, false) as MeshInstance3D
	if mi == null:
		return AABB()
	var todo := _aabb_global(mi)
	var cuerpo := AABB()
	var hay := false
	for s in mi.mesh.get_surface_count():
		var vs: PackedVector3Array = mi.mesh.surface_get_arrays(s)[Mesh.ARRAY_VERTEX]
		var bb := AABB(mi.global_transform * vs[0], Vector3.ZERO)
		for v in vs:
			bb = bb.expand(mi.global_transform * v)
		if bb.size.y > todo.size.y * 0.5:
			cuerpo = cuerpo.merge(bb) if hay else bb
			hay = true
	if not hay:
		return todo
	var c := cuerpo.get_center()
	return AABB(Vector3(c.x, todo.position.y, c.z), Vector3(0, todo.size.y, 0))


func _pieza(raiz: Node, nombre: String) -> AABB:
	var mi := raiz.find_child(nombre, true, false) as MeshInstance3D
	return _aabb_global(mi) if mi else AABB()


# Agua circulando por el circuito. Con llenado, sale de la bomba como un
# frente que avanza: los canales se van llenando a medida que llega y el
# tanque baja hasta que el agua empieza a volver.
func _circulacion(velocidad: float, llenado: bool) -> void:
	if _circuito == null:
		return
	var largo := _circuito.get_baked_length()
	var t_vuelta := largo / velocidad
	# el tanque baja mientras el agua se reparte por el circuito
	_agua_tanque(0.7, 1.0 if llenado else -1.0, t_vuelta)
	# agua en cada canal, creciendo desde su entrada cuando llega el frente
	for c in _canales:
		var y := c.get_center().y - c.size.y * 0.22
		var ini := Vector3(c.position.x, y, c.get_center().z)
		var fin := Vector3(c.end.x, y, c.get_center().z)
		var o_ini := _circuito.get_closest_offset(ini)
		var o_fin := _circuito.get_closest_offset(fin)
		var entrada := ini if o_ini < o_fin else fin
		var sentido := 1.0 if o_ini < o_fin else -1.0
		var pivote := Node3D.new()
		pivote.position = entrada
		_efectos.add_child(pivote)
		var agua := MeshInstance3D.new()
		var caja := BoxMesh.new()
		caja.size = Vector3(c.size.x * 0.97, c.size.y * 0.2, c.size.z * 0.55)
		agua.mesh = caja
		agua.material_override = _liquido(COLOR_AGUA, 0.65)
		agua.position.x = sentido * c.size.x * 0.97 / 2.0
		pivote.add_child(agua)
		if llenado:
			pivote.scale.x = 0.01
			var tw := create_tween()
			tw.tween_interval(minf(o_ini, o_fin) / velocidad)
			tw.tween_property(pivote, "scale:x", 1.0, c.size.x / velocidad)
	_fluido(_puntos_circuito, COLOR_AGUA, velocidad, llenado, 0.026)


# Agua continua a lo largo de un recorrido (tubo con el shader agua_flujo).
# Con llenado, el agua avanza desde el inicio a la velocidad de la corriente.
func _fluido(puntos: Array, color: Color, velocidad: float, llenado: bool, radio: float) -> void:
	var malla := Look.malla_tubo(puntos, radio, 12, 0.06)
	if malla == null:
		return
	var mat := ShaderMaterial.new()
	mat.shader = SHADER_AGUA
	mat.set_shader_parameter("color", color)
	mat.set_shader_parameter("color_franja", color.lerp(Color.WHITE, 0.65))
	mat.set_shader_parameter("velocidad", velocidad)
	var mi := MeshInstance3D.new()
	mi.mesh = malla
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_efectos.add_child(mi)
	if llenado:
		var largo := 0.0
		for i in range(1, puntos.size()):
			largo += (puntos[i] as Vector3).distance_to(puntos[i - 1])
		mat.set_shader_parameter("avance", 0.0)
		_frentes.append([mat, velocidad, 0.0, largo + 1.0])
	else:
		mat.set_shader_parameter("avance", 100000.0)


# Plantas que crecen en el centro de cada plantín, con las raíces bajando
# hasta tocar el agua que corre por el canal.
func _plantas() -> void:
	var hoja := StandardMaterial3D.new()
	hoja.albedo_color = Color(0.30, 0.68, 0.28)
	hoja.roughness = 0.7
	var tallo := StandardMaterial3D.new()
	tallo.albedo_color = Color(0.36, 0.55, 0.25)
	var raiz := StandardMaterial3D.new()
	raiz.albedo_color = Color(0.93, 0.89, 0.74)
	raiz.roughness = 0.8
	var i := 0
	for caja in _macetas:
		# un poco hundida en el plantín, así las raíces llegan al agua
		var centro := Vector3(caja.get_center().x, caja.end.y - caja.size.y * 0.3, caja.get_center().z)
		# agua del canal que está debajo de la maceta
		var y_agua := caja.position.y - 0.05
		for c in _canales:
			if absf(c.get_center().z - centro.z) < c.size.z / 2.0 and centro.x > c.position.x and centro.x < c.end.x \
					and c.get_center().y < centro.y and c.end.y > caja.position.y - 0.1:
				y_agua = c.get_center().y - c.size.y * 0.14
		var planta := Node3D.new()
		planta.position = centro
		_efectos.add_child(planta)
		# tallo y hojas
		var t := MeshInstance3D.new()
		var ct := CylinderMesh.new()
		ct.top_radius = 0.008
		ct.bottom_radius = 0.012
		ct.height = 0.09
		ct.radial_segments = 6
		t.mesh = ct
		t.material_override = tallo
		t.position.y = 0.035
		planta.add_child(t)
		for k in 5:
			var h := MeshInstance3D.new()
			var sm := SphereMesh.new()
			sm.radius = 0.055
			sm.height = 0.19
			sm.radial_segments = 8
			sm.rings = 4
			h.mesh = sm
			h.material_override = hoja
			h.rotation = Vector3(deg_to_rad(48 if k < 4 else 5), deg_to_rad(90 * k + i * 23), 0)
			h.position = Vector3(0, 0.08, 0) + h.basis.y * 0.07
			planta.add_child(h)
		# raíces: del fondo de la maceta hasta el agua
		var largo := maxf(centro.y - y_agua + 0.05, 0.08)
		for k in 4:
			var r := MeshInstance3D.new()
			var cr := CylinderMesh.new()
			cr.top_radius = 0.007
			cr.bottom_radius = 0.003
			cr.height = largo
			cr.radial_segments = 5
			r.mesh = cr
			r.material_override = raiz
			var ang := TAU * k / 4.0 + i
			r.position = Vector3(cos(ang) * 0.02, -largo / 2.0, sin(ang) * 0.02)
			r.rotation = Vector3(sin(ang) * 0.12, 0, cos(ang) * 0.12)
			planta.add_child(r)
		planta.scale = Vector3.ONE * 0.01
		var tw := create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.tween_interval(0.03 * i)
		tw.tween_property(planta, "scale", Vector3.ONE, 0.8)
		i += 1


# Minitanques con aditivos de colores: el líquido sube por el conector de
# cada tapa, corre por su manguera bajo el estante y baja al tanque por su caño.
# Recorridos del CAD: [conector, tramo a lo largo de X, bajada al tanque,
# tramo en Z (solo los de la derecha)].
const MANGUERAS := [
	["Part 137", "Part 125", "Part 163", ""],
	["Part 159", "Part 14", "Part 148", ""],
	["Part 140", "Part 130", "Part 162", "Part 167"],
	["Part 127", "Part 117", "Part 144", "Part 129"],
]

func _aditivos() -> void:
	if _reservorios.size == Vector3.ZERO or _tanque.size == Vector3.ZERO:
		return
	_transparente("manguera", 0.3)
	var armario := _main.get_node("PivotArmario/Armario")
	var r := _reservorios
	var radio := 0.115
	var alto := r.size.y * 0.72
	var y_liq := r.position.y + 0.04
	for k in MANGUERAS.size():
		var ruta: Array = MANGUERAS[k]
		var conector := _pieza(armario, ruta[0])
		var tramo := _pieza(armario, ruta[1])
		var bajada := _pieza(armario, ruta[2])
		if conector.size == Vector3.ZERO or tramo.size == Vector3.ZERO or bajada.size == Vector3.ZERO:
			continue
		var color: Color = COLORES_ADITIVOS[k]
		# el cilindro del minitanque: el conector está en el borde de su tapa
		var cx := conector.get_center().x + 0.095
		var cz := conector.get_center().z + 0.0025
		var liq := MeshInstance3D.new()
		var cil := CylinderMesh.new()
		cil.top_radius = radio
		cil.bottom_radius = radio
		cil.height = alto
		cil.radial_segments = 20
		liq.mesh = cil
		liq.material_override = _liquido(color, 0.75)
		liq.position = Vector3(cx, y_liq + alto / 2.0, cz)
		_efectos.add_child(liq)
		# recorrido por la manguera
		var y_tramo := tramo.get_center().y
		var z_tramo := tramo.get_center().z
		var xc := conector.get_center().x
		var zc := conector.get_center().z
		var puntos := [
			Vector3(cx, y_liq + alto * 0.5, cz),
			Vector3(cx, conector.position.y, cz),
			Vector3(xc, conector.position.y + 0.02, zc),
			Vector3(xc, y_tramo, zc),
		]
		if ruta[3] != "":
			puntos.append(Vector3(xc, y_tramo, z_tramo))
		puntos.append(Vector3(bajada.get_center().x, y_tramo, z_tramo))
		puntos.append(Vector3(bajada.get_center().x, bajada.position.y, z_tramo))
		_fluido(puntos, color, 0.45, true, 0.011)


# ── Cámara ───────────────────────────────────────────────────────────────

func _pivote() -> Node3D:
	return _main.get_node_or_null("CamaraPivot")


func _guardar_camara() -> void:
	var piv := _pivote()
	if piv and _cam_original.is_empty():
		_cam_original = {"pos": piv.position, "fov": piv.get_node("Camera3D").fov}


func _camara_normal() -> void:
	var piv := _pivote()
	if piv == null or _cam_original.is_empty():
		return
	var tw := create_tween().set_parallel().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(piv, "position", _cam_original["pos"], 0.9)
	tw.tween_property(piv, "rotation_degrees", Vector3.ZERO, 0.9)
	tw.tween_property(piv.get_node("Camera3D"), "fov", _cam_original["fov"], 0.9)


# paneo hacia el costado derecho, acercándose al display
func _camara_lcd() -> void:
	var piv := _pivote()
	if piv == null or PanelControl.lcd == null:
		return
	_guardar_camara()
	var destino := PanelControl.lcd.global_position
	var pos := piv.position
	pos.y = destino.y - 0.1
	var tw := create_tween().set_parallel().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(piv, "position", pos, 1.4)
	tw.tween_property(piv, "rotation_degrees", Vector3(-8, 90, 0), 1.4)
	tw.tween_property(piv.get_node("Camera3D"), "fov", 34.0, 1.4)


# pequeñas variaciones para que los valores se vean "vivos"
func _actualizar_valores() -> void:
	var v := _valores
	v["ph"] = clampf(v["ph"] + randf_range(-0.02, 0.02), 5.8, 6.4)
	v["ec"] = clampf(v["ec"] + randf_range(-0.01, 0.01), 1.7, 2.1)
	v["t_sup"] = clampf(v["t_sup"] + randf_range(-0.1, 0.1), 20.0, 22.5)
	v["t_inf"] = clampf(v["t_inf"] + randf_range(-0.1, 0.1), 20.0, 22.5)
	v["t_ext"] = clampf(v["t_ext"] + randf_range(-0.1, 0.1), 21.0, 27.0)
	v["t_int"] = clampf(v["t_int"] + randf_range(-0.1, 0.1), 22.0, 25.5)
	v["hr_ext"] = clampf(v["hr_ext"] + randf_range(-0.4, 0.4), 45.0, 65.0)
	v["hr_int"] = clampf(v["hr_int"] + randf_range(-0.4, 0.4), 55.0, 68.0)


func _lineas_pantalla(i: int) -> Array:
	var v := _valores
	var pie := "         %d/4" % (i + 1)
	match i:
		0:
			return ["SOLUCION NUTRITIVA", "pH   %.2f" % v["ph"], "EC   %.2f mS/cm" % v["ec"], pie]
		1:
			return ["TEMP. SOLUCION", "Sup.  %.1f C" % v["t_sup"], "Inf.  %.1f C" % v["t_inf"], pie]
		2:
			return ["AMBIENTE", "T.ext  %.1f C" % v["t_ext"], "T.int  %.1f C" % v["t_int"], pie]
		_:
			return ["HUMEDAD RELATIVA", "Ext.  %.0f %%" % v["hr_ext"], "Int.  %.0f %%" % v["hr_int"], pie]


# Animación típica de un LCD de caracteres: se borra la pantalla, el texto se
# escribe letra por letra con un cursor parpadeante y queda fijo hasta el
# cambio de pantalla; los valores se siguen actualizando en vivo.
func _dibujar_lcd() -> void:
	if PanelControl.lcd == null:
		return
	var lineas := _lineas_pantalla(_pantalla)
	var t := _t_pantalla - 0.25          # 0.25 s con la pantalla en blanco
	if t < 0.0:
		PanelControl.lcd.text = " \n \n \n "
		return
	var mostrar_n := int(t * LETRAS_POR_SEG)
	var total := 0
	for l in lineas:
		total += (l as String).length()
	var salida := []
	var resto := mostrar_n
	for l in lineas:
		var linea: String = l
		if resto >= linea.length():
			salida.append(linea)
			resto -= linea.length()
		else:
			var cursor := "_" if int(t * 6.0) % 2 == 0 else " "
			salida.append(linea.substr(0, resto) + cursor)
			resto = -1
			break
	# las 4 filas siempre ocupan su lugar, como en un LCD real
	while salida.size() < 4:
		salida.append(" ")
	PanelControl.lcd.text = "\n".join(salida)


# ── Cartel "Mostrando: ..." ──────────────────────────────────────────────

func _crear_cartel() -> void:
	var capa := CanvasLayer.new()
	add_child(capa)
	_cartel = PanelContainer.new()
	var estilo := StyleBoxFlat.new()
	estilo.bg_color = Color(0.03, 0.09, 0.07, 0.8)
	estilo.border_color = Color(0.66, 0.84, 0.71, 0.3)
	estilo.set_border_width_all(2)
	estilo.set_corner_radius_all(48)
	estilo.content_margin_left = 34
	estilo.content_margin_right = 40
	estilo.content_margin_top = 18
	estilo.content_margin_bottom = 18
	_cartel.add_theme_stylebox_override("panel", estilo)
	_cartel.position = Vector2(40, 40)
	var fila := HBoxContainer.new()
	fila.add_theme_constant_override("separation", 22)
	_cartel.add_child(fila)
	var punto := PanelContainer.new()
	var estilo_punto := StyleBoxFlat.new()
	estilo_punto.bg_color = Color(0.5, 0.88, 0.63)
	estilo_punto.set_corner_radius_all(12)
	punto.add_theme_stylebox_override("panel", estilo_punto)
	punto.custom_minimum_size = Vector2(22, 22)
	punto.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	fila.add_child(punto)
	_texto_cartel = Label.new()
	_texto_cartel.add_theme_font_size_override("font_size", 40)
	_texto_cartel.add_theme_color_override("font_color", Color(0.86, 0.95, 0.89))
	fila.add_child(_texto_cartel)
	_cartel.modulate.a = 0.0
	capa.add_child(_cartel)


func _cartel_visible(ver: bool, texto := "") -> void:
	if texto != "":
		_texto_cartel.text = texto
	var tw := create_tween()
	tw.tween_property(_cartel, "modulate:a", 1.0 if ver else 0.0, 0.3)
