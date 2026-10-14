class_name NeutronStarSystem
extends RefCounted

static func create(pulsar: bool = false) -> CelestialBody:
	var b: CelestialBody = SolarSystemPreset.body("pulsar" if pulsar else "neutron","Pulsar" if pulsar else "Neutron Star","pulsar" if pulsar else "neutron_star",GravitySolver.MSUN*1.4,12000.0,600000.0,"a8d9ff","lava")
	b.rotation_period = 0.033 if pulsar else 0.2
	b.axial_tilt = 20.0
	b.magnetic_axis = 35.0
	b.strength = 1e28
	b.composition = "Degenerate neutron-rich matter; representative 1.4 solar masses / 12 km"
	return b
