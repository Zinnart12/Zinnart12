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
	var root: Node3D = Node3D.new()
	root.name = body.id.replace("-", "_")
	var surface: MeshInstance3D = MeshInstance3D.new()
	surface.name = "Surface"
	surface.mesh = sphere_medium
	var material: ShaderMaterial = load("res://materials/Star.tres").duplicate() if body.kind == "star" else load("res://materials/Planet.tres").duplicate()
	material.set_shader_parameter("seed", fmod(body.seed, 10000.0) * 0.0137)
	if body.kind == "star":
		material.set_shader_parameter("temperature_color", StarSystem.temperature_color(body.temperature))
	else:
		material.set_shader_parameter("base_color", body.color)
		material.set_shader_parameter("surface_kind", ["earth", "rocky", "gas", "ice", "lava", "ocean"].find(body.surface))
	surface.material_override = material
	root.add_child(surface)
	if body.atmosphere > 0.0 or body.kind == "star":
		var halo: MeshInstance3D = MeshInstance3D.new()
		halo.name = "Atmosphere"
		halo.mesh = sphere_medium
		var halo_material: ShaderMaterial = ShaderMaterial.new()
		halo_material.shader = load("res://shaders/atmosphere.gdshader")
		halo_material.set_shader_parameter("tint", StarSystem.temperature_color(body.temperature) if body.kind == "star" else Color("488ce6"))
		halo_material.set_shader_parameter("strength", 0.25 if body.kind == "star" else clampf(body.atmosphere, 0.0, 1.0) * 0.48)
		halo.material_override = halo_material
		halo.scale = Vector3.ONE * (1.1 if body.kind == "star" else 1.045)
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
		var ring_material: StandardMaterial3D = StandardMaterial3D.new()
		ring_material.vertex_color_use_as_albedo = true
		ring_material.cull_mode = BaseMaterial3D.CULL_DISABLED
		ring_material.roughness = 0.95
		ring.material_override = ring_material
		root.add_child(ring)
	if body.kind == "star":
		var light: OmniLight3D = OmniLight3D.new()
		light.name = "Starlight"
		light.light_color = StarSystem.temperature_color(body.temperature)
		light.light_energy = 1.3
		light.omni_range = 8000.0
		# Exposure-normalized scene illumination. Climate/radiative transfer is a later phase.
		light.omni_attenuation = 0.0
		light.shadow_enabled = false
		root.add_child(light)
	return root

func set_lod(root: Node3D, angular_radius: float, quality: int) -> void:
	var mesh: SphereMesh = sphere_low if angular_radius < 0.01 else sphere_medium
	if quality == 2 and angular_radius > 0.1:
		mesh = sphere_high
	for node: Node in root.get_children():
		if node is MeshInstance3D and node.name in ["Surface", "Atmosphere", "Clouds"]:
			node.mesh = mesh
