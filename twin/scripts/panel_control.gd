extends RefCounted

# Panel de control del costado derecho del gabinete (referencia: foto del
# costado): panel de MDF marrón con la caja de control (display LCD, luz
# piloto y Raspberry Pi encima), un ventilador, las 4 salidas de ADITIVOS con
# sus conectores, pasacables en la esquina y cables que llevan todo a la caja.
#
# Se arma con piezas simples dentro del espacio local de la malla del gabinete
# (coordenadas del CAD en metros: X ancho, Y profundidad con el frente en
# y = -0.022, Z alto). Lo llama look_tecnico.gd.

const Look = preload("res://scripts/look_tecnico.gd")

# medidas del gabinete (CAD)
const X_IZQ := -0.083
const X_DER := 0.817
const PARED := 0.033          # espesor de la pared lateral
const Y_FRENTE := -0.022
const Y_FONDO := 0.428
const ALTO := 1.677

# capa de render propia: las luces UV del interior no iluminan el panel
const CAPA_PANEL := 2

const COLORES := {
	"mdf":      [Color(0.30, 0.24, 0.20), 0.80],
	"caja":     [Color(0.86, 0.87, 0.87), 0.55],
	"lcd_marco":[Color(0.08, 0.08, 0.09), 0.50],
	"negro":    [Color(0.06, 0.06, 0.07), 0.50],
	"blanco":   [Color(0.93, 0.93, 0.92), 0.50],
	"rpi":      [Color(0.80, 0.12, 0.22), 0.40],
	"canaleta": [Color(0.62, 0.63, 0.64), 0.60],
	"verde":    [Color(0.20, 0.62, 0.30), 0.50],
	"tornillo": [Color(0.75, 0.76, 0.78), 0.30],
	"cable_rojo":  [Color(0.75, 0.10, 0.10), 0.45],
	"cable_azul":  [Color(0.12, 0.35, 0.80), 0.45],
	"cable_negro": [Color(0.07, 0.07, 0.08), 0.45],
	"cable_verde": [Color(0.15, 0.60, 0.25), 0.45],
	"cable_gris":  [Color(0.55, 0.55, 0.56), 0.45],
	"manguera":    [Color(0.80, 0.78, 0.60), 0.30],  # manguera cristal amarillenta
}

static var _mats := {}
static var _s := 1.0      # +1 si el costado derecho es x = X_DER, -1 si es x = X_IZQ
static var _xf := X_DER   # cara exterior del costado derecho
# texto del display LCD (lo llena modo_pasos.gd en el paso de monitoreo)
static var lcd: Label3D


