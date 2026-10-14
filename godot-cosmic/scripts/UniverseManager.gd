class_name UniverseManager
extends Node3D

const UNITS_PER_AU: float = 32.0
const BASE_METRES_TO_SCENE: float = UNITS_PER_AU / GravitySolver.AU
var metres_to_scene: float = BASE_METRES_TO_SCENE
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
var markers: BodyMarkers
var spawn_serial: int = 0
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
	env.ambient_light_energy = 0.025
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
	markers = BodyMarkers.new()
	markers.universe = self
	label_layer.add_child(markers)
	camera_rig.universe = self
	load_preset("solar")
	set_quality(GraphicsMenu.selected_quality)
	if get_tree().has_meta("restore_cosmic"):
		restore(get_tree().get_meta("restore_cosmic"))
		get_tree().remove_meta("restore_cosmic")

func set_render_units(value: float) -> void:
	metres_to_scene=value
	previous_origin=PackedFloat64Array([INF,INF,INF])
	calculate_display_radii()

func to_scene(p: PackedFloat64Array) -> Vector3:
	# Subtract doubles BEFORE constructing float32 Vector3.
	return Vector3((p[0] - origin_si[0]) * metres_to_scene, (p[1] - origin_si[1]) * metres_to_scene, (p[2] - origin_si[2]) * metres_to_scene)

func load_preset(preset: String) -> void:
	var bodies: Array[CelestialBody] = SolarSystemPreset.create()
	var title: String = "Solar System"
	if preset == "earthmoon":
		bodies = SolarSystemPreset.earth_moon()
		title = "Earth & Moon"
	elif preset == "binary":
		bodies = SolarSystemPreset.binary()
		title = "Binary Stars"
	elif preset in ["observatory","earthhole","solarhole","neutronhole","binaryhole","disk"]:
		bodies = CompactPresets.create(preset)
		for entry: Array in CompactPresets.ENTRIES:
			if entry[1]==preset:title=entry[0]
	engine.load_bodies(bodies, title)
	clock.pending = 0.0
	selected_id = "earth" if engine.find_body("earth") != null else bodies[0].id
	clear_visuals()
	sync_visuals()
	ui.rebuild_body_list()
	camera_rig.overview()
	if preset in ["observatory","disk"]: camera_rig.focus(bodies[0].id)
	clock.speed = 0.01 if preset in ["binaryhole","neutronhole"] else 60.0 if preset=="earthhole" else GravitySolver.DAY
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
		var physical: float = b.radius * metres_to_scene
		var display: float = 2.45 * pow(b.radius / 695700000.0, 0.42) if b.kind == "star" else 0.64 * pow(b.radius / 6371000.0, 0.42)
		if b.kind == "black_hole": display = maxf(physical,0.28)
		display_radii[b.id] = physical if true_scale else maxf(physical,display*metres_to_scene/BASE_METRES_TO_SCENE)
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
			var factor: float = sqrt(d2) * metres_to_scene * 0.82 / (display_radii[a.id] + display_radii[b.id])
			factors[a.id] = minf(factors[a.id], factor)
			factors[b.id] = minf(factors[b.id], factor)
	for b: CelestialBody in engine.bodies:
		display_radii[b.id] = maxf(b.radius * metres_to_scene, display_radii[b.id] * factors[b.id])

func _process(delta: float) -> void:
	if camera_rig.universe == null:
		return
	clock.accumulate(delta)
	var requested: float = clock.take_request()
	if requested > 0.0:
		engine.advance(requested)
		if engine.limited: clock.pending = 0.0
		var changed: bool=engine.bodies.size()!=visuals.size()
		if not changed:
			for body: CelestialBody in engine.bodies:
				if not visuals.has(body.id):changed=true;break
		if changed:
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
		if fps > 0.0 and fps < 35.0: adaptive_scale = maxf(0.55,adaptive_scale*0.85)
		elif fps > 58.0: adaptive_scale = minf(float(GraphicsMenu.settings.render_scale),adaptive_scale*1.1)
		get_viewport().scaling_3d_scale = adaptive_scale

