extends SceneTree

var passed: int = 0
var failures: int = 0

func check(condition: bool, description: String) -> void:
	if condition:
		passed += 1
		print("PASS ",passed,": ",description)
	else:
		failures += 1
		push_error("FAIL: " + description)

func pair(eccentricity: float = 0.0, velocity_factor: float = 1.0) -> SimulationEngine:
	var distance: float = GravitySolver.AU * (1.0-eccentricity)
	var speed: float = sqrt(GravitySolver.G * (GravitySolver.MSUN+GravitySolver.MEARTH)/GravitySolver.AU*(1.0+eccentricity)/(1.0-eccentricity))*velocity_factor
	var fraction: float = GravitySolver.MEARTH/(GravitySolver.MSUN+GravitySolver.MEARTH)
	var sun: CelestialBody = SolarSystemPreset.body("sun","Sun","star",GravitySolver.MSUN,695700000.0,5772.0,"fff2c5")
	var earth: CelestialBody = SolarSystemPreset.body("earth","Earth","planet",GravitySolver.MEARTH,6371000.0,288.0,"80b7e6")
	sun.position[0] = -distance*fraction
	earth.position[0] = distance*(1.0-fraction)
	sun.velocity[2] = -speed*fraction
	earth.velocity[2] = speed*(1.0-fraction)
	var engine: SimulationEngine = SimulationEngine.new()
	engine.load_bodies([sun,earth],"Test pair")
	return engine

func integrate(engine: SimulationEngine, duration: float) -> void:
	var end: float = engine.time+duration
	var batches: int = 0
	while engine.time < end-0.00001:
		var done: float = engine.advance(end-engine.time,4096,0)
		if done <= 0.0 or batches > 2000:
			check(false,"integration makes forward progress")
			return
		batches += 1

func separation(engine: SimulationEngine) -> float:
	var d2: float = 0.0
	for k: int in range(3): d2 += pow(engine.bodies[1].position[k]-engine.bodies[0].position[k],2.0)
	return sqrt(d2)

