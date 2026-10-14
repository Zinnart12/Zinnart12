class_name UniverseManager
extends Node3D

const UNITS_PER_AU: float = 32.0
const METRES_TO_SCENE: float = UNITS_PER_AU / GravitySolver.AU
var engine: SimulationEngine = SimulationEngine.new()
var clock: TimeController = TimeController.new()
var generator: PlanetGenerator = PlanetGenerator.new()
var origin_si: PackedFloat64Array = PackedFloat64Array([0.0, 0.0, 0.0])
var visuals: Dictionary = {}
var display_radii: Dictionary = {}
var trail_history: Dictionary = {}
var trail_nodes: Dictionary = {}
var trail_buffers: Dictionary = {}
var previous_origin: PackedFloat64Array = PackedFloat64Array([INF,INF,INF])
var selected_id: String = "earth"
var true_scale: bool = false
var show_trails: bool = true
var show_labels: bool = true
var quality: int = 1
var stars: MultiMeshInstance3D
var world: WorldEnvironment
var last_trail_time: float = -1.0
var adaptive_elapsed: float = 0.0
var adaptive_scale: float = 1.0
var label_layer: CanvasLayer
var labels: Dictionary = {}
@onready var camera_rig: CameraController = $CameraRig
@onready var ui: SandboxUI = $SandboxUI
@onready var body_root: Node3D = $Bodies

func _ready() -> void:
	world = WorldEnvironment.new()
	var env: Environment = Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("03070d")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("506b83")
	env.ambient_light_energy = 0.16
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.glow_enabled = true
	env.glow_intensity = 0.35
	env.glow_bloom = 0.04
	env.glow_hdr_threshold = 1.2
	world.environment = env
	add_child(world)
	stars = StarSystem.create_background()
	add_child(stars)
	label_layer = CanvasLayer.new()
	label_layer.layer = 0
	add_child(label_layer)
	camera_rig.universe = self
	load_preset("solar")
	camera_rig.focus(selected_id)
	set_quality(GraphicsMenu.selected_quality)
	if get_tree().has_meta("restore_cosmic"):
		restore(get_tree().get_meta("restore_cosmic"))
		get_tree().remove_meta("restore_cosmic")

func to_scene(p: PackedFloat64Array) -> Vector3:
	# Subtract doubles BEFORE constructing float32 Vector3.
	return Vector3((p[0] - origin_si[0]) * METRES_TO_SCENE, (p[1] - origin_si[1]) * METRES_TO_SCENE, (p[2] - origin_si[2]) * METRES_TO_SCENE)

func load_preset(preset: String) -> void:
	var bodies: Array[CelestialBody] = SolarSystemPreset.create()
	var title: String = "Solar System"
	if preset == "earthmoon":
		bodies = SolarSystemPreset.earth_moon()
		title = "Earth & Moon"
	elif preset == "binary":
		bodies = SolarSystemPreset.binary()
		title = "Binary Stars"
	engine.load_bodies(bodies, title)
	clock.pending = 0.0
	selected_id = "earth" if engine.find_body("earth") != null else bodies[0].id
	clear_visuals()
	sync_visuals()
	ui.rebuild_body_list()
	camera_rig.overview()
	ui.refresh()

func clear_visuals() -> void:
	for root: Node3D in visuals.values(): root.queue_free()
	for trail: MeshInstance3D in trail_nodes.values(): trail.queue_free()
	for label: Label in labels.values(): label.queue_free()
	visuals.clear()
	trail_nodes.clear()
	trail_buffers.clear()
	trail_history.clear()
	labels.clear()
	last_trail_time = -1.0