static func construir(gabinete: MeshInstance3D, armario: Node) -> void:
	var raiz := Node3D.new()
	raiz.name = "PanelControl"
	gabinete.add_child(raiz)

	# ¿qué costado queda a la derecha visto desde la cámara?
	var cam := gabinete.get_viewport().get_camera_3d()
	var derecha := Vector3.RIGHT
	if cam:
		derecha = cam.global_basis.x
	var a := gabinete.to_global(Vector3(X_DER, 0.2, 0.8))
	var b := gabinete.to_global(Vector3(X_IZQ, 0.2, 0.8))
	_s = 1.0 if (a - b).dot(derecha) > 0.0 else -1.0
	_xf = X_DER if _s > 0.0 else X_IZQ

	var yc := 0.19   # centro de las piezas a lo profundo del costado

	# Los conectores de ADITIVOS ya están en el CAD: son las piezas del
	# "Sistema" que atraviesan la pared de este costado. Se pintan de negro y
	# se usan sus posiciones para las etiquetas y los cables.
	var conectores := _conectores(gabinete, armario)

	# panel de MDF que cubre todo el costado
	_caja(raiz, _p(0.006, (Y_FRENTE + Y_FONDO) / 2.0, ALTO / 2.0), Vector3(0.012, Y_FONDO - Y_FRENTE, ALTO), "mdf")
	var ext := 0.012  # cara exterior del panel

	# ── caja de control ──
	var zc := 1.515
	_caja(raiz, _p(ext + 0.055, yc, zc), Vector3(0.11, 0.30, 0.28), "caja")
	# tapa (se ve la junta)
	_caja(raiz, _p(ext + 0.113, yc, zc), Vector3(0.006, 0.29, 0.27), "caja")
	# display LCD 20x4
	var cara := ext + 0.117
	_caja(raiz, _p(cara + 0.002, yc - 0.025, zc + 0.085), Vector3(0.004, 0.105, 0.038), "lcd_marco")
	var pantalla := _caja(raiz, _p(cara + 0.0045, yc - 0.025, zc + 0.085), Vector3(0.002, 0.090, 0.026), "lcd_marco", false)
	pantalla.material_override = _emisivo(Color(0.16, 0.34, 0.85), 0.9)
	lcd = Label3D.new()
	lcd.name = "TextoLCD"
	lcd.font_size = 32
	lcd.outline_size = 0
	lcd.pixel_size = 0.0052 / 32.0
	lcd.line_spacing = -9.0
	lcd.modulate = Color(0.88, 0.95, 1.0)
	lcd.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	lcd.shaded = false
	lcd.double_sided = false
	var z_lcd := Vector3(_s, 0, 0)
	var y_lcd := Vector3(0, 0, 1)
	# con alineación a la izquierda, la posición es el borde izquierdo del texto
	# anclado arriba: las filas quedan fijas aunque se escriban de a una
	lcd.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	var borde_izq := _p(cara + 0.0062, yc - 0.025, zc + 0.085) - y_lcd.cross(z_lcd) * 0.041 + y_lcd * 0.0122
	lcd.transform = Transform3D(Basis(y_lcd.cross(z_lcd), y_lcd, z_lcd), borde_izq)
	lcd.visible = false
	raiz.add_child(lcd)
	# luz piloto naranja
	var piloto := _cilindro_x(raiz, _p(cara + 0.008, yc - 0.075, zc - 0.07), 0.011, 0.016, "negro", false)
	piloto.material_override = _emisivo(Color(1.0, 0.42, 0.04), 1.1)
	# bisagra del lado del frente
	_cilindro_z(raiz, _p(ext + 0.105, yc - 0.155, zc), 0.005, 0.20, "tornillo")
	# Raspberry Pi arriba de la caja
	_caja(raiz, _p(ext + 0.05, yc - 0.07, zc + 0.14 + 0.012), Vector3(0.065, 0.095, 0.024), "blanco")
	_caja(raiz, _p(ext + 0.05, yc - 0.07, zc + 0.14 + 0.03), Vector3(0.065, 0.095, 0.012), "rpi")

	# ── ventilador ──
	# el mismo ventilador del CAD que está en el otro costado, girado 180°
	_ventilador_espejo(gabinete, armario)

	# ── salidas de ADITIVOS ──
	var za := 0.563
	var ys := [yc - 0.075, yc - 0.025, yc + 0.025, yc + 0.075]
	var sale := 0.07   # cuánto sobresale el conector del panel
	if conectores.size() == 4:
		za = conectores[0].z
		sale = conectores[0].w
		ys = conectores.map(func(c): return c.y)
	var yl: float = (ys[0] + ys[3]) / 2.0
	_caja(raiz, _p(ext + 0.0015, yl, za + 0.075), Vector3(0.003, 0.085, 0.017), "blanco")
	_texto(raiz, "ADITIVOS", _p(ext + 0.0035, yl, za + 0.075), 0.010)
	for i in 4:
		_caja(raiz, _p(ext + 0.0015, ys[i], za + 0.048), Vector3(0.003, 0.02, 0.014), "blanco")
		_texto(raiz, str(i + 1), _p(ext + 0.0035, ys[i], za + 0.048), 0.009)
		# anillo verde del conector estanco (el cuerpo es la pieza del CAD)
		if conectores.size() == 4:
			_cilindro_x(raiz, _p(sale * 0.45, ys[i], za), 0.0135, 0.006, "verde", false)
		else:
			_cilindro_x(raiz, _p(ext + 0.022, ys[i], za), 0.012, 0.030, "negro")
			_cilindro_x(raiz, _p(ext + 0.018, ys[i], za), 0.0125, 0.005, "verde", false)

	# ── pasacables ──
	# Uno solo, adentro del gabinete en la esquina trasera de este costado,
	# del piso al techo. Arriba los cables salen por un agujero del techo.
	var yc_esq := Y_FONDO - 0.03
	var adentro := -PARED - 0.016
	var z_piso := 0.102
	var z_techo := 1.644
	_caja(raiz, _p(adentro, yc_esq, (z_piso + z_techo) / 2.0), Vector3(0.03, 0.03, z_techo - z_piso), "canaleta")
	# pasacables de goma en el agujero del techo
	_cilindro_z(raiz, _p(adentro, yc_esq, ALTO + 0.003), 0.013, 0.008, "negro")

	# ── cables ──
	# haz que sube por el pasacables, sale por el techo y entra por arriba de
	# la caja de control (adentro de la caja está el Arduino)
	var tope_caja := zc + 0.14
	var colores := ["cable_rojo", "cable_azul", "cable_negro", "cable_rojo", "cable_negro"]
	for i in colores.size():
		var d := (i - 2) * 0.005
		_tubo(raiz, [
			_p(adentro + d, yc_esq, z_techo - 0.08),
			_p(adentro + d, yc_esq, ALTO + 0.025),
			_p(ext + 0.02, yc_esq - 0.03 + d, ALTO + 0.045),
			_p(ext + 0.065 + d, yc + 0.10, tope_caja + 0.035),
			_p(ext + 0.065 + d, yc + 0.10, tope_caja - 0.005),
		], 0.0032, colores[i])
	# USB azul: del Arduino (adentro de la caja) a la Raspberry, por fuera
	_tubo(raiz, [
		_p(ext + 0.035, yc + 0.03, tope_caja - 0.005),
		_p(ext + 0.035, yc + 0.03, tope_caja + 0.05),
		_p(ext + 0.05, yc - 0.005, tope_caja + 0.04),
		_p(ext + 0.05, yc - 0.022, tope_caja + 0.022),
	], 0.003, "cable_azul")
	# adentro: mangueras de cada conector de ADITIVOS a su reservorio y cables
	# de las bombas de los reservorios al pasacables
	var reservorios := armario.find_child("Part 119", true, false) as MeshInstance3D
	if reservorios:
		var caja_res: AABB = reservorios.global_transform * reservorios.mesh.get_aabb()
		var inv := gabinete.global_transform.affine_inverse()
		var centro: Vector3 = inv * caja_res.get_center()
		var tope: Vector3 = inv * (caja_res.get_center() + Vector3(0, caja_res.size.y / 2.0, 0))
		var lado: float = absf((inv.basis * Vector3(caja_res.size.x, 0, 0)).x) * 0.25
		var destinos := [
			Vector3(centro.x - lado, centro.y - lado, tope.z),
			Vector3(centro.x + lado, centro.y - lado, tope.z),
			Vector3(centro.x - lado, centro.y + lado, tope.z),
			Vector3(centro.x + lado, centro.y + lado, tope.z),
		]
		for i in 4:
			var ini := _p(-PARED, ys[i], za)
			var fin: Vector3 = destinos[i] + Vector3(0, 0, 0.01)
			_tubo(raiz, [
				ini,
				ini.lerp(fin, 0.35) + Vector3(0, 0, 0.06),
				fin + Vector3(0, 0, 0.08),
				fin,
			], 0.004, "manguera")
			var entrada := _p(adentro - 0.012, yc_esq, za + 0.10 + i * 0.03)
			_tubo(raiz, [
				fin + Vector3(0, 0.01, 0.0),
				fin + Vector3(0, 0.02, 0.10),
				entrada.lerp(fin, 0.3) + Vector3(0, 0, 0.08),
				entrada,
			], 0.0025, "cable_negro")
	# cables de las luces: salen por el agujero del techo y van por encima del
	# armario hasta las dos carcasas de las luces (CAD: x 0.25 y 0.48, y 0.215)
	var salida := _p(adentro, yc_esq, ALTO + 0.008)
	var luces := [Vector3(0.48, 0.215, ALTO), Vector3(0.247, 0.215, ALTO)]
	for i in luces.size():
		var destino: Vector3 = luces[i]
		for j in 2:
			var d := (j - 0.5) * 0.007
			_tubo(raiz, [
				salida + Vector3(0, d, 0),
				salida + Vector3(0, d, 0.012),
				Vector3(lerpf(salida.x, destino.x, 0.5), lerpf(salida.y, destino.y, 0.3) + d, ALTO + 0.005),
				destino + Vector3(_s * 0.045, d, 0.006),
				destino + Vector3(_s * 0.035, d, 0.004),
			], 0.0028, ["cable_rojo", "cable_negro"][j])


