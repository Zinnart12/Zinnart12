class_name StarSystem
extends RefCounted

static func temperature_color(kelvin: float) -> Color:
	var t: float = clampf(kelvin, 1000.0, 40000.0) / 100.0
	var r: float = 255.0 if t <= 66.0 else 329.698727446 * pow(t - 60.0, -0.1332047592)
	var g: float = 99.4708025861 * log(t) - 161.1195681661 if t <= 66.0 else 288.1221695283 * pow(t - 60.0, -0.0755148492)
	var b: float = 255.0 if t >= 66.0 else 0.0 if t <= 19.0 else 138.5177312231 * log(t - 10.0) - 305.0447927307
	return Color(clampf(r / 255.0, 0.0, 1.0), clampf(g / 255.0, 0.0, 1.0), clampf(b / 255.0, 0.0, 1.0))

static func create_background() -> MultiMeshInstance3D:
	var stars: MultiMeshInstance3D = MultiMeshInstance3D.new()
	stars.name = "BackgroundStars"
	var mesh: QuadMesh = QuadMesh.new()
	mesh.size = Vector2(11.0, 11.0)
	var material: ShaderMaterial = ShaderMaterial.new()
	material.shader = load("res://shaders/starfield.gdshader")
	mesh.material = material
	var instances: MultiMesh = MultiMesh.new()
	instances.transform_format = MultiMesh.TRANSFORM_3D
	instances.use_colors = true
	instances.mesh = mesh
	instances.instance_count = 4096
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 2031417
	for i: int in range(instances.instance_count):
		var y: float = rng.randf_range(-1.0, 1.0)
		var a: float = rng.randf() * TAU
		var xz: float = sqrt(1.0 - y * y)
		var direction: Vector3 = Vector3(xz * cos(a), y, xz * sin(a))
		var t: Transform3D = Transform3D.IDENTITY
		t.origin = direction * 4000.0
		t.basis = Basis.IDENTITY.scaled(Vector3.ONE * rng.randf_range(0.4, 1.5))
		instances.set_instance_transform(i, t)
		var color: Color = temperature_color(rng.randf_range(3000.0, 15000.0))
		instances.set_instance_color(i, color * rng.randf_range(0.25, 0.85))
	stars.multimesh = instances
	stars.extra_cull_margin = 4500.0
	return stars
