class_name PlanetGenerator
extends RefCounted

var sphere_high: SphereMesh = SphereMesh.new()
var sphere_low: SphereMesh = SphereMesh.new()
var sphere_medium: SphereMesh = SphereMesh.new()

func _init() -> void:
	for mesh: SphereMesh in [sphere_high, sphere_medium, sphere_low]:
		mesh.radius = 1.0
		mesh.height = 2.0
	sphere_high.radial_segments = 96
	sphere_high.rings = 48
	sphere_medium.radial_segments = 64
	sphere_medium.rings = 32
	sphere_low.radial_segments = 24
	sphere_low.rings = 12

func create(body: CelestialBody) -> Node3D:
	if body.kind == "black_hole":
		return load("res://scenes/BlackHole.tscn").instantiate()
	var root: Node3D = Node3D.new()
	root.name = body.id.replace("-", "_")
	var surface: MeshInstance3D = MeshInstance3D.new()
	surface.name = "Surface"
	surface.mesh = sphere_medium
	var material: ShaderMaterial = load("res://materials/Star.tres").duplicate() if body.is_luminous() else load("res://materials/Planet.tres").duplicate()
	material.set_shader_parameter("seed", fmod(body.seed, 10000.0) * 0.0137)
	if body.is_luminous():
		material.set_shader_parameter("temperature_color", StarSystem.temperature_color(body.temperature))
	else:
		material.set_shader_parameter("base_color", body.color)
		material.set_shader_parameter("surface_kind", ["earth", "rocky", "gas", "ice", "lava", "ocean"].find(body.surface))
		material.set_shader_parameter("has_rings",body.id == "saturn")
		material.set_shader_parameter("great_red_spot",body.id == "jupiter")
		material.set_shader_parameter("mars_surface",body.id == "mars")
	material.set_shader_parameter("temperature",body.temperature)
	surface.material_override = material
	root.add_child(surface)
	if body.atmosphere > 0.0 or body.is_luminous():
		var halo: MeshInstance3D = MeshInstance3D.new()
		halo.name = "Atmosphere"
		halo.mesh = sphere_medium
		if body.is_luminous():
			var corona_quad: QuadMesh=QuadMesh.new()
			corona_quad.size=Vector2(6.0,6.0)
			halo.mesh=corona_quad
		var halo_material: ShaderMaterial = ShaderMaterial.new()
		halo_material.shader = load("res://shaders/corona.gdshader") if body.is_luminous() else load("res://shaders/atmosphere.gdshader")
		halo_material.set_shader_parameter("tint", StarSystem.temperature_color(body.temperature) if body.is_luminous() else Color("488ce6"))
		halo_material.set_shader_parameter("strength", clampf(body.atmosphere, 0.0, 1.0) * 0.48)
		halo.material_override = halo_material
		halo.scale = Vector3.ONE * (1.0 if body.is_luminous() else 1.045)
		root.add_child(halo)
	if body.surface == "earth":
		var clouds: MeshInstance3D = MeshInstance3D.new()
		clouds.name = "Clouds"
		clouds.mesh = sphere_medium
		var cloud_material: ShaderMaterial = ShaderMaterial.new()
		cloud_material.shader = load("res://shaders/clouds.gdshader")
		clouds.material_override = cloud_material
		clouds.scale = Vector3.ONE * 1.012
		root.add_child(clouds)
	if body.id == "saturn":
		var ring: MeshInstance3D = MeshInstance3D.new()
		ring.name = "Rings"
		var ring_mesh: ArrayMesh = ArrayMesh.new()
		var vertices: PackedVector3Array = PackedVector3Array()
		var normals: PackedVector3Array = PackedVector3Array()
		var colors: PackedColorArray = PackedColorArray()
		for i: int in range(192):
			for r: float in [1.35, 2.4]:
				for j: int in [0, 1]:
					var angle: float = float(i + j) * TAU / 192.0
					vertices.append(Vector3(cos(angle) * r, 0.0, sin(angle) * r))
					normals.append(Vector3.UP)
					colors.append(Color("bca782"))
		var indices: PackedInt32Array = PackedInt32Array()
		for i: int in range(192):
			var base: int = i * 4
			indices.append_array(PackedInt32Array([base, base + 2, base + 1, base + 1, base + 2, base + 3]))
		var arrays: Array = []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = vertices
		arrays[Mesh.ARRAY_NORMAL] = normals
		arrays[Mesh.ARRAY_COLOR] = colors
		arrays[Mesh.ARRAY_INDEX] = indices
		ring_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		ring.mesh = ring_mesh
		var ring_material: ShaderMaterial = ShaderMaterial.new()
		ring_material.shader = load("res://shaders/rings.gdshader")
		ring.material_override = ring_material
		root.add_child(ring)
	if body.is_luminous():
		for i: int in range(3):
			var flare: MeshInstance3D = MeshInstance3D.new()
			flare.name = "Prominence"+str(i)
			var arc: TorusMesh = TorusMesh.new()
			arc.inner_radius = 0.16
			arc.outer_radius = 0.22
			arc.rings = 24
			arc.ring_segments = 8
			flare.mesh = arc
			flare.position = Vector3(0.0,0.95,0.0).rotated(Vector3.FORWARD,float(i)*2.1)
			flare.rotation = Vector3(PI/2.0,0.0,float(i)*2.1)
			var flare_material: ShaderMaterial = ShaderMaterial.new()
			flare_material.shader = load("res://shaders/prominence.gdshader")
			flare_material.set_shader_parameter("tint",StarSystem.temperature_color(body.temperature))
			flare.material_override = flare_material
			root.add_child(flare)
		var light: OmniLight3D = OmniLight3D.new()
		light.name = "Starlight"
		light.light_color = StarSystem.temperature_color(body.temperature)
		light.light_energy = 1.3
		light.omni_range = 8000.0
		# Exposure-normalized scene illumination. Climate/radiative transfer is a later phase.
		light.omni_attenuation = 2.0
		light.shadow_enabled = false
		root.add_child(light)
	if body.kind in ["neutron_star", "pulsar"]:
		var axis: Node3D = Node3D.new()
		axis.name = "MagneticAxis"
		axis.rotation.z = deg_to_rad(body.magnetic_axis)
		root.add_child(axis)
		for sign_value: float in [-1.0,1.0]:
			var beam: MeshInstance3D = MeshInstance3D.new()
			var cone: CylinderMesh = CylinderMesh.new()
			cone.top_radius = 0.12; cone.bottom_radius = 2.5; cone.height = 16.0
			beam.mesh = cone
			beam.position.y = sign_value*8.5
			if sign_value>0: beam.rotation.z = PI
			var beam_material: ShaderMaterial = ShaderMaterial.new()
			beam_material.shader = load("res://shaders/pulsar.gdshader")
			beam.material_override = beam_material
			axis.add_child(beam)
	return root

func set_lod(root: Node3D, angular_radius: float, quality: int) -> void:
	if root is BlackHoleRenderer:return
	var mesh: SphereMesh = sphere_low if quality==0 or angular_radius < 0.01 else sphere_medium
	if quality == 2 and angular_radius > 0.1:
		mesh = sphere_high
	for node: Node in root.get_children():
		if node is MeshInstance3D and node.name in ["Surface", "Atmosphere", "Clouds"]:
			if node.mesh is SphereMesh:node.mesh=mesh