func _initialize() -> void:
	SaveSystem.save_path = "user://cosmic-physics-test.csu"
	var earth: SimulationEngine = pair()
	integrate(earth,GravitySolver.YEAR)
	var r: float = separation(earth)
	var angle: float = atan2(earth.bodies[1].position[2]-earth.bodies[0].position[2],earth.bodies[1].position[0]-earth.bodies[0].position[0])
	check(absf(r/GravitySolver.AU-1.0)<1e-6 and absf(angle)<0.0003,"Earth returns after a year from Newtonian gravity")
	check(absf(float(earth.diagnostics.drift))<1e-8,"circular two-body relative energy error below 1e-8")
	var moon: SimulationEngine = SimulationEngine.new()
	moon.load_bodies(SolarSystemPreset.earth_moon())
	var initial_moon: Array = Array(moon.bodies[1].position)
	var period: float = TAU*sqrt(pow(384400000.0,3.0)/(GravitySolver.G*(moon.bodies[0].mass+moon.bodies[1].mass)))
	integrate(moon,period)
	var lunar_error: float = 0.0
	for k: int in range(3): lunar_error += pow(moon.bodies[1].position[k]-initial_moon[k],2.0)
	check(sqrt(lunar_error)/384400000.0<0.002 and moon.bodies.size()==2,"Moon completes its eccentric orbit without artificial animation")
	var normal: SimulationEngine = pair()
	var heavier: SimulationEngine = pair()
	heavier.bodies[0].mass *= 2.0
	heavier.reset_baseline()
	integrate(normal,GravitySolver.DAY*30)
	integrate(heavier,GravitySolver.DAY*30)
	check(absf(separation(normal)-separation(heavier))>GravitySolver.AU*0.05,"increasing solar mass changes the physical orbit")
	var ellipse: SimulationEngine = pair(0.6)
	var peak_error: float = 0.0
	for i: int in range(20):
		integrate(ellipse,GravitySolver.YEAR/4.0)
		peak_error = maxf(peak_error,absf(ellipse.diagnostics.drift))
	check(peak_error<8e-5 and ellipse.bodies.size()==2,"five-year eccentric orbit has bounded energy error")
	var escape: SimulationEngine = pair(0.0,sqrt(2.0)*1.25)
	integrate(escape,GravitySolver.YEAR)
	check(separation(escape)>7.0*GravitySolver.AU and escape.diagnostics.energy>0.0,"super-escape velocity leaves the field rather than following a fixed orbit")
	var a: CelestialBody = SolarSystemPreset.body("a","A","asteroid",2e10,1000.0,200.0,"888888")
	var b: CelestialBody = SolarSystemPreset.body("b","B","asteroid",3e10,1000.0,200.0,"888888")
	a.position[0] = -10000.0; b.position[0] = 10000.0
	a.velocity = PackedFloat64Array([10000.0,200.0,0.0]); b.velocity = PackedFloat64Array([-10000.0,200.0,0.0])
	var impact: SimulationEngine = SimulationEngine.new()
	impact.load_bodies([a,b])
	var initial_momentum: Array = impact.diagnostics.momentum.duplicate()
	integrate(impact,5.0)
	var conserved: bool = true
	for k: int in range(3): conserved = conserved and absf(impact.diagnostics.momentum[k]-initial_momentum[k])<maxf(1.0,absf(initial_momentum[k])*1e-12)
	check(impact.bodies.size()==1 and impact.bodies[0].mass==5e10 and conserved,"swept contact catches fast impacts and conserves mass and linear momentum")
	check(absf(pow(impact.bodies[0].radius,3.0)/2e9-1.0)<1e-12 and impact.bodies[0].temperature>200.0,"contact conserves volume and records dissipated heat")
	var limited: SimulationEngine = pair()
	var actual: float = limited.advance(GravitySolver.YEAR,8,0)
	check(limited.limited and limited.steps==8 and limited.time==actual and actual<GravitySolver.YEAR,"work limits report only actual completed physics time")
	var tiny: CelestialBody = SolarSystemPreset.body("tiny","Tiny","asteroid",1e5,1.0,200.0,"888888")
	tiny.position = PackedFloat64Array([GravitySolver.AU+1.0,0.0,0.0])
	check(tiny.position[0]-GravitySolver.AU==1.0,"CPU position preserves metre differences at AU scale with float64")
	var solar: SimulationEngine = SimulationEngine.new()
	solar.load_bodies(SolarSystemPreset.create())
	integrate(solar,GravitySolver.DAY*30)
	check(solar.bodies.size()==10 and absf(solar.diagnostics.drift)<1e-5,"all ten Solar System bodies interact stably")
	var snapshot: Dictionary = solar.snapshot()
	var encoded: String = JSON.stringify(snapshot,"",false,true)
	var decoded: Variant = JSON.parse_string(encoded)
	check(SaveSystem.validate(decoded).is_empty() and decoded.bodies[3].position==snapshot.bodies[3].position,"save JSON preserves double positions and validates the complete state")
	var malformed: Dictionary = snapshot.duplicate(true)
	malformed.bodies[0].mass = -1.0
	check(not SaveSystem.validate(malformed).is_empty(),"negative mass data is rejected before loading")
	malformed = snapshot.duplicate(true)
	malformed.bodies[1].id = malformed.bodies[0].id
	check(not SaveSystem.validate(malformed).is_empty(),"duplicate IDs cannot corrupt the simulation")
	var requested: Array[float] = []
	for fps: int in [1,30,60,120]:
		var clock: TimeController = TimeController.new()
		var sum: float = 0.0
		for frame: int in range(fps):
			clock.accumulate(1.0/float(fps))
			sum += clock.take_request()
		requested.append(sum)
	check(requested.all(func(value: float) -> bool: return absf(value-GravitySolver.DAY)<0.000001),"requested simulation time is independent of render FPS")
	var storage_error: String = SaveSystem.save_snapshot(snapshot)
	var saved: Dictionary = SaveSystem.load_snapshot()
	check(storage_error.is_empty() and saved.has("data") and saved.data.bodies==snapshot.bodies,"native save/load writes a validated complete snapshot")
	print("\nGodot physics checks: ",passed," passed; ",failures," failed. Peak eccentric energy drift: ",peak_error)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SaveSystem.save_path))
	quit(1 if failures>0 else 0)
