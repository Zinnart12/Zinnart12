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
				distance = clampf(distance * factor, minimum_distance(), 10000.0)
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
	return maxf(universe.display_radii.get(focused_id, 0.000003) * 1.16, 0.000003) if universe != null else 0.01

func focus(id_value: String) -> void:
	if universe == null:
		return
	var body: CelestialBody = universe.engine.find_body(id_value)
	if body == null:
		return
	focused_id = id_value
	target_si = body.position.duplicate()
	distance = maxf(float(universe.display_radii.get(id_value, 1.0)) * 5.2, 0.00001)
	fly_speed = maxf(distance * 0.6, 0.00001)
	update_eye_from_orbit()
	update_camera()

func overview() -> void:
	if universe == null:
		return
	focused_id = ""
	target_si.fill(0.0)
	var extent: float = 0.0
	for body: CelestialBody in universe.engine.bodies:
		var norm2: float = 0.0
		for k: int in range(3):
			norm2 += body.position[k] * body.position[k]
		extent = maxf(extent, sqrt(norm2) * universe.METRES_TO_SCENE + float(universe.display_radii.get(body.id, 1.0)))
	var half_fov: float = deg_to_rad(camera.fov * 0.5)
	distance = maxf(extent / sin(half_fov) * 1.6, 0.02)
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
		eye_si[k] = target_si[k] + offset[k] / universe.METRES_TO_SCENE

func tick(delta: float) -> void:
	if universe == null:
		return
	var focused: CelestialBody = universe.engine.find_body(focused_id)
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
					eye_si[k] += move[k] / universe.METRES_TO_SCENE
	update_camera()

func update_camera() -> void:
	universe.origin_si = target_si.duplicate() if mode == "orbit" else eye_si.duplicate()
	camera.position = universe.to_scene(eye_si)
	var forward: Vector3 = -Vector3(sin(yaw) * cos(pitch), sin(pitch), cos(yaw) * cos(pitch))
	camera.look_at(camera.global_position + forward, Vector3.UP)
	camera.near = maxf(0.0000001, minf(0.002, distance * 0.005))
