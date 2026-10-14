class_name CameraController
extends Node3D

var universe: UniverseManager
var camera: Camera3D
var mode: String = "orbit"
var focused_id: String = ""
var target_si: PackedFloat64Array = PackedFloat64Array([0.0, 0.0, 0.0])
var eye_si: PackedFloat64Array = target_si.duplicate()
var yaw: float = 0.6
var pitch: float = 0.48
var distance: float = 150.0
var fly_speed: float = 20.0
var dragging: bool = false
var press_position: Vector2 = Vector2.ZERO
var zoom_goal: float = 150.0
var zoom_transition: bool = false

func _ready() -> void:
	camera = $Camera3D
	camera.fov = 48.0
	camera.far = 20000.0

func _unhandled_input(event: InputEvent) -> void:
	if universe == null:
		return
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			dragging = event.pressed
			if event.pressed:
				press_position = event.position
			elif press_position.distance_to(event.position) < 5.0:
				universe.pick_body(event.position)
		elif event.pressed and event.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
			var factor: float = 0.84 if event.button_index == MOUSE_BUTTON_WHEEL_UP else 1.0 / 0.84
			if mode == "orbit":
				zoom_goal = clampf((zoom_goal if zoom_transition else distance)*factor,minimum_distance(),10000.0)
				zoom_transition = true
			else:
				fly_speed = clampf(fly_speed / factor, 0.00001, 4000.0)
	if event is InputEventMouseMotion and dragging:
		yaw -= event.relative.x * 0.004
		pitch = clampf(pitch + event.relative.y * 0.004, -1.5, 1.5)
	if event is InputEventKey and event.pressed and not event.echo:
		match event.physical_keycode:
			KEY_F: focus(universe.selected_id)
			KEY_R: overview()
			KEY_C: toggle_mode()
			KEY_W, KEY_A, KEY_S, KEY_D, KEY_Q, KEY_E:
				if mode == "orbit":
					toggle_mode()

func minimum_distance() -> float:
	if universe == null:return 0.01
	var body: CelestialBody = universe.engine.find_body(focused_id)
	var margin: float = 20.0 if body != null and body.kind=="black_hole" else 1.16
	return maxf(universe.display_radii.get(focused_id,0.00000001)*margin,0.00000001)

func focus(id_value: String) -> void:
	if universe == null:
		return
	var body: CelestialBody = universe.engine.find_body(id_value)
	if body == null:
		return
	focused_id = id_value
	universe.select_body(id_value)
	target_si = body.position.duplicate()
	mode = "orbit"
	var radius: float = float(universe.display_radii.get(id_value,1.0))
	if radius<0.1:
		universe.set_render_units(universe.metres_to_scene/maxf(radius,1e-30))
		radius=float(universe.display_radii[id_value])
	var extent: float = radius*(13.0 if body.kind=="black_hole" else 2.4 if body.id=="saturn" else 1.3)
	distance = maxf(extent/sin(deg_to_rad(camera.fov*0.5))*1.2,0.00000003)
	zoom_goal = distance;zoom_transition = false
	if body.kind=="black_hole":pitch=0.18
	elif not body.is_luminous():
		var dominant: CelestialBody=null
		for star: CelestialBody in universe.engine.bodies:
			if star.is_luminous() and (dominant==null or StellarLighting.flux(star,body)>StellarLighting.flux(dominant,body)):dominant=star
		if dominant!=null:
			yaw=atan2(dominant.position[0]-body.position[0],dominant.position[2]-body.position[2])+0.7
			pitch=0.3
	fly_speed = maxf(distance * 0.6, 0.00001)
	update_eye_from_orbit()
	update_camera()

