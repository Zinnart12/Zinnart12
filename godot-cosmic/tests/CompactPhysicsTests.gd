extends SceneTree
var passed: int=0
var failed: int=0
func check(value: bool,message: String) -> void:
	if value:passed+=1;print("PASS compact ",passed,": ",message)
	else:failed+=1;push_error("FAIL compact: "+message)
func momentum(bodies: Array[CelestialBody]) -> PackedFloat64Array:
	var result: PackedFloat64Array=PackedFloat64Array([0.0,0.0,0.0])
	for body: CelestialBody in bodies:
		for k: int in range(3):result[k]+=body.mass*body.velocity[k]
	return result
func _initialize() -> void:
	SaveSystem.save_path="user://cosmic-compact-test.csu"
	var system: BlackHoleSystem=BlackHoleSystem.new()
	var hole: CelestialBody=CompactPresets.hole()
	check(absf(hole.radius/29533.3938206688-1.0)<1e-10,"10 solar masses give Rs = 29.5334 km")
	check(BlackHoleSystem.photon_sphere(hole.mass)==1.5*hole.radius and absf(BlackHoleSystem.shadow_radius(hole.mass)/hole.radius-sqrt(27.0)/2.0)<1e-12,"horizon, photon sphere and apparent shadow are distinct")
	var body: CelestialBody=SolarSystemPreset.body("test","Probe","asteroid",1e20,1.0,200.0,"888888")
	body.strength=1e35;body.velocity[0]=200.0;body.position[0]=hole.radius*0.8
	var bodies: Array[CelestialBody]=[hole,body]
	var original: PackedFloat64Array=momentum(bodies)
	var mass: float=hole.mass+body.mass
	var events: Array[Dictionary]=system.resolve(bodies)
	check(bodies.size()==1 and events[0].type=="capture" and hole.mass==mass and hole.accreted_mass==body.mass,"inside-horizon body is removed and accreted mass is recorded")
	check(absf(momentum(bodies)[0]/original[0]-1.0)<1e-12 and hole.radius==BlackHoleSystem.schwarzschild_radius(mass),"capture conserves modeled linear momentum and updates the horizon")
	hole=CompactPresets.hole();body=body.detached_copy();body.position[0]=hole.radius+0.5;body.fragmentation_depth=1
	bodies=[hole,body]
	check(system.resolve(bodies).is_empty() and CollisionSystem.new().resolve(bodies).is_empty() and bodies.size()==2,"solid contact outside the horizon cannot swallow a body prematurely")
	var previous: Dictionary={hole.id:Array(hole.position),body.id:[-2.0*hole.radius,0.0,0.0]}
	body.position[0]=2.0*hole.radius
	check(system.resolve(bodies,previous).size()==1 and bodies.size()==1,"swept horizon check catches a fast crossing between endpoints")
	hole=CompactPresets.hole();body=CompactPresets.object(0)
	var state: Dictionary=BlackHoleSystem.tidal_state(hole,body,1e12)
	body.position=PackedFloat64Array([state.roche*0.8,0.0,0.0]);body.velocity=PackedFloat64Array([120.0,30.0,200.0])
	bodies=[hole,body];original=momentum(bodies);mass=hole.mass+body.mass
	events=system.resolve(bodies)
	var after: PackedFloat64Array=momentum(bodies)
	var total: float=0.0
	for fragment: CelestialBody in bodies:total+=fragment.mass
	check(events.size()==1 and events[0].type=="tidal_disruption" and bodies.size()==9,"overstressed Earth produces eight force-bearing debris bodies")
	check(absf(total/mass-1.0)<1e-12 and absf(after[2]/original[2]-1.0)<1e-12,"tidal fragmentation conserves mass and linear momentum")
	var engine: SimulationEngine=SimulationEngine.new();engine.load_bodies(bodies)
	var old_position: PackedFloat64Array=engine.bodies[1].position.duplicate()
	engine.advance(0.1,256,0)
	check(engine.bodies[1].position!=old_position,"debris continues to integrate under N-body forces")
	hole=CompactPresets.hole(1e9*GravitySolver.MSUN);body=CompactPresets.object(0)
	state=BlackHoleSystem.tidal_state(hole,body,hole.radius)
	check(state.ratio<1.0 and state.roche<hole.radius,"sufficiently massive holes have an Earth disruption limit inside their horizon")
	body.position=PackedFloat64Array([hole.radius*0.99,0.0,0.0]);bodies=[hole,body];events=system.resolve(bodies)
	check(bodies.size()==1 and events[0].type=="capture","massive-hole case swallows the planet without mandatory exterior fragmentation")
	var sun: CelestialBody=SolarSystemPreset.create()[0]
	body=CompactPresets.object(0);body.position=PackedFloat64Array([GravitySolver.AU,0.0,0.0]);sun.position.fill(0.0)
	var flux: float=StellarLighting.flux(sun,body);body.position[0]*=2.0
	check(absf(flux/1361.0-1.0)<0.01 and absf(StellarLighting.flux(sun,body)/flux-0.25)<1e-12,"stellar luminosity and SI flux follow Stefan–Boltzmann and inverse square")
	for preset: Array in CompactPresets.ENTRIES:
		engine.load_bodies(CompactPresets.create(preset[1]),preset[0])
		check(SaveSystem.validate(engine.snapshot()).is_empty(),"valid physical data for "+preset[0])
	engine.load_bodies([CompactPresets.hole(),NeutronStarSystem.create(true)])
	engine.bodies[1].position[0]=engine.bodies[0].radius*0.8
	engine.advance(0.1,256,0)
	check(engine.bodies.size()==1 and engine.events[0].type=="capture","neutron-star encounter is captured by the actual engine")
	var saved: Dictionary=engine.snapshot()
	check(SaveSystem.save_snapshot(saved).is_empty() and SaveSystem.load_snapshot().data==saved,"compact-object save round-trip preserves new properties")
	var bad: Dictionary=saved.duplicate(true);bad.bodies[0].radius*=2.0
	check(not SaveSystem.validate(bad).is_empty(),"inconsistent saved black-hole radius is rejected")
	check_precession()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SaveSystem.save_path))
	print("\nCompact physics: ",passed," passed; ",failed," failed.")
	quit(1 if failed else 0)

