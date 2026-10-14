class_name SandboxUI
extends CanvasLayer

var universe: UniverseManager
var root: Control
var body_list: ItemList
var title: Label
var selected_name: Label
var fields: Label
var mass_edit: LineEdit
var mass_slider: HSlider
var play_button: Button
var time_label: Label
var monitor: Label
var toast: Label
var graphics: GraphicsMenu
var update_elapsed: float = 0.0
var toast_time: float = 0.0
var updating: bool = false
var list_ids: Array[String] = []

func _ready() -> void:
	universe = get_parent()
	layer = 2
	root = Control.new()
	root.name = "HUD"
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.theme = ThemeFactory.make()
	add_child(root)
	var header: HBoxContainer = HBoxContainer.new()
	header.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	header.offset_left = 30
	header.offset_right = -30
	header.offset_top = 24
	header.add_theme_constant_override("separation", 22)
	root.add_child(header)
	header.add_child(ThemeFactory.label("COSMIC SANDBOX", 27, Color("b5f0e1")))
	title = ThemeFactory.label("Solar System / N-BODY", 18, Color("91adbc"))
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)
	header.add_child(ThemeFactory.button("Graphics", func() -> void: graphics.popup_centered()))
	header.add_child(ThemeFactory.button("Main Menu", func() -> void: get_tree().change_scene_to_file("res://scenes/MainMenu.tscn")))
	graphics = GraphicsMenu.new()
	graphics.quality_selected = func(value: int) -> void: universe.set_quality(value)
	root.add_child(graphics)
	var left: PanelContainer = PanelContainer.new()
	left.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	left.position = Vector2(24,110)
	left.custom_minimum_size = Vector2(300,720)
	root.add_child(left)
	var library: VBoxContainer = VBoxContainer.new()
	library.add_theme_constant_override("separation", 14)
	left.add_child(library)
	library.add_child(ThemeFactory.label("ORBITAL LABORATORY", 14, Color("8ce8d3")))
	library.add_child(ThemeFactory.label("Explore the universe.", 24))
	for entry: Array in [["Solar System", "solar"], ["Earth & Moon", "earthmoon"], ["Binary Stars", "binary"]]:
		var preset: String = entry[1]
		library.add_child(ThemeFactory.button(entry[0], func() -> void: universe.load_preset(preset)))
	library.add_child(HSeparator.new())
	library.add_child(ThemeFactory.label("CELESTIAL BODIES", 14, Color("819fac")))
	body_list = ItemList.new()
	body_list.name = "BodyList"
	body_list.focus_mode = Control.FOCUS_NONE
	body_list.custom_minimum_size = Vector2(255,350)
	body_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body_list.item_selected.connect(func(index: int) -> void: universe.select_body(list_ids[index]))
	body_list.item_activated.connect(func(index: int) -> void: universe.camera_rig.focus(list_ids[index]))
	library.add_child(body_list)
	library.add_child(ThemeFactory.label("All bodies attract each other.\nTrails record integrated positions.", 14, Color("6e8b9d")))
	var right: PanelContainer = PanelContainer.new()
	right.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	right.offset_left = -350
	right.offset_right = -24
	right.offset_top = 110
	root.add_child(right)
	var inspector: VBoxContainer = VBoxContainer.new()
	inspector.add_theme_constant_override("separation", 13)
	right.add_child(inspector)
	inspector.add_child(ThemeFactory.label("SELECTED OBJECT / SI", 14, Color("819fac")))
	selected_name = ThemeFactory.label("Earth", 31)
	inspector.add_child(selected_name)
	inspector.add_child(ThemeFactory.button("Focus [F]", func() -> void: universe.camera_rig.focus(universe.selected_id)))
	inspector.add_child(HSeparator.new())
	inspector.add_child(ThemeFactory.label("MASS  /  kg", 14, Color("819fac")))
	mass_edit = LineEdit.new()
	mass_edit.name = "MassEdit"
	mass_edit.text_submitted.connect(universe.edit_mass)
	inspector.add_child(mass_edit)
	mass_slider = HSlider.new()
	mass_slider.name = "MassSlider"
	mass_slider.min_value = 10.0
	mass_slider.max_value = 32.0
	mass_slider.step = 0.002
	mass_slider.value_changed.connect(func(value: float) -> void:
		if not updating: universe.edit_mass(str(pow(10.0,value))))
	inspector.add_child(mass_slider)
	fields = ThemeFactory.label("", 17)
	fields.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	fields.custom_minimum_size.x = 285
	inspector.add_child(fields)
	monitor = ThemeFactory.label("", 15, Color("88b8bc"))
	inspector.add_child(HSeparator.new())
	inspector.add_child(monitor)
	var bottom: PanelContainer = PanelContainer.new()
	bottom.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	bottom.offset_left = 24
	bottom.offset_right = -24
	bottom.offset_top = -142
	bottom.offset_bottom = -24
	root.add_child(bottom)
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	bottom.add_child(row)
	play_button = ThemeFactory.button("Pause [Space]", toggle_pause)
	play_button.name = "PauseButton"
	row.add_child(play_button)
	row.add_child(ThemeFactory.button("Step", func() -> void:
		universe.clock.set_running(false)
		universe.engine.advance(minf(universe.clock.speed,GravitySolver.DAY))
		universe.sync_visuals()
		refresh()))
	time_label = ThemeFactory.label("0 days", 18)
	time_label.custom_minimum_size.x = 150
	row.add_child(time_label)
	var speed: OptionButton = OptionButton.new()
	speed.name = "TimeSpeed"
	var values: Array[float] = [1.0,60.0,3600.0,86400.0,604800.0,2592000.0,31557600.0]
	for text: String in ["Real time", "1 minute / s", "1 hour / s", "1 day / s", "1 week / s", "30 days / s", "1 year / s"]: speed.add_item(text)
	speed.select(3)
	speed.item_selected.connect(func(index: int) -> void: universe.clock.speed = values[index]; universe.clock.pending = 0.0)
	row.add_child(speed)
	row.add_child(ThemeFactory.button("Overview [R]", func() -> void: universe.camera_rig.overview()))
	row.add_child(ThemeFactory.button("Orbit / Fly [C]", func() -> void: universe.camera_rig.toggle_mode()))
	row.add_child(ThemeFactory.button("Reset", func() -> void: universe.load_preset("solar")))
	row.add_child(ThemeFactory.button("Save", save_game))
	row.add_child(ThemeFactory.button("Load", load_game))
	var layers: HBoxContainer = HBoxContainer.new()
	layers.position = Vector2(350,845)
	layers.add_theme_constant_override("separation", 18)
	root.add_child(layers)
	for entry: Array in [["Orbit trails", "show_trails", true], ["Labels", "show_labels", true], ["True size", "true_scale", false]]:
		var checkbox: CheckBox = CheckBox.new()
		checkbox.text = entry[0]
		checkbox.button_pressed = entry[2]
		var property: String = entry[1]
		checkbox.toggled.connect(func(enabled: bool) -> void:
			universe.set(property,enabled)
			if property == "true_scale":
				universe.calculate_display_radii()
				universe.camera_rig.focus(universe.selected_id)
				notify("True radii enabled." if enabled else "Display radii exaggerated; physical distances and contacts unchanged."))
		layers.add_child(checkbox)
	var help: Label = ThemeFactory.label("Drag: orbit/look   |   Wheel: zoom   |   WASD / Q E: fly   |   Shift: fast", 15, Color("648797"))
	help.position = Vector2(350,115)
	help.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(help)
	toast = ThemeFactory.label("", 18, Color("a8eddb"))
	toast.position = Vector2(350,890)
	root.add_child(toast)

