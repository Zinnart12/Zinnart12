class_name SimulationEngine
extends RefCounted

var bodies: Array[CelestialBody] = []
var simulation_name: String = "Solar System"
var time: float = 0.0
var steps: int = 0
var baseline_energy: float = 0.0
var diagnostics: Dictionary = {}
var gravity: GravitySolver = GravitySolver.new()
var collision: CollisionSystem = CollisionSystem.new()
var black_holes: BlackHoleSystem = BlackHoleSystem.new()
var limited: bool = false
var min_step: float = 0.0
var events: Array[Dictionary] = []

func load_bodies(new_bodies: Array[CelestialBody], new_name: String = "Solar System", new_time: float = 0.0) -> void:
	bodies.clear()
	for b: CelestialBody in new_bodies:
		bodies.append(b.detached_copy())
	simulation_name = new_name
	time = new_time
	steps = 0
	events.clear()
	reset_baseline()

func reset_baseline() -> void:
	diagnostics = gravity.diagnostics(bodies)
	baseline_energy = float(diagnostics.energy)
	diagnostics["drift"] = 0.0
	limited = false
	min_step = 0.0

func advance(seconds: float, max_steps: int = 256, budget_usec: int = 6000) -> float:
	if not is_finite(seconds) or seconds <= 0.0:
		return 0.0
	var start_ticks: int = Time.get_ticks_usec()
	var completed: float = 0.0
	var count: int = 0
	min_step = INF
	var contacts: Array[Dictionary] = black_holes.resolve(bodies)
	contacts.append_array(collision.resolve(bodies))
	if not contacts.is_empty():
		events.append_array(contacts)
		reset_baseline()
	while completed < seconds and count < max_steps:
		if count > 0 and budget_usec > 0 and Time.get_ticks_usec() - start_ticks >= budget_usec:
			break
		var dt: float = minf(seconds - completed, gravity.stable_step(bodies))
		if not is_finite(dt) or dt <= 0.0 or time + dt == time:
			break
		var previous: Array = []
		var previous_ids: Dictionary = {}
		for body: CelestialBody in bodies:
			previous.append(body.position.duplicate())
			previous_ids[body.id] = body.position.duplicate()
		black_holes.relativistic_kick(bodies,dt*0.5)
		gravity.step(bodies, dt)
		black_holes.relativistic_kick(bodies,dt*0.5)
		completed += dt
		time += dt
		steps += 1
		count += 1
		min_step = minf(min_step, dt)
		contacts = black_holes.resolve(bodies,previous_ids)
		contacts.append_array(collision.resolve(bodies,previous if contacts.is_empty() else []))
		if not contacts.is_empty():
			events.append_array(contacts)
			reset_baseline()
		if events.size() > 64:
			events = events.slice(events.size() - 64)
	limited = completed < seconds - maxf(1e-8, seconds * 1e-12)
	if not is_finite(min_step):
		min_step = 0.0
	diagnostics = gravity.diagnostics(bodies)
	diagnostics["drift"] = (float(diagnostics.energy) - baseline_energy) / absf(baseline_energy) if baseline_energy != 0.0 else 0.0
	diagnostics["substeps"] = count
	return completed

func find_body(id_value: String) -> CelestialBody:
	for b: CelestialBody in bodies:
		if b.id == id_value:
			return b
	return null

func snapshot() -> Dictionary:
	var data: Array = []
	for body: CelestialBody in bodies:
		data.append(body.to_dict())
	return {"schema_version": 1, "name": simulation_name, "time": time, "steps": steps, "bodies": data}
