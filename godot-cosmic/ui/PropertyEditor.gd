class_name PropertyEditor
extends VBoxContainer

var universe: UniverseManager
var inputs: Dictionary={}
const ENTRIES: Array = [["radius","Radius / m"],["temperature","Temperature / K"],["strength","Tensile strength / Pa"],["rotation_period","Rotation period / s"],["spin","Spin metadata (Kerr off)"],["magnetic_axis","Magnetic axis / deg"],["position","Position / m · x, y, z"],["velocity","Velocity / m/s · x, y, z"]]

func _ready() -> void:
	add_child(ThemeFactory.label("EDIT PHYSICAL STATE",14,Color("819fac")))
	for entry: Array in ENTRIES:
		var key: String=entry[0]
		add_child(ThemeFactory.label(entry[1],13))
		var edit: LineEdit=LineEdit.new()
		edit.name="Property_"+key
		edit.text_submitted.connect(func(value: String) -> void:submit(key,value))
		inputs[key]=edit;add_child(edit)

func refresh(body: CelestialBody) -> void:
	for key: String in inputs:
		var edit: LineEdit=inputs[key]
		edit.editable=not (key=="radius" and body.kind=="black_hole")
		edit.tooltip_text="Derived from mass: Rs = 2GM/c²" if not edit.editable else "Enter applies a validated SI value"
		if edit.has_focus():continue
		if key in ["position","velocity"]:
			var vector: PackedFloat64Array=body.get(key)
			edit.text=String.num_scientific(vector[0])+", "+String.num_scientific(vector[1])+", "+String.num_scientific(vector[2])
		else:edit.text=String.num_scientific(float(body.get(key)))

func submit(key: String,text_value: String) -> void:
	var body: CelestialBody=universe.engine.find_body(universe.selected_id)
	if body==null or (key=="radius" and body.kind=="black_hole"):return
	var candidate: CelestialBody=body.detached_copy()
	if key in ["position","velocity"]:
		var parts: PackedStringArray=text_value.split(",")
		if parts.size()!=3:universe.ui.notify("Use three SI components: x, y, z");return
		var vector: PackedFloat64Array=PackedFloat64Array()
		for part: String in parts:
			if not part.strip_edges().is_valid_float():universe.ui.notify("Invalid vector component.");return
			vector.append(part.to_float())
		candidate.set(key,vector)
	else:
		if not text_value.is_valid_float():universe.ui.notify("Enter a finite numeric SI value.");return
		candidate.set(key,text_value.to_float())
	var snapshot: Dictionary=universe.engine.snapshot()
	for i: int in range(snapshot.bodies.size()):
		if snapshot.bodies[i].id==body.id:snapshot.bodies[i]=candidate.to_dict()
	var error: String=SaveSystem.validate(snapshot)
	if not error.is_empty():universe.ui.notify(error);return
	body.set(key,candidate.get(key))
	universe.engine.reset_baseline()
	if key=="position":universe.trail_history[body.id].clear()
	universe.calculate_display_radii();universe.ui.refresh()
	universe.ui.notify("Updated "+key+" in the real simulation.")
