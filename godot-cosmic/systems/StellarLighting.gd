class_name StellarLighting
extends RefCounted

const SIGMA: float = 5.670374419e-8
const EARTH_FLUX: float = 1361.0

static func flux(source: CelestialBody, receiver: CelestialBody) -> float:
	var r2: float = 0.0
	for k: int in range(3): r2 += pow(source.position[k] - receiver.position[k], 2.0)
	return source.luminosity() / (4.0 * PI * maxf(r2, source.radius * source.radius))

static func apply(root: Node3D, receiver: CelestialBody, bodies: Array[CelestialBody], external_sun: bool = false) -> void:
	var sources: Array[CelestialBody] = []
	for b: CelestialBody in bodies:
		if b.is_luminous() and b.id != receiver.id: sources.append(b)
	if external_sun:
		var sun: CelestialBody = SolarSystemPreset.body("external-sun","External Sun lighting","star",GravitySolver.MSUN,695700000.0,5772.0,"fff2c5")
		sun.position[0] = -GravitySolver.AU
		sources.append(sun)
	sources.sort_custom(func(a: CelestialBody, b: CelestialBody) -> bool: return flux(a,receiver) > flux(b,receiver))
	var dirs: PackedVector3Array = PackedVector3Array()
	var colors: PackedColorArray = PackedColorArray()
	dirs.resize(4)
	colors.resize(4)
	var dominant: Vector3 = Vector3.RIGHT
	for i: int in range(mini(sources.size(),4)):
		var b: CelestialBody = sources[i]
		dirs[i] = Vector3(b.position[0]-receiver.position[0],b.position[1]-receiver.position[1],b.position[2]-receiver.position[2]).normalized()
		var color: Color = StarSystem.temperature_color(b.temperature)
		# SI irradiance remains linear. Shader exposure compression only affects display.
		colors[i] = Color(color.r,color.g,color.b,flux(b,receiver)/EARTH_FLUX)
		if i == 0: dominant = dirs[i]
	for name_value: String in ["Surface", "Clouds", "Rings"]:
		if root.has_node(name_value) and not receiver.is_luminous() and receiver.kind != "black_hole":
			var material: ShaderMaterial = root.get_node(name_value).material_override
			material.set_shader_parameter("stellar_count",mini(sources.size(),4))
			material.set_shader_parameter("stellar_directions",dirs)
			material.set_shader_parameter("stellar_flux",colors)
			material.set_shader_parameter("sunlight_direction",dominant)
	if root.has_node("Atmosphere"):
		root.get_node("Atmosphere").material_override.set_shader_parameter("sunlight_direction",dominant)
