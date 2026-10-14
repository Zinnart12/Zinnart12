class_name CelestialBody
extends RefCounted

# Godot's standard Vector3 is float32. PackedFloat64Array keeps CPU physics
# at double precision even with the official single-precision engine binary.
var id: String = ""
var body_name: String = ""
var kind: String = "planet"
var surface: String = "rocky"
var mass: float = 5.9722e24
var radius: float = 6371000.0
var position: PackedFloat64Array = PackedFloat64Array([0.0, 0.0, 0.0])
var velocity: PackedFloat64Array = PackedFloat64Array([0.0, 0.0, 0.0])
var temperature: float = 288.0
var rotation_period: float = 86164.0
var axial_tilt: float = 23.44
var atmosphere: float = 1.0
var composition: String = "Silicate rock, iron, water"
var color: Color = Color("80b7e6")
var seed: float = 1.0

func density() -> float:
	return mass / (4.0 * PI * radius * radius * radius / 3.0)

func surface_gravity() -> float:
	return GravitySolver.G * mass / (radius * radius)

func escape_velocity() -> float:
	return sqrt(2.0 * GravitySolver.G * mass / radius)

func to_dict() -> Dictionary:
	return {"id": id, "name": body_name, "kind": kind, "surface": surface,
		"mass": mass, "radius": radius, "position": Array(position), "velocity": Array(velocity),
		"temperature": temperature, "rotation_period": rotation_period,
		"axial_tilt": axial_tilt, "atmosphere": atmosphere, "composition": composition,
		"color": color.to_html(), "seed": seed}

static func from_dict(data: Dictionary) -> CelestialBody:
	var b: CelestialBody = CelestialBody.new()
	b.id = str(data.get("id", ""))
	b.body_name = str(data.get("name", "Body"))
	b.kind = str(data.get("kind", "planet"))
	b.surface = str(data.get("surface", "rocky"))
	b.mass = float(data.get("mass", 5.9722e24))
	b.radius = float(data.get("radius", 6371000.0))
	b.position = PackedFloat64Array(data.get("position", [0.0, 0.0, 0.0]))
	b.velocity = PackedFloat64Array(data.get("velocity", [0.0, 0.0, 0.0]))
	b.temperature = float(data.get("temperature", 288.0))
	b.rotation_period = float(data.get("rotation_period", 86164.0))
	b.axial_tilt = float(data.get("axial_tilt", 23.44))
	b.atmosphere = float(data.get("atmosphere", 0.0))
	b.composition = str(data.get("composition", "Rock"))
	b.color = Color(str(data.get("color", "80b7e6")))
	b.seed = float(data.get("seed", 1.0))
	return b

func detached_copy() -> CelestialBody:
	return from_dict(to_dict())