func sync_visuals() -> void:
	var ids: Dictionary = {}
	for b: CelestialBody in engine.bodies:
		ids[b.id] = true
		if not visuals.has(b.id):
			var root: Node3D = generator.create(b)
			body_root.add_child(root)
			visuals[b.id] = root
			trail_history[b.id] = []
			var trail: MeshInstance3D = MeshInstance3D.new()
			trail.name = "Trail_" + b.id
			var points: PackedVector3Array = PackedVector3Array()
			points.resize(360)
			points.fill(Vector3.ZERO)
			trail_buffers[b.id] = points
			var arrays: Array = []
			arrays.resize(Mesh.ARRAY_MAX)
			arrays[Mesh.ARRAY_VERTEX] = points
			var mesh: ArrayMesh = ArrayMesh.new()
			mesh.add_surface_from_arrays(Mesh.PRIMITIVE_LINE_STRIP, arrays, [], {}, Mesh.ARRAY_FLAG_USE_DYNAMIC_UPDATE)
			var material: StandardMaterial3D = StandardMaterial3D.new()
			material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			material.albedo_color = b.color * 0.45
			mesh.surface_set_material(0, material)
			trail.mesh = mesh
			trail_nodes[b.id] = trail
			body_root.add_child(trail)
			var label: Label = Label.new()
			label.add_theme_font_size_override("font_size", 13)
			label.add_theme_color_override("font_color", Color("b3c6d4"))
			label.add_theme_color_override("font_shadow_color", Color.BLACK)
			label.add_theme_constant_override("shadow_offset_x", 1)
			label.add_theme_constant_override("shadow_offset_y", 1)
			label.mouse_filter = Control.MOUSE_FILTER_IGNORE
			label_layer.add_child(label)
			labels[b.id] = label
	for id_value: String in visuals.keys():
		if not ids.has(id_value):
			visuals[id_value].queue_free()
			trail_nodes[id_value].queue_free()
			labels[id_value].queue_free()
			visuals.erase(id_value)
			trail_nodes.erase(id_value)
			trail_buffers.erase(id_value)
			labels.erase(id_value)
			trail_history.erase(id_value)
	if engine.find_body(selected_id) == null:
		selected_id = engine.bodies[0].id if not engine.bodies.is_empty() else ""
	calculate_display_radii()

func calculate_display_radii() -> void:
	display_radii.clear()
	for b: CelestialBody in engine.bodies:
		var physical: float = b.radius * METRES_TO_SCENE
		var display: float = 2.45 * pow(b.radius / 695700000.0, 0.42) if b.kind == "star" else 0.64 * pow(b.radius / 6371000.0, 0.42)
		display_radii[b.id] = physical if true_scale else maxf(physical, display)
	if true_scale:
		return
	var factors: Dictionary = {}
	for b: CelestialBody in engine.bodies: factors[b.id] = 1.0
	for i: int in range(engine.bodies.size()):
		for j: int in range(i + 1, engine.bodies.size()):
			var a: CelestialBody = engine.bodies[i]
			var b: CelestialBody = engine.bodies[j]
			var d2: float = 0.0
			for k: int in range(3): d2 += pow(a.position[k] - b.position[k], 2.0)
			var factor: float = sqrt(d2) * METRES_TO_SCENE * 0.82 / (display_radii[a.id] + display_radii[b.id])
			factors[a.id] = minf(factors[a.id], factor)
			factors[b.id] = minf(factors[b.id], factor)
	for b: CelestialBody in engine.bodies:
		display_radii[b.id] = maxf(b.radius * METRES_TO_SCENE, display_radii[b.id] * factors[b.id])

func _process(delta: float) -> void:
	if camera_rig.universe == null:
		return
	clock.accumulate(delta)
	var requested: float = clock.take_request()
	if requested > 0.0:
		var count: int = engine.bodies.size()
		engine.advance(requested)
		if engine.limited: clock.pending = 0.0
		if count != engine.bodies.size():
			sync_visuals()
			ui.rebuild_body_list()
	calculate_display_radii()
	camera_rig.tick(delta)
	update_rendering()
	ui.tick(delta)
	adaptive_elapsed += delta
	if quality == 1 and adaptive_elapsed > 3.0:
		adaptive_elapsed = 0.0
		var fps: float = Engine.get_frames_per_second()
		if fps > 0.0 and fps < 35.0: adaptive_scale = maxf(0.55, adaptive_scale * 0.85)
		elif fps > 58.0: adaptive_scale = minf(1.0, adaptive_scale * 1.1)
		get_viewport().scaling_3d_scale = adaptive_scale