func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode == KEY_SPACE:
			toggle_pause()
			get_viewport().set_input_as_handled()
		elif event.physical_keycode == KEY_F11:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED if DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN else DisplayServer.WINDOW_MODE_FULLSCREEN)

func toggle_pause() -> void:
	universe.clock.set_running(not universe.clock.running)
	refresh()

func rebuild_body_list() -> void:
	body_list.clear()
	list_ids.clear()
	for body: CelestialBody in universe.engine.bodies:
		list_ids.append(body.id)
		body_list.add_item(body.body_name)

func tick(delta: float) -> void:
	update_elapsed += delta
	if update_elapsed > 0.2:
		update_elapsed = 0.0
		refresh()
	if toast_time > 0.0:
		toast_time -= delta
		toast.visible = toast_time > 0.0

func refresh() -> void:
	if universe == null or title == null:
		return
	title.text = universe.engine.simulation_name + "  /  N-BODY"
	play_button.text = "Pause [Space]" if universe.clock.running else "Play [Space]"
	time_label.text = "%.2f days" % (universe.engine.time / GravitySolver.DAY)
	var body: CelestialBody = universe.engine.find_body(universe.selected_id)
	if body == null:
		selected_name.text = "Select an object"
		return
	selected_name.text = body.body_name
	for i: int in range(list_ids.size()):
		if list_ids[i] == body.id: body_list.select(i)
	updating = true
	if not mass_edit.has_focus(): mass_edit.text = String.num_scientific(body.mass)
	mass_slider.set_value_no_signal(log(body.mass)/log(10.0))
	updating = false
	var speed2: float = 0.0
	for k: int in range(3): speed2 += body.velocity[k]*body.velocity[k]
	fields.text = "Radius           %.1f km\nDensity         %.1f kg/m³\nTemperature    %.0f K\nGravity          %.3f m/s²\nVelocity         %.2f km/s\nEscape speed  %.2f km/s\nRotation         %.2f h\nAtmosphere    %.3f\n\nCOMPOSITION\n%s" % [body.radius/1000.0,body.density(),body.temperature,body.surface_gravity(),sqrt(speed2)/1000.0,body.escape_velocity()/1000.0,body.rotation_period/3600.0,body.atmosphere,body.composition]
	monitor.text = "PHYSICS MONITOR\n%d bodies · %d FPS\nΔE / |E₀|: %s\nStep: %.1f s · CPU float64\n%s" % [universe.engine.bodies.size(),Engine.get_frames_per_second(),String.num_scientific(float(universe.engine.diagnostics.get("drift",0.0))),universe.engine.min_step,"Speed limited by physics budget" if universe.engine.limited else "Velocity Verlet · adaptive steps"]

func notify(message: String) -> void:
	toast.text = message
	toast.visible = true
	toast_time = 7.0

func save_game() -> void:
	var result: String = SaveSystem.save_snapshot(universe.engine.snapshot())
	notify("Saved locally: " + SaveSystem.save_path if result.is_empty() else result)

func load_game() -> void:
	var result: Dictionary = SaveSystem.load_snapshot()
	if result.has("error"): notify(result.error)
	else:
		universe.restore(result.data)
		notify("Simulation restored.")