func overview() -> void:
	if universe == null:
		return
	universe.set_render_units(universe.BASE_METRES_TO_SCENE)
	if not universe.engine.bodies.is_empty():
		var extent_si: float=0.0
		for body: CelestialBody in universe.engine.bodies:
			for k: int in range(3):extent_si=maxf(extent_si,absf(body.position[k]))
		if extent_si*universe.metres_to_scene<1.0 and extent_si>0.0:universe.set_render_units(5.0/extent_si)
	focused_id = ""
	mode = "orbit"
	target_si.fill(0.0)
	if not universe.engine.bodies.is_empty():
		for k: int in range(3):
			var minimum: float = INF
			var maximum: float = -INF
			for body: CelestialBody in universe.engine.bodies:
				minimum=minf(minimum,body.position[k]);maximum=maxf(maximum,body.position[k])
			target_si[k]=(minimum+maximum)*0.5
	var extent: float = 0.0
	for body: CelestialBody in universe.engine.bodies:
		var norm2: float = 0.0
		for k: int in range(3):
			norm2 += pow(body.position[k]-target_si[k],2.0)
		extent = maxf(extent, sqrt(norm2)*universe.metres_to_scene+float(universe.display_radii.get(body.id,1.0))*(13.0 if body.kind=="black_hole" else 1.35))
	var half_fov: float = deg_to_rad(camera.fov * 0.5)
	distance = maxf(extent / sin(half_fov) * 1.6, 0.02)
	zoom_goal=distance;zoom_transition=false
	yaw = 0.6
	pitch = 0.65
	fly_speed = maxf(distance * 0.25, 0.00001)
	update_eye_from_orbit()
	update_camera()

func toggle_mode() -> void:
	if mode == "orbit":
		update_eye_from_orbit()
		mode = "fly"
	else:
		mode = "orbit"
		focus(universe.selected_id)

func update_eye_from_orbit() -> void:
	var offset: Vector3 = Vector3(sin(yaw) * cos(pitch), sin(pitch), cos(yaw) * cos(pitch)) * distance
	for k: int in range(3):
		eye_si[k] = target_si[k] + offset[k] / universe.metres_to_scene

func tick(delta: float) -> void:
	if universe == null:
		return
	var focused: CelestialBody = universe.engine.find_body(focused_id)
	if zoom_transition:
		distance=exp(lerpf(log(maxf(distance,1e-12)),log(maxf(zoom_goal,1e-12)),1.0-exp(-delta*12.0)))
		if absf(distance/zoom_goal-1.0)<0.0001:distance=zoom_goal;zoom_transition=false
	if mode == "orbit":
		if focused != null:
			target_si = focused.position.duplicate()
		update_eye_from_orbit()
	else:
		var focus_owner: Control = get_viewport().gui_get_focus_owner()
		if not focus_owner is LineEdit and not focus_owner is TextEdit:
			var forward: Vector3 = -Vector3(sin(yaw) * cos(pitch), sin(pitch), cos(yaw) * cos(pitch))
			var right: Vector3 = forward.cross(Vector3.UP).normalized()
			var move: Vector3 = Vector3.ZERO
			if Input.is_physical_key_pressed(KEY_W): move += forward
			if Input.is_physical_key_pressed(KEY_S): move -= forward
			if Input.is_physical_key_pressed(KEY_D): move += right
			if Input.is_physical_key_pressed(KEY_A): move -= right
			if Input.is_physical_key_pressed(KEY_E): move += Vector3.UP
			if Input.is_physical_key_pressed(KEY_Q): move -= Vector3.UP
			if move.length_squared() > 0.0:
				move = move.normalized() * fly_speed * minf(delta, 0.25) * (4.0 if Input.is_physical_key_pressed(KEY_SHIFT) else 1.0)
				for k: int in range(3):
					eye_si[k] += move[k] / universe.metres_to_scene
	update_camera()

func update_camera() -> void:
	universe.origin_si = target_si.duplicate() if mode == "orbit" else eye_si.duplicate()
	camera.position = universe.to_scene(eye_si)
	var forward: Vector3 = -Vector3(sin(yaw) * cos(pitch), sin(pitch), cos(yaw) * cos(pitch))
	camera.look_at(camera.global_position + forward, Vector3.UP)
	camera.near=clampf(distance*0.005,0.001,20.0)
	camera.far=maxf(8000.0,distance*3.0)
