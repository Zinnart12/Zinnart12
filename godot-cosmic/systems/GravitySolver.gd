class_name GravitySolver
extends RefCounted

const G: float = 6.67430e-11
const AU: float = 149597870700.0
const DAY: float = 86400.0
const YEAR: float = 31557600.0
const MSUN: float = 1.98847e30
const MEARTH: float = 5.9722e24
const MAX_STEP: float = 3600.0

var scratch_a: PackedFloat64Array = PackedFloat64Array()
var scratch_b: PackedFloat64Array = PackedFloat64Array()

func accelerations(bodies: Array[CelestialBody], output: PackedFloat64Array) -> void:
	output.resize(bodies.size() * 3)
	output.fill(0.0)
	for i: int in range(bodies.size()):
		for j: int in range(i + 1, bodies.size()):
			var a: CelestialBody = bodies[i]
			var b: CelestialBody = bodies[j]
			var dx: float = b.position[0] - a.position[0]
			var dy: float = b.position[1] - a.position[1]
			var dz: float = b.position[2] - a.position[2]
			var d2: float = dx * dx + dy * dy + dz * dz
			# Contacts merge before the next step; this floor avoids division by zero
			# while a swept-contact candidate is evaluated at a step endpoint.
			d2 = maxf(d2, pow((a.radius + b.radius) * 0.1, 2.0))
			var factor: float = G / (d2 * sqrt(d2))
			for k: int in range(3):
				var delta: float = b.position[k] - a.position[k]
				output[i * 3 + k] += delta * factor * b.mass
				output[j * 3 + k] -= delta * factor * a.mass

func step(bodies: Array[CelestialBody], dt: float) -> void:
	accelerations(bodies, scratch_a)
	for i: int in range(bodies.size()):
		for k: int in range(3):
			bodies[i].position[k] += bodies[i].velocity[k] * dt + 0.5 * scratch_a[i * 3 + k] * dt * dt
	accelerations(bodies, scratch_b)
	for i: int in range(bodies.size()):
		for k: int in range(3):
			bodies[i].velocity[k] += 0.5 * (scratch_a[i * 3 + k] + scratch_b[i * 3 + k]) * dt

func stable_step(bodies: Array[CelestialBody]) -> float:
	var result: float = MAX_STEP
	for i: int in range(bodies.size()):
		for j: int in range(i + 1, bodies.size()):
			var d2: float = 0.0
			var v2: float = 0.0
			for k: int in range(3):
				d2 += pow(bodies[j].position[k] - bodies[i].position[k], 2.0)
				v2 += pow(bodies[j].velocity[k] - bodies[i].velocity[k], 2.0)
			if d2 <= 0.0:
				continue
			var distance: float = sqrt(d2)
			result = minf(result, 0.01 * sqrt(distance * d2 / (G * (bodies[i].mass + bodies[j].mass))))
			if v2 > 0.0:
				result = minf(result, 0.15 * distance / sqrt(v2))
	return result

func diagnostics(bodies: Array[CelestialBody]) -> Dictionary:
	var kinetic: float = 0.0
	var potential: float = 0.0
	var momentum: PackedFloat64Array = PackedFloat64Array([0.0, 0.0, 0.0])
	for i: int in range(bodies.size()):
		var b: CelestialBody = bodies[i]
		for k: int in range(3):
			kinetic += 0.5 * b.mass * b.velocity[k] * b.velocity[k]
			momentum[k] += b.mass * b.velocity[k]
		for j: int in range(i + 1, bodies.size()):
			var d2: float = 0.0
			for k: int in range(3):
				d2 += pow(bodies[j].position[k] - b.position[k], 2.0)
			potential -= G * b.mass * bodies[j].mass / maxf(sqrt(d2), (b.radius + bodies[j].radius) * 0.1)
	return {"kinetic": kinetic, "potential": potential, "energy": kinetic + potential, "momentum": Array(momentum)}