# Duplica el ventilador lateral del CAD (está en el costado opuesto) y lo gira
# 180° sobre el eje vertical para ubicarlo en este costado, sobre el panel.
static func _ventilador_espejo(gabinete: MeshInstance3D, armario: Node) -> void:
	var original := armario.find_child("FanIzqLat", true, false) as Node3D
	if original == null:
		return
	var g := gabinete.global_transform
	var c_local: Vector3 = g.affine_inverse() * original.global_position
	if (c_local.x > (X_DER + X_IZQ) / 2.0) == (_s > 0.0):
		return  # ya está de este lado
	var copia := original.duplicate() as Node3D
	copia.name = "FanDerLat"
	original.get_parent().add_child(copia)
	var pivote := Vector3((X_DER + X_IZQ) / 2.0, c_local.y, 0.0)
	var giro := Transform3D(Basis(), pivote) * Transform3D(Basis(Vector3(0, 0, 1), PI), Vector3.ZERO) \
		* Transform3D(Basis(), -pivote)
	var sobre_panel := Transform3D(Basis(), Vector3(_s * 0.012, 0, 0))
	copia.global_transform = g * sobre_panel * giro * g.affine_inverse() * original.global_transform


# Piezas del CAD que atraviesan la pared de este costado (los 4 conectores de
# ADITIVOS). Las pinta de negro y devuelve, ordenadas a lo profundo,
# Vector4(_, y, z, cuánto sobresalen de la cara exterior).
static func _conectores(gabinete: MeshInstance3D, armario: Node) -> Array:
	var inv := gabinete.global_transform.affine_inverse()
	var res := []
	for mi in armario.find_children("*", "MeshInstance3D", true, false):
		if mi == gabinete or mi.get_parent() is MeshInstance3D or mi.mesh == null:
			continue
		if not str(mi.get_path()).contains("Sistema"):
			continue
		var bb: AABB = inv * (mi.global_transform * mi.mesh.get_aabb())
		var sale := (bb.end.x - _xf) if _s > 0.0 else (_xf - bb.position.x)
		var cruza := bb.position.x < _xf and bb.end.x > _xf
		if cruza and sale > 0.005 and bb.size.y < 0.1:
			for s in mi.mesh.get_surface_count():
				mi.set_surface_override_material(s, _mat("negro"))
			mi.layers = CAPA_PANEL
			var c := bb.get_center()
			res.append(Vector4(0.0, c.y, c.z, sale))
	res.sort_custom(func(a, b): return a.y < b.y)
	return res


