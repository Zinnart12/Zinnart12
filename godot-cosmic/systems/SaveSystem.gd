class_name SaveSystem
extends RefCounted

const SAVE_PATH: String = "user://cosmic-sandbox.csu"
const MAX_BYTES: int = 2000000
# Tests redirect storage so they never overwrite a player's saved simulation.
static var save_path: String = SAVE_PATH

static func validate(data: Variant) -> String:
	if not data is Dictionary or data.get("schema_version") != 1:
		return "Unsupported save format."
	if not data.get("bodies") is Array or data.bodies.size() > 128:
		return "Maximum 128 bodies."
	if not _numeric(data.get("time"), 0.0, 1e15):
		return "Invalid simulation time."
	if not data.get("steps") is float and not data.get("steps") is int:
		return "Invalid step counter."
	if not _numeric(data.steps, 0.0, 9e15) or float(data.steps) != floorf(float(data.steps)):
		return "Invalid step counter."
	if not data.get("name") is String or data.name.length() > 100:
		return "Invalid simulation name."
	var ids: Dictionary = {}
	for item: Variant in data.bodies:
		if not item is Dictionary:
			return "Invalid body."
		if not item.get("id") is String or item.id.is_empty() or ids.has(item.id):
			return "Missing or duplicated body ID."
		ids[item.id] = true
		if not item.get("name") is String or item.name.is_empty() or item.name.length() > 100:
			return "Invalid object name."
		if not item.get("kind") in ["star", "planet", "moon", "asteroid", "comet", "black_hole", "neutron_star", "pulsar", "white_dwarf", "debris"] or not item.get("surface") in ["earth", "rocky", "gas", "ice", "lava", "ocean"]:
			return "Unknown object type."
		for field: String in ["mass", "radius", "temperature", "rotation_period", "axial_tilt", "atmosphere", "seed"]:
			if not _numeric(item.get(field), -1e41, 1e41):
				return "Invalid numeric property: " + field
		if not _numeric(item.mass, 1e-6, 1e41) or not _numeric(item.radius, 1e-3, 1e18) or not _numeric(item.temperature, 0.0, 1e9):
			return "Invalid mass, radius or temperature."
		if not _numeric(item.atmosphere, 0.0, 1000.0):
			return "Invalid atmosphere."
		for field: String in ["position", "velocity"]:
			if not item.get(field) is Array or item[field].size() != 3:
				return "Vector must have three components."
			for component: Variant in item[field]:
				if not _numeric(component, -1e22 if field == "position" else -1e9, 1e22 if field == "position" else 1e9):
					return "Invalid " + field
		if not item.get("composition") is String or item.composition.length() > 500:
			return "Invalid composition."
		if not item.get("color") is String or not Color.html_is_valid(item.color):
			return "Invalid color."
		for entry: Array in [["strength",0.0,1e35],["spin",-0.998,0.998],["accreted_mass",0.0,1e41],["fragmentation_depth",0.0,10.0],["magnetic_axis",0.0,180.0]]:
			if item.has(entry[0]) and not _numeric(item[entry[0]],entry[1],entry[2]): return "Invalid " + entry[0]
		if item.has("fragmentation_depth") and float(item.fragmentation_depth) != floorf(float(item.fragmentation_depth)): return "Invalid fragment generation."
		if item.has("disk_enabled") and not item.disk_enabled is bool: return "Invalid disk flag."
		if item.kind == "black_hole" and absf(item.radius/BlackHoleSystem.schwarzschild_radius(item.mass)-1.0) > 1e-8: return "Black hole radius must equal Schwarzschild radius."
	return ""

static func _numeric(value: Variant, minimum: float, maximum: float) -> bool:
	return (value is float or value is int) and is_finite(float(value)) and float(value) >= minimum and float(value) <= maximum

static func save_snapshot(data: Dictionary) -> String:
	var error: String = validate(data)
	if not error.is_empty():
		return error
	var bytes: PackedByteArray = var_to_bytes(data)
	if bytes.size() > MAX_BYTES:
		return "Save exceeds 2 MB."
	var file: FileAccess = FileAccess.open(save_path + ".tmp", FileAccess.WRITE)
	if file == null:
		return "Cannot write save: " + error_string(FileAccess.get_open_error())
	file.store_var(data, false)
	file.flush()
	var write_error: Error = file.get_error()
	file.close()
	if write_error != OK:
		return "Cannot finish save: " + error_string(write_error)
	var result: Error = DirAccess.rename_absolute(ProjectSettings.globalize_path(save_path + ".tmp"), ProjectSettings.globalize_path(save_path))
	return "" if result == OK else "Cannot replace save: " + error_string(result)

static func load_snapshot() -> Dictionary:
	if not FileAccess.file_exists(save_path):
		return {"error": "No saved simulation yet."}
	var file: FileAccess = FileAccess.open(save_path, FileAccess.READ)
	if file == null or file.get_length() > MAX_BYTES:
		return {"error": "Cannot read save or file exceeds 2 MB."}
	var parsed: Variant = file.get_var(false)
	file.close()
	var error: String = validate(parsed)
	return {"error": error} if not error.is_empty() else {"data": parsed}
