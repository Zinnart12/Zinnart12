extends SceneTree

var passed: int = 0
var failed: int = 0

func _initialize() -> void:
	SaveSystem.save_path = "user://cosmic-scene-test.csu"
	call_deferred("run")

func check(value: bool, text: String) -> void:
	if value:
		passed += 1
		print("PASS scene ",passed,": ",text)
	else:
		failed += 1
		push_error("FAIL scene: " + text)

func run() -> void:
	var menu: Control = load("res://scenes/MainMenu.tscn").instantiate()
	root.add_child(menu)
	current_scene = menu
	await process_frame
	var play: Button = menu.find_child("PlayButton",true,false)
	check(play != null,"F5 main menu has a real start control")
	var settings: GraphicsMenu
	for child: Node in menu.get_children():
		if child is GraphicsMenu: settings = child
	settings.quality_picker.item_selected.emit(0)
	play.pressed.emit()
	await process_frame
	await process_frame
	var universe: UniverseManager = current_scene
	check(universe != null and universe.engine.bodies.size()==10 and universe.visuals.size()==10,"main menu enters native Solar System scene with ten visual and physical bodies")
	check(universe.quality==0 and not universe.world.environment.glow_enabled,"main-menu quality selection is applied to the actual sandbox renderer")
	universe.ui.play_button.pressed.emit()
	await process_frame
	var paused: Dictionary = universe.engine.snapshot()
	await process_frame
	check(not universe.clock.running and universe.engine.snapshot()==paused,"Pause freezes real physical state")
	var earth: CelestialBody = universe.engine.find_body("earth")
	var before: PackedFloat64Array = earth.position.duplicate()
	universe.engine.advance(86400.0,4096,0)
	check(earth.position != before and universe.engine.time>paused.time,"simulation advances positions using the N-body engine")
	universe.select_body("sun")
	var mass: float = universe.engine.find_body("sun").mass
	universe.ui.mass_slider.value = log(mass*2.0)/log(10.0)
	check(absf(universe.engine.find_body("sun").mass/mass-2.0)<0.01,"native mass slider actually edits the gravitational mass")
	universe.camera_rig.focus("earth")
	universe.camera_rig.tick(0.0)
	check(universe.origin_si==universe.engine.find_body("earth").position and universe.to_scene(universe.origin_si)==Vector3.ZERO,"floating origin tracks the focused body before float32 conversion")
	universe.true_scale = true
	universe.calculate_display_radii()
	check(absf(universe.display_radii.earth/(earth.radius*universe.METRES_TO_SCENE)-1.0)<1e-12,"true-size rendering does not edit physical positions or radii")
	universe.ui.save_game()
	var saved: Dictionary = universe.engine.snapshot()
	universe.edit_mass("1e30")
	universe.ui.load_game()
	check(universe.engine.snapshot()==saved and not universe.clock.running,"native Save and Load controls restore all SI data and simulation time")
	universe.load_preset("earthmoon")
	check(universe.engine.bodies.size()==2,"Earth–Moon preset loads proper physical bodies")
	# Route genuine Godot key events, rather than calling camera callbacks directly.
	universe.ui.mass_edit.release_focus()
	var event: InputEventKey = InputEventKey.new()
	event.physical_keycode = KEY_W
	event.keycode = KEY_W
	event.pressed = true
	var before_eye: PackedFloat64Array = universe.camera_rig.eye_si.duplicate()
	var before_camera_state: Dictionary = universe.engine.snapshot()
	Input.parse_input_event(event)
	await process_frame
	await process_frame
	check(universe.camera_rig.mode=="fly" and universe.camera_rig.eye_si!=before_eye,"W key travels through the Godot input system and flies the native camera")
	check(universe.engine.snapshot()==before_camera_state,"fly camera input does not mutate physical body coordinates")
	event = InputEventKey.new()
	event.physical_keycode = KEY_W
	event.keycode = KEY_W
	event.pressed = false
	Input.parse_input_event(event)
	universe.load_preset("binary")
	check(universe.engine.bodies.size()==2 and universe.engine.bodies[0].kind=="star","binary-star preset is a second true N-body system")
	universe.set_quality(0)
	check(not universe.world.environment.glow_enabled and absf(root.scaling_3d_scale-0.7)<0.000001,"graphics quality changes the active renderer settings")
	universe.set_quality(2)
	check(universe.world.environment.glow_enabled and root.msaa_3d==Viewport.MSAA_4X,"Ultra enables antialiasing and restrained glow")
	var valid: Dictionary = universe.engine.snapshot()
	var invalid: Dictionary = valid.duplicate(true)
	invalid.bodies[0].mass = -1.0
	universe.restore(invalid)
	check(universe.engine.snapshot()==valid,"invalid save cannot partially overwrite the running universe")
	print("\nScene checks: ",passed," passed; ",failed," failed.")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SaveSystem.save_path))
	quit(1 if failed>0 else 0)