# punto a una distancia "fuera" de la cara exterior del costado derecho
# (negativo = hacia adentro del gabinete)
static func _p(fuera: float, y: float, z: float) -> Vector3:
	return Vector3(_xf + _s * fuera, y, z)


static func _mat(clave: String) -> StandardMaterial3D:
	if not _mats.has(clave):
		var m := StandardMaterial3D.new()
		m.albedo_color = COLORES[clave][0]
		m.roughness = COLORES[clave][1]
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
		_mats[clave] = m
	return _mats[clave]


static func _emisivo(color: Color, energia: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.emission_enabled = true
	m.emission = color
	m.emission_energy_multiplier = energia
	return m


static func _caja(padre: Node3D, centro: Vector3, tam: Vector3, clave: String, aristas := true) -> MeshInstance3D:
	var m := BoxMesh.new()
	m.size = tam
	return _pieza(padre, m, Transform3D(Basis(), centro), clave, aristas)


# cilindro con el eje hacia afuera del costado (eje X del CAD)
static func _cilindro_x(padre: Node3D, centro: Vector3, radio: float, largo: float, clave: String, aristas := true) -> MeshInstance3D:
	var m := CylinderMesh.new()
	m.top_radius = radio
	m.bottom_radius = radio
	m.height = largo
	m.radial_segments = 24
	m.rings = 1
	return _pieza(padre, m, Transform3D(Basis(Vector3.BACK, PI / 2.0), centro), clave, aristas)


# cilindro vertical (eje Z del CAD)
static func _cilindro_z(padre: Node3D, centro: Vector3, radio: float, largo: float, clave: String) -> MeshInstance3D:
	var m := CylinderMesh.new()
	m.top_radius = radio
	m.bottom_radius = radio
	m.height = largo
	m.radial_segments = 12
	m.rings = 1
	return _pieza(padre, m, Transform3D(Basis(Vector3.RIGHT, PI / 2.0), centro), clave, false)


static func _pieza(padre: Node3D, malla: Mesh, xf: Transform3D, clave: String, aristas: bool) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = malla
	mi.transform = xf
	mi.material_override = _mat(clave)
	mi.layers = CAPA_PANEL
	padre.add_child(mi)
	if aristas:
		Look._agregar_aristas(mi)
	return mi


# texto pegado al panel, mirando hacia afuera
static func _texto(padre: Node3D, texto: String, pos: Vector3, alto: float) -> void:
	var l := Label3D.new()
	l.text = texto
	l.font_size = 64
	l.outline_size = 0
	l.pixel_size = alto / 64.0
	l.modulate = Color(0.08, 0.08, 0.09)
	l.double_sided = false
	var z := Vector3(_s, 0, 0)          # hacia afuera
	var y := Vector3(0, 0, 1)           # arriba
	l.transform = Transform3D(Basis(y.cross(z), y, z), pos)
	padre.add_child(l)


# cable: tubo suave que pasa por los puntos dados
static func _tubo(padre: Node3D, puntos: Array, radio: float, clave: String) -> void:
	var curva := Curve3D.new()
	curva.bake_interval = 0.01
	for i in puntos.size():
		var prev: Vector3 = puntos[maxi(i - 1, 0)]
		var sig: Vector3 = puntos[mini(i + 1, puntos.size() - 1)]
		var t: Vector3 = (sig - prev) * 0.25
		curva.add_point(puntos[i], -t, t)
	var pts := curva.get_baked_points()
	if pts.size() < 2:
		return
	const LADOS := 10
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var normal_prev := Vector3.ZERO
	var anillos := []
	for i in pts.size():
		var tan: Vector3 = (pts[mini(i + 1, pts.size() - 1)] - pts[maxi(i - 1, 0)]).normalized()
		var n: Vector3 = normal_prev
		if n == Vector3.ZERO or absf(n.dot(tan)) > 0.99:
			n = Vector3.UP if absf(tan.dot(Vector3.UP)) < 0.9 else Vector3.RIGHT
		n = (n - tan * n.dot(tan)).normalized()
		normal_prev = n
		var bn := tan.cross(n)
		var anillo := []
		for k in LADOS:
			var ang := TAU * k / LADOS
			var dir := n * cos(ang) + bn * sin(ang)
			anillo.append([pts[i] + dir * radio, dir])
		anillos.append(anillo)
	for i in anillos.size() - 1:
		for k in LADOS:
			var k2 := (k + 1) % LADOS
			for v in [anillos[i][k], anillos[i + 1][k], anillos[i + 1][k2], anillos[i][k], anillos[i + 1][k2], anillos[i][k2]]:
				st.set_normal(v[1])
				st.add_vertex(v[0])
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	mi.material_override = _mat(clave)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.layers = CAPA_PANEL
	padre.add_child(mi)
