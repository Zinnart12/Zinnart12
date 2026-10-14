class_name CollisionSystem
extends RefCounted

# Phase 1 baseline: completely inelastic contact, not a fragmentation solver.
# Every force-bearing remnant stays in the same N-body array.
func resolve(bodies: Array[CelestialBody], previous: Array = []) -> Array[Dictionary]:
	var events: Array[Dictionary] = []
	var searching: bool = true
	while searching:
		searching = false
		for i: int in range(bodies.size()):
			if searching:
				break
			for j: int in range(i + 1, bodies.size()):
				var a: CelestialBody = bodies[i]
				var b: CelestialBody = bodies[j]
				# Horizon capture belongs to BlackHoleSystem, not solid-sphere contact.
				if a.kind == "black_hole" or b.kind == "black_hole": continue
				var contact: float = a.radius + b.radius
				var d2: float = 0.0
				for k: int in range(3):
					d2 += pow(b.position[k] - a.position[k], 2.0)
				var collides: bool = d2 <= contact * contact
				if not collides and previous.size() == bodies.size():
					var start: PackedFloat64Array = PackedFloat64Array([0.0, 0.0, 0.0])
					var change: PackedFloat64Array = start.duplicate()
					var dot_value: float = 0.0
					var change2: float = 0.0
					for k: int in range(3):
						start[k] = previous[j][k] - previous[i][k]
						change[k] = b.position[k] - a.position[k] - start[k]
						dot_value += start[k] * change[k]
						change2 += change[k] * change[k]
					var fraction: float = clampf(-dot_value / change2, 0.0, 1.0) if change2 > 0.0 else 0.0
					var closest2: float = 0.0
					for k: int in range(3):
						closest2 += pow(start[k] + fraction * change[k], 2.0)
					collides = closest2 <= contact * contact
				if not collides:
					continue
				var total: float = a.mass + b.mass
				var survivor: CelestialBody = a.detached_copy() if a.mass >= b.mass else b.detached_copy()
				var relative_speed2: float = 0.0
				for k: int in range(3):
					survivor.position[k] = (a.mass * a.position[k] + b.mass * b.position[k]) / total
					survivor.velocity[k] = (a.mass * a.velocity[k] + b.mass * b.velocity[k]) / total
					relative_speed2 += pow(a.velocity[k] - b.velocity[k], 2.0)
				var energy: float = 0.5 * a.mass * b.mass / total * relative_speed2
				survivor.temperature = minf(1e9, (a.temperature * a.mass + b.temperature * b.mass) / total + energy / (1000.0 * total))
				survivor.mass = total
				survivor.radius = pow(pow(a.radius, 3.0) + pow(b.radius, 3.0), 1.0 / 3.0)
				events.append({"names": [a.body_name, b.body_name], "energy": energy, "position": Array(survivor.position)})
				bodies[i] = survivor
				bodies.remove_at(j)
				previous.clear()
				searching = true
				break
	return events