func update_rendering() -> void:
	stars.position = camera_rig.camera.position
	# Sky must stay behind the viewed system, including very massive holes.
	stars.scale=Vector3.ONE*(camera_rig.camera.far*0.8/4000.0)
	var add_trail: bool = engine.time != last_trail_time
	var origin_moved: bool = origin_si != previous_origin
	for b: CelestialBody in engine.bodies:
		var root: Node3D = visuals[b.id]
		root.position = to_scene(b.position)
		root.scale = Vector3.ONE * float(display_radii[b.id])
		root.rotation = Vector3(deg_to_rad(b.axial_tilt), fmod(engine.time / b.rotation_period, 1.0) * TAU if absf(b.rotation_period) > 1e-6 else 0.0, 0.0)
		if root is BlackHoleRenderer:
			root.rotation = Vector3.ZERO
			root.update_view(b,engine.time,int(GraphicsMenu.settings.black_hole_quality))
		var shader: ShaderMaterial = root.get_node("Surface").material_override
		if not root is BlackHoleRenderer:shader.set_shader_parameter("sim_time", engine.time / 3600.0)
		shader.set_shader_parameter("temperature", b.temperature)
		if b.is_luminous():shader.set_shader_parameter("temperature_color",StarSystem.temperature_color(b.temperature))
		shader.set_shader_parameter("detail_quality",GraphicsMenu.settings.star_detail if b.is_luminous() else GraphicsMenu.settings.texture_detail)
		shader.set_shader_parameter("shadow_quality",GraphicsMenu.settings.shadow_quality)
		shader.set_shader_parameter("ring_axis",root.basis.y.normalized())
		StellarLighting.apply(root,b,engine.bodies,engine.simulation_name=="Earth & Moon")
		if root.has_node("Atmosphere"):
			root.get_node("Atmosphere").material_override.set_shader_parameter("sim_time",engine.time/3600.0)
			if b.is_luminous():root.get_node("Atmosphere").material_override.set_shader_parameter("tint",StarSystem.temperature_color(b.temperature))
		if root.has_node("Clouds"):
			root.get_node("Clouds").material_override.set_shader_parameter("sim_time", engine.time / 3600.0)
		for child: Node in root.get_children():
			if child.name.begins_with("Prominence"):
				child.material_override.set_shader_parameter("sim_time",engine.time/3600.0)
				child.visible = int(GraphicsMenu.settings.particle_quality)>0
			if child.name=="MagneticAxis":
				child.visible=int(GraphicsMenu.settings.particle_quality)>0
				child.rotation.z=deg_to_rad(b.magnetic_axis)
		var distance: float = camera_rig.camera.position.distance_to(root.position)
		generator.set_lod(root,float(display_radii[b.id])/maxf(distance,1e-12) if GraphicsMenu.settings.lod else 1.0,int(GraphicsMenu.settings.planet_detail))
		if add_trail:
			var history: Array = trail_history[b.id]
			history.append(b.position.duplicate())
			if history.size() > 360: history.pop_front()
		trail_nodes[b.id].visible = show_trails and trail_history[b.id].size() > 1
		if add_trail or origin_moved:
			update_trail(b)
		var label: Label = labels[b.id]
		label.visible = false
	markers.rebuild()
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
	var marker_id: String = markers.pick(screen_position)
	if not marker_id.is_empty():
		select_body(marker_id)
		return
	var eye: Vector3 = camera_rig.camera.project_ray_origin(screen_position)
	var ray: Vector3 = camera_rig.camera.project_ray_normal(screen_position)
	var nearest: float = INF
	var id_value: String = ""
	for b: CelestialBody in engine.bodies:
		var p: Vector3 = eye - visuals[b.id].position
		var projection: float = p.dot(ray)
		var pick_radius: float=float(display_radii[b.id])*(sqrt(27.0)/2.0 if b.kind=="black_hole" else 1.0)
		var disc: float = projection * projection - (p.length_squared() - pick_radius*pick_radius)
		if disc < 0.0: continue
		var distance: float = -projection - sqrt(disc)
		if distance > 0.0 and distance < nearest:
			nearest = distance
			id_value = b.id
	if not id_value.is_empty(): select_body(id_value)

func edit_mass(text: String) -> void:
	var body: CelestialBody = engine.find_body(selected_id)
	if body == null or not text.is_valid_float() or not is_finite(text.to_float()) or text.to_float() < 1e-6 or text.to_float() > 1e41:
		ui.notify("Mass must be finite and between 1e-6 and 1e41 kg.")
		return
	var candidate: CelestialBody=body.detached_copy()
	candidate.mass=text.to_float()
	if candidate.kind=="black_hole":candidate.radius=BlackHoleSystem.schwarzschild_radius(candidate.mass)
	var error: String=SaveSystem.validate({"schema_version":1,"name":"Mass edit","time":0.0,"steps":0,"bodies":[candidate.to_dict()]})
	if not error.is_empty():ui.notify(error);return
	body.mass=candidate.mass
	body.radius=candidate.radius
	engine.reset_baseline()
	ui.refresh()

func set_quality(value: int) -> void:
	quality = value
	adaptive_scale = 0.7 if value == 0 else 1.0
	get_viewport().scaling_3d_scale = adaptive_scale
	get_viewport().msaa_3d = Viewport.MSAA_DISABLED if value == 0 else Viewport.MSAA_2X if value == 1 else Viewport.MSAA_4X
	world.environment.glow_enabled = value != 0
	stars.multimesh.visible_instance_count=[1024,2048,4096][int(GraphicsMenu.settings.particle_quality)]
	if ui.graphics != null:
		if value != GraphicsMenu.selected_quality:
			ui.graphics.select_preset(value)
		ui.graphics.apply_to(self)

func add_object(index: int) -> void:
	if engine.bodies.size()>=128:ui.notify("Maximum 128 force-bearing bodies.");return
	var body: CelestialBody = CompactPresets.object(index)
	spawn_serial += 1
	body.id += "-added-"+str(spawn_serial)
	while engine.find_body(body.id)!=null:
		spawn_serial+=1;body.id=body.kind+"-added-"+str(spawn_serial)
	var anchor: CelestialBody = engine.find_body(selected_id)
	if anchor != null:
		var distance: float = maxf((anchor.radius+body.radius)*8.0,2e8)
		if anchor.kind == "black_hole" and body.kind != "black_hole":distance=maxf(distance,BlackHoleSystem.tidal_state(anchor,body,1e12).roche*1.4)
		body.position = anchor.position.duplicate()
		body.velocity = anchor.velocity.duplicate()
		body.position[0] += distance
		body.velocity[2] += sqrt(GravitySolver.G*(anchor.mass+body.mass)/distance)
	engine.bodies.append(body)
	engine.reset_baseline()
	selected_id=body.id
	sync_visuals();ui.rebuild_body_list();camera_rig.focus(body.id);ui.refresh()
	ui.notify("Added "+body.body_name+" to the N-body solver.")

func delete_selected() -> void:
	var body: CelestialBody=engine.find_body(selected_id)
	if body==null:return
	engine.bodies.erase(body);engine.reset_baseline();sync_visuals();ui.rebuild_body_list();ui.refresh()

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
