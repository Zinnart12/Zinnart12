class_name BlackHoleSystem
extends RefCounted

const C: float = 299792458.0
const MAX_BODIES: int = 128
var fragment_serial: int = 0

static func schwarzschild_radius(mass: float) -> float:
	return 2.0 * GravitySolver.G * mass / (C*C)

static func photon_sphere(mass: float) -> float:
	return 1.5 * schwarzschild_radius(mass)

static func shadow_radius(mass: float) -> float:
	return sqrt(27.0)/2.0 * schwarzschild_radius(mass)

static func tidal_state(hole: CelestialBody, body: CelestialBody, distance: float) -> Dictionary:
	var differential: float = 2.0 * GravitySolver.G * hole.mass * body.radius / pow(maxf(distance,hole.radius),3.0)
	var stress: float = body.density() * differential * body.radius
	var self_binding: float = body.density() * GravitySolver.G * body.mass / body.radius
	var resistance: float = self_binding + body.strength
	var limit: float = pow(2.0 * GravitySolver.G * hole.mass * body.density() * pow(body.radius,2.0) / resistance,1.0/3.0)
	return {"acceleration":differential,"stress":stress,"resistance":resistance,"ratio":stress/resistance,"roche":limit}

static func distance_between(a: CelestialBody, b: CelestialBody) -> float:
	var r2: float = 0.0
	for k: int in range(3): r2 += pow(a.position[k]-b.position[k],2.0)
	return sqrt(r2)

# Weak-field 1PN test-body correction, paired recoil conserves linear momentum.
# Disabled inside 10 Rs and at v >= 0.2 c: this is not a strong-field GR integrator.
func relativistic_kick(bodies: Array[CelestialBody], dt: float) -> void:
	for hole: CelestialBody in bodies:
		if hole.kind != "black_hole": continue
		for body: CelestialBody in bodies:
			if body == hole: continue
			var r: PackedFloat64Array = PackedFloat64Array([0.0,0.0,0.0])
			var v: PackedFloat64Array = r.duplicate()
			var r2: float = 0.0
			var v2: float = 0.0
			var rv: float = 0.0
			for k: int in range(3):
				r[k] = body.position[k]-hole.position[k]
				v[k] = body.velocity[k]-hole.velocity[k]
				r2 += r[k]*r[k]; v2 += v[k]*v[k]; rv += r[k]*v[k]
			var distance: float = sqrt(r2)
			if distance <= hole.radius*10.0 or v2 >= pow(0.2*C,2.0) or body.mass > hole.mass*0.01: continue
			var mu: float = GravitySolver.G*hole.mass
			var factor: float = mu/(C*C*r2*distance)
			for k: int in range(3):
				var dv: float = factor*((4.0*mu/distance-v2)*r[k]+4.0*rv*v[k])*dt
				body.velocity[k] += dv
				hole.velocity[k] -= dv*body.mass/hole.mass

func resolve(bodies: Array[CelestialBody], previous: Dictionary = {}) -> Array[Dictionary]:
	var events: Array[Dictionary] = []
	# Capture takes priority over fragmentation. A large hole can swallow a planet intact.
	for hole: CelestialBody in bodies.duplicate():
		if hole.kind != "black_hole" or not bodies.has(hole): continue
		hole.radius = schwarzschild_radius(hole.mass)
		for body: CelestialBody in bodies.duplicate():
			if body == hole or not bodies.has(body): continue
			var contact: float = hole.radius + (body.radius if body.kind == "black_hole" else 0.0)
			var captured: bool = distance_between(hole,body) <= contact
			if not captured and previous.has(hole.id) and previous.has(body.id):
				var start: PackedFloat64Array = PackedFloat64Array([0.0,0.0,0.0])
				var change: PackedFloat64Array = start.duplicate()
				var dot_value: float = 0.0
				var change2: float = 0.0
				for k: int in range(3):
					start[k] = previous[body.id][k]-previous[hole.id][k]
					change[k] = body.position[k]-hole.position[k]-start[k]
					dot_value += start[k]*change[k]; change2 += change[k]*change[k]
				var fraction: float = clampf(-dot_value/change2,0.0,1.0) if change2>0.0 else 0.0
				var closest2: float = 0.0
				for k: int in range(3): closest2 += pow(start[k]+fraction*change[k],2.0)
				captured = closest2 <= contact*contact
			if not captured: continue
			var total: float = hole.mass+body.mass
			for k: int in range(3):
				hole.position[k] += (body.position[k]-hole.position[k])*body.mass/total
				hole.velocity[k] += (body.velocity[k]-hole.velocity[k])*body.mass/total
			hole.mass = total
			hole.accreted_mass += body.mass
			hole.radius = schwarzschild_radius(total)
			events.append({"type":"capture","names":[hole.body_name,body.body_name],"mass":body.mass})
			bodies.erase(body)
	for hole: CelestialBody in bodies.duplicate():
		if hole.kind != "black_hole": continue
		for body: CelestialBody in bodies.duplicate():
			if not bodies.has(body) or body.kind == "black_hole" or body.fragmentation_depth > 0: continue
			var distance: float = distance_between(hole,body)
			var state: Dictionary = tidal_state(hole,body,distance)
			# Keep fragments within the same numeric/save resolution as other bodies.
			if state.ratio <= 1.0 or bodies.size()+7 > MAX_BODIES or body.mass<8e-6 or body.radius<0.002: continue
			var fragments: Array[CelestialBody] = fragment(body,hole,state)
			bodies.erase(body)
			bodies.append_array(fragments)
			events.append({"type":"tidal_disruption","names":[hole.body_name,body.body_name],"stress":state.stress,"resistance":state.resistance,"fragments":8})
	return events

func fragment(body: CelestialBody, hole: CelestialBody, state: Dictionary) -> Array[CelestialBody]:
	var results: Array[CelestialBody] = []
	var distance: float=distance_between(body,hole)
	var radial: PackedFloat64Array=PackedFloat64Array([0.0,0.0,0.0])
	for k: int in range(3):radial[k]=(body.position[k]-hole.position[k])/maxf(distance,1e-30)
	var expansion: float = minf(body.escape_velocity()*0.4, sqrt(maxf(0.0,state.acceleration*body.radius))*0.15)
	for x: float in [-1.0,1.0]:
		for y: float in [-1.0,1.0]:
			for z: float in [-1.0,1.0]:
				fragment_serial += 1
				var b: CelestialBody = body.detached_copy()
				b.id = body.id+"-fragment-"+str(fragment_serial)
				while results.any(func(other: CelestialBody) -> bool: return other.id == b.id):
					fragment_serial += 1; b.id = body.id+"-fragment-"+str(fragment_serial)
				b.body_name = body.body_name+" debris "+str(results.size()+1)
				b.kind = "debris"; b.mass = body.mass/8.0; b.radius = body.radius*0.5
				b.fragmentation_depth = body.fragmentation_depth+1; b.atmosphere = 0.0; b.surface = "rocky"
				var offset: PackedFloat64Array=PackedFloat64Array([x*body.radius*0.68,y*body.radius*0.68,z*body.radius*0.68])
				var projected: float=0.0
				for k: int in range(3):projected+=offset[k]*radial[k]
				for k: int in range(3):
					b.position[k] += offset[k]
					b.velocity[k] += radial[k]*projected/body.radius*expansion
				results.append(b)
	return results
