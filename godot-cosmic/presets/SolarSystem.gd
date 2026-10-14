class_name SolarSystemPreset
extends RefCounted

static func body(id_value: String, name_value: String, kind_value: String, mass_value: float, radius_value: float, temp: float, color_value: String, surface_value: String = "rocky") -> CelestialBody:
	return CelestialBody.from_dict({"id": id_value, "name": name_value, "kind": kind_value,
		"mass": mass_value, "radius": radius_value, "temperature": temp, "color": color_value,
		"surface": surface_value, "seed": float(id_value.hash() % 10000), "atmosphere": 0.0})

static func orbit(b: CelestialBody, semimajor: float, eccentricity: float, phase: float, inclination: float, parent_mass: float) -> void:
	var p: float = semimajor * (1.0 - eccentricity * eccentricity)
	var distance: float = p / (1.0 + eccentricity * cos(phase))
	var speed: float = sqrt(GravitySolver.G * (parent_mass + b.mass) / p)
	b.position = PackedFloat64Array([distance * cos(phase), distance * sin(phase) * sin(inclination), distance * sin(phase) * cos(inclination)])
	b.velocity = PackedFloat64Array([-speed * sin(phase), speed * (eccentricity + cos(phase)) * sin(inclination), speed * (eccentricity + cos(phase)) * cos(inclination)])

static func barycentric(bodies: Array[CelestialBody]) -> void:
	var total: float = 0.0
	var p: PackedFloat64Array = PackedFloat64Array([0.0, 0.0, 0.0])
	var v: PackedFloat64Array = p.duplicate()
	for b: CelestialBody in bodies:
		total += b.mass
	for b: CelestialBody in bodies:
		for k: int in range(3):
			p[k] += b.position[k] * b.mass / total
			v[k] += b.velocity[k] * b.mass / total
	for b: CelestialBody in bodies:
		for k: int in range(3):
			b.position[k] -= p[k]
			b.velocity[k] -= v[k]

static func create() -> Array[CelestialBody]:
	var sun: CelestialBody = body("sun", "Sun", "star", GravitySolver.MSUN, 695700000.0, 5772.0, "fff2c5", "lava")
	sun.rotation_period = 25.38 * GravitySolver.DAY
	sun.axial_tilt = 7.25
	sun.composition = "Hydrogen 73%, helium 25%, heavier elements 2%"
	var bodies: Array[CelestialBody] = [sun]
	var parameters: Array = [
		["mercury", "Mercury", 3.3011e23, 2439700.0, 0.3871, 0.2056, 7.0, 0.4, 440.0, 58.646, 0.034, "b5aaa0", "rocky", 0.0],
		["venus", "Venus", 4.8675e24, 6051800.0, 0.7233, 0.0068, 3.39, 2.2, 737.0, -243.025, 2.64, "d7bc80", "rocky", 92.0],
		["earth", "Earth", 5.9722e24, 6371000.0, 1.0, 0.0167, 0.0, 0.0, 288.0, 0.99726968, 23.44, "80b7e6", "earth", 1.0],
		["mars", "Mars", 6.4171e23, 3389500.0, 1.5237, 0.0934, 1.85, 3.0, 210.0, 1.025957, 25.19, "c98769", "rocky", 0.006],
		["jupiter", "Jupiter", 1.89813e27, 69911000.0, 5.2028, 0.0489, 1.30, 0.9, 165.0, 0.4135417, 3.13, "d9b28b", "gas", 8.0],
		["saturn", "Saturn", 5.6834e26, 58232000.0, 9.5388, 0.0565, 2.49, 2.7, 134.0, 0.444, 26.73, "e3cb9f", "gas", 8.0],
		["uranus", "Uranus", 8.681e25, 25362000.0, 19.1914, 0.0463, 0.77, 4.1, 76.0, 0.718, 97.77, "a4dce3", "ice", 6.0],
		["neptune", "Neptune", 1.02413e26, 24622000.0, 30.0611, 0.0095, 1.77, 5.2, 72.0, 0.671, 28.32, "5987e2", "ice", 6.0]]
	for row: Array in parameters:
		var b: CelestialBody = body(row[0], row[1], "planet", row[2], row[3], row[8], row[11], row[12])
		b.rotation_period = row[9] * GravitySolver.DAY
		b.axial_tilt = row[10]
		b.atmosphere = row[13]
		b.composition = "Hydrogen, helium, volatile compounds" if b.surface in ["gas", "ice"] else "Iron core, silicate mantle and crust"
		if b.id == "earth":
			b.composition = "Iron, silicates, liquid water; nitrogen/oxygen atmosphere"
		orbit(b, row[4] * GravitySolver.AU, row[5], row[7], deg_to_rad(row[6]), sun.mass)
		bodies.append(b)
	var earth: CelestialBody = bodies[3]
	var moon: CelestialBody = body("moon", "Moon", "moon", 7.342e22, 1737400.0, 220.0, "b8b6b1")
	moon.rotation_period = 27.321661 * GravitySolver.DAY
	moon.axial_tilt = 6.68
	moon.composition = "Basalt and silicate regolith, small iron core"
	orbit(moon, 384400000.0, 0.0549, 1.1, deg_to_rad(5.145), earth.mass)
	var fraction: float = moon.mass / (earth.mass + moon.mass)
	for k: int in range(3):
		var offset: float = moon.position[k]
		var speed: float = moon.velocity[k]
		earth.position[k] -= offset * fraction
		earth.velocity[k] -= speed * fraction
		moon.position[k] = earth.position[k] + offset
		moon.velocity[k] = earth.velocity[k] + speed
	bodies.append(moon)
	barycentric(bodies)
	return bodies

static func earth_moon() -> Array[CelestialBody]:
	var all: Array[CelestialBody] = create()
	var earth: CelestialBody = all[3]
	var moon: CelestialBody = all[9]
	for k: int in range(3):
		moon.position[k] -= earth.position[k]
		moon.velocity[k] -= earth.velocity[k]
	earth.position.fill(0.0)
	earth.velocity.fill(0.0)
	var pair: Array[CelestialBody] = [earth, moon]
	barycentric(pair)
	return pair

static func binary() -> Array[CelestialBody]:
	var a: CelestialBody = body("star-a", "Star A", "star", GravitySolver.MSUN * 0.8, 580000000.0, 5200.0, "ffdcaa", "lava")
	var b: CelestialBody = body("star-b", "Star B", "star", GravitySolver.MSUN * 0.6, 440000000.0, 4400.0, "ffc18b", "lava")
	orbit(b, 0.2 * GravitySolver.AU, 0.15, 0.0, 0.0, a.mass)
	var pair: Array[CelestialBody] = [a, b]
	barycentric(pair)
	return pair
