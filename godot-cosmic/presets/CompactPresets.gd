class_name CompactPresets
extends RefCounted

const ENTRIES: Array = [["Black Hole Observatory","observatory"],["Earth vs Black Hole","earthhole"],["Solar System vs Black Hole","solarhole"],["Neutron Star vs Black Hole","neutronhole"],["Binary Black Hole","binaryhole"],["Black Hole Accretion Disk","disk"]]
const OBJECTS: Array[String] = ["Earth","Black Hole","Sagittarius A*","Stellar Black Hole","Supermassive Black Hole","Neutron Star","Pulsar","White Dwarf","Asteroid"]

static func hole(mass: float=10.0*GravitySolver.MSUN, name_value: String="Stellar Black Hole") -> CelestialBody:
	var b: CelestialBody = SolarSystemPreset.body("black-hole",name_value,"black_hole",mass,BlackHoleSystem.schwarzschild_radius(mass),16000.0,"e89036","lava")
	b.rotation_period = 0.0
	b.axial_tilt = 0.0
	b.composition = "Schwarzschild exterior / capture sink; spin stored, Kerr geometry not modeled"
	return b

static func object(index: int) -> CelestialBody:
	match index:
		0: return SolarSystemPreset.create()[3]
		1,3: return hole()
		2: return hole(4.3e6*GravitySolver.MSUN,"Sagittarius A*")
		4: return hole(1e8*GravitySolver.MSUN,"Supermassive Black Hole")
		5: return NeutronStarSystem.create()
		6: return NeutronStarSystem.create(true)
		7:
			var b: CelestialBody = SolarSystemPreset.body("white-dwarf","White Dwarf","white_dwarf",0.6*GravitySolver.MSUN,7000000.0,18000.0,"d9e7ff","lava")
			b.composition = "Degenerate carbon/oxygen; Newtonian bulk dynamics"
			return b
	return SolarSystemPreset.body("asteroid","Asteroid","asteroid",2e15,6000.0,200.0,"a59689")

static func create(preset: String) -> Array[CelestialBody]:
	if preset == "solarhole":
		var all: Array[CelestialBody] = SolarSystemPreset.create()
		var h: CelestialBody = hole(10000.0*GravitySolver.MSUN)
		h.position[0] = GravitySolver.AU*2.0
		all.append(h)
		SolarSystemPreset.barycentric(all)
		return all
	var h: CelestialBody = hole(4.3e6*GravitySolver.MSUN,"Sagittarius A*") if preset in ["observatory","disk"] else hole()
	var bodies: Array[CelestialBody] = [h]
	if preset == "earthhole":
		var earth: CelestialBody = object(0)
		var limit: float = BlackHoleSystem.tidal_state(h,earth,1e12).roche
		earth.position = PackedFloat64Array([limit*1.25,0.0,0.0])
		earth.velocity = PackedFloat64Array([-3000.0,0.0,sqrt(GravitySolver.G*h.mass/earth.position[0])*0.25])
		bodies.append(earth)
	elif preset == "neutronhole":
		var n: CelestialBody = NeutronStarSystem.create(true)
		n.position[0] = h.radius*12.0
		n.velocity[0] = -0.035*BlackHoleSystem.C
		n.velocity[2] = 0.01*BlackHoleSystem.C
		bodies.append(n)
	elif preset == "binaryhole":
		var second: CelestialBody = hole(8.0*GravitySolver.MSUN,"Black Hole B")
		second.id = "hole-b"
		h.body_name = "Black Hole A"
		SolarSystemPreset.orbit(second,h.radius*180.0,0.12,0.0,0.0,h.mass)
		bodies.append(second)
	elif preset == "observatory":
		var star: CelestialBody = SolarSystemPreset.body("s2","S2-like Star","star",8.0*GravitySolver.MSUN,3e9,18000.0,"bad7ff","lava")
		SolarSystemPreset.orbit(star,h.radius*150.0,0.55,0.6,0.25,h.mass)
		bodies.append(star)
	SolarSystemPreset.barycentric(bodies)
	return bodies