func update_rendering() -> void:
	stars.position = camera_rig.camera.position
	var sun: CelestialBody = null
	for b: CelestialBody in engine.bodies:
		if b.kind == "star" and (sun == null or b.mass > sun.mass): sun = b
	var add_trail: bool = engine.time != last_trail_time
	var origin_moved: bool = origin_si != previous_origin
	for b: CelestialBody in engine.bodies:
		var root: Node3D = visuals[b.id]
		root.position = to_scene(b.position)
		root.scale = Vector3.ONE * float(display_radii[b.id])
		root.rotation = Vector3(deg_to_rad(b.axial_tilt), fmod(engine.time / b.rotation_period, 1.0) * TAU if absf(b.rotation_period) > 1.0 else 0.0, 0.0)
		var shader: ShaderMaterial = root.get_node("Surface").material_override
		shader.set_shader_parameter("sim_time", engine.time / 3600.0)
		shader.set_shader_parameter("temperature", b.temperature)
		var direction: Vector3 = Vector3.RIGHT
		if sun != null and sun.id != b.id:
			direction = Vector3(sun.position[0] - b.position[0], sun.position[1] - b.position[1], sun.position[2] - b.position[2]).normalized()
			shader.set_shader_parameter("sunlight_direction", direction)
		if root.has_node("Atmosphere"):
			root.get_node("Atmosphere").material_override.set_shader_parameter("sunlight_direction", direction)
		if root.has_node("Clouds"):
			root.get_node("Clouds").material_override.set_shader_parameter("sim_time", engine.time / 3600.0)
		var distance: float = camera_rig.camera.position.distance_to(root.position)
		generator.set_lod(root, float(display_radii[b.id]) / maxf(distance, 0.0000001), quality)
		if add_trail:
			var history: Array = trail_history[b.id]
			history.append(b.position.duplicate())
			if history.size() > 360: history.pop_front()
		trail_nodes[b.id].visible = show_trails and trail_history[b.id].size() > 1
		if add_trail or origin_moved:
			update_trail(b)
		var label: Label = labels[b.id]
		label.text = b.body_name
		label.modulate = Color("8ce8d3") if b.id == selected_id else Color.WHITE
		label.visible = show_labels and not camera_rig.camera.is_position_behind(root.position)
		if label.visible:
			label.position = camera_rig.camera.unproject_position(root.position) + Vector2(14, -8)
	last_trail_time = engine.time
	previous_origin = origin_si.duplicate()

func update_trail(b: CelestialBody) -> void:
	var node: MeshInstance3D = trail_nodes[b.id]
	var history: Array = trail_history[b.id]
	node.visible = show_trails and history.size() > 1
	if not node.visible: return
	var points: PackedVector3Array = trail_buffers[b.id]
	for i: int in range(360):
		points[i] = to_scene(history[mini(i,history.size()-1)])
	var mesh: ArrayMesh = node.mesh
	mesh.surface_update_vertex_region(0, 0, points.to_byte_array())

func select_body(id_value: String) -> void:
	if engine.find_body(id_value) != null:
		selected_id = id_value
		ui.refresh()

func pick_body(screen_position: Vector2) -> void:
	var eye: Vector3 = camera_rig.camera.project_ray_origin(screen_position)
	var ray: Vector3 = camera_rig.camera.project_ray_normal(screen_position)
	var nearest: float = INF
	var id_value: String = ""
	for b: CelestialBody in engine.bodies:
		var p: Vector3 = eye - visuals[b.id].position
		var projection: float = p.dot(ray)
		var disc: float = projection * projection - (p.length_squared() - pow(float(display_radii[b.id]), 2.0))
		if disc < 0.0: continue
		var distance: float = -projection - sqrt(disc)
		if distance > 0.0 and distance < nearest:
			nearest = distance
			id_value = b.id
	if not id_value.is_empty(): select_body(id_value)

func edit_mass(text: String) -> void:
	var body: CelestialBody = engine.find_body(selected_id)
	if body == null or not text.is_valid_float() or not is_finite(text.to_float()) or text.to_float() < 1e-6 or text.to_float() > 1e35:
		ui.notify("Mass must be finite and between 1e-6 and 1e35 kg.")
		return
	body.mass = text.to_float()
	engine.reset_baseline()
	ui.refresh()

func set_quality(value: int) -> void:
	quality = value
	adaptive_scale = 0.7 if value == 0 else 1.0
	get_viewport().scaling_3d_scale = adaptive_scale
	get_viewport().msaa_3d = Viewport.MSAA_DISABLED if value == 0 else Viewport.MSAA_2X if value == 1 else Viewport.MSAA_4X
	world.environment.glow_enabled = value != 0

func restore(data: Dictionary) -> void:
	var error: String = SaveSystem.validate(data)
	if not error.is_empty():
		ui.notify(error)
		return
	var bodies: Array[CelestialBody] = []
	for value: Dictionary in data.bodies: bodies.append(CelestialBody.from_dict(value))
	engine.load_bodies(bodies, data.name, data.time)
	engine.steps = int(data.steps)
	clock.set_running(false)
	clear_visuals()
	sync_visuals()
	selected_id = bodies[0].id if not bodies.is_empty() else ""
	ui.rebuild_body_list()
	camera_rig.overview()
	ui.refresh()
