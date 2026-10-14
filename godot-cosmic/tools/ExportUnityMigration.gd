extends SceneTree

# Run with Godot 4.6.3. Never edits the original preset or player save.
# Optional: -- --save=/absolute/input.csu --out=/absolute/output.json
func _initialize() -> void:
	var input: String = ""
	var output: String = ""
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--save="): input = argument.trim_prefix("--save=")
		if argument.begins_with("--out="): output = argument.trim_prefix("--out=")
	if not input.is_empty():
		if output.is_empty():
			push_error("Specify --out for save conversion.")
			quit(1)
			return
		SaveSystem.save_path = input
		var loaded: Dictionary = SaveSystem.load_snapshot()
		if loaded.has("error"):
			push_error(str(loaded.error))
			quit(1)
			return
		_write(output, _with_bits(loaded.data))
		return
	var entries: Array = []
	var golden: Array = []
	var base: Array = [["solar", "Solar System", SolarSystemPreset.create()],
		["earthmoon", "Earth & Moon", SolarSystemPreset.earth_moon()],
		["binary", "Binary Stars", SolarSystemPreset.binary()]]
	for item: Array in base:
		_append(entries, golden, item[0], item[1], item[2], true)
	for item: Array in CompactPresets.ENTRIES:
		_append(entries, golden, item[1], item[0], CompactPresets.create(item[1]), false)
	var directory: String = ProjectSettings.globalize_path("res://../unity-cosmic/Assets/StreamingAssets")
	DirAccess.make_dir_recursive_absolute(directory)
	_write(directory + "/GodotPresets.json", {"migration_schema":1,"entries":entries}, false)
	_write(directory + "/GodotGoldenSteps.json", {"cases":golden})

func _append(entries: Array, golden: Array, id: String, title: String, bodies: Array[CelestialBody], phase1: bool) -> void:
	var simulation: SimulationEngine = SimulationEngine.new()
	simulation.load_bodies(bodies, title)
	var initial: Dictionary = _with_bits(simulation.snapshot())
	var error: String = SaveSystem.validate(initial)
	assert(error.is_empty(), error)
	entries.append({"id":id,"title":title,"phase1":phase1,
		"seconds_per_second":GravitySolver.DAY if phase1 else 0.01,"snapshot":initial})
	# Oracle exercises the original Newton solver directly, independently of Unity.
	var solver: GravitySolver = GravitySolver.new()
	var step: float = minf(120.0,solver.stable_step(bodies))
	solver.step(bodies,step)
	var after: Array = []
	for body: CelestialBody in bodies: after.append(body.to_dict())
	var bits: Array = []
	for record: Dictionary in initial.bodies:
		var fields: Dictionary = {}
		for field: String in ["mass","radius","temperature","rotation_period","axial_tilt","atmosphere","seed","strength","spin","accreted_mass","magnetic_axis"]:
			fields[field] = _double_bits(float(record[field]))
		for field: String in ["position","velocity"]:
			var components: Array = []
			for value: float in record[field]: components.append(_double_bits(value))
			fields[field] = components
		bits.append({"id":record.id,"fields":fields})
	golden.append({"id":id,"dt":step,"bodies":after,"initial_bits":bits})

func _double_bits(value: float) -> String:
	var bytes: PackedByteArray = PackedByteArray()
	bytes.resize(8)
	bytes.encode_double(0,value)
	return bytes.hex_encode()

func _with_bits(snapshot: Dictionary) -> Dictionary:
	var result: Dictionary = snapshot.duplicate(true)
	result["time_bits"] = _double_bits(float(result.time))
	result["steps_bits"] = _double_bits(float(result.steps))
	for record: Dictionary in result.bodies:
		for field: String in ["mass","radius","temperature","rotation_period","axial_tilt","atmosphere","seed","strength","spin","accreted_mass","magnetic_axis"]:
			if record.has(field): record[field + "_bits"] = _double_bits(float(record[field]))
		for field: String in ["position","velocity"]:
			var components: Array = []
			for value: float in record[field]: components.append(_double_bits(value))
			record[field + "_bits"] = components
	return result

func _write(path: String, data: Dictionary, done: bool = true) -> void:
	var file: FileAccess = FileAccess.open(path,FileAccess.WRITE)
	if file == null:
		push_error("Cannot write migration file: " + path)
		quit(1)
		return
	# full_precision=true retains the IEEE-754 values through text conversion.
	file.store_string(JSON.stringify(data,"\t",true,true) + "\n")
	file.close()
	print("Migration JSON: " + path)
	if done: quit(0)