func check_precession() -> void:
	var h: CelestialBody=CompactPresets.hole()
	var probe: CelestialBody=SolarSystemPreset.body("orbit-probe","Orbit Probe","asteroid",1e10,1.0,200.0,"888888")
	probe.strength=1e35
	var a: float=h.radius*100.0
	var e: float=0.2
	SolarSystemPreset.orbit(probe,a,e,0.0,0.0,h.mass)
	var engine: SimulationEngine=SimulationEngine.new();engine.load_bodies([h,probe])
	var period: float=TAU*sqrt(a*a*a/(GravitySolver.G*h.mass))
	var last_r: float=BlackHoleSystem.distance_between(engine.bodies[0],engine.bodies[1])
	var falling: bool=false
	var angles: Array[float]=[]
	for i: int in range(8000):
		engine.advance(period/1500.0,32,0)
		var r: float=BlackHoleSystem.distance_between(engine.bodies[0],engine.bodies[1])
		if falling and r>last_r:
			var b: CelestialBody=engine.bodies[1]
			angles.append(atan2(b.position[2]-engine.bodies[0].position[2],b.position[0]-engine.bodies[0].position[0]))
			falling=false
			if angles.size()==3:break
		if r<last_r:falling=true
		last_r=r
	var expected: float=3.0*PI*h.radius/(a*(1.0-e*e))
	var measured: float=angle_difference(angles[0],angles[2])*0.5 if angles.size()==3 else 0.0
	print("Precession measured ",measured," rad/orbit; weak-field prediction ",expected)
	check(angles.size()==3 and absf(measured/expected-1.0)<0.15,"weak-field 1PN correction gives prograde orbital precession near the analytical prediction")
