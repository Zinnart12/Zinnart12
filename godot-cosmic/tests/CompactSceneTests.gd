extends SceneTree
var passed: int=0
var failed: int=0
func _initialize() -> void:
	SaveSystem.save_path="user://cosmic-compact-scene.csu"
	call_deferred("run")
func check(value: bool,message: String) -> void:
	if value:passed+=1;print("PASS compact scene ",passed,": ",message)
	else:failed+=1;push_error("FAIL compact scene: "+message)
func run() -> void:
	var u: UniverseManager=load("res://scenes/Sandbox.tscn").instantiate()
	root.add_child(u);current_scene=u;u.clock.set_running(false)
	await process_frame
	u.ui.add_picker.select(2)
	u.ui.root.find_child("AddObjectButton",true,false).pressed.emit()
	await process_frame
	var h: CelestialBody=u.engine.find_body(u.selected_id)
	check(h.kind=="black_hole" and u.visuals[h.id] is BlackHoleRenderer and u.engine.bodies.size()==11,"Add Object creates Sagittarius A* in the live solver and dedicated ray renderer")
	u.ui.search.text="Sagittarius"
	u.ui.search.text_changed.emit(u.ui.search.text)
	check(u.ui.list_ids.size()==1 and u.ui.list_ids[0]==h.id,"search filters actual object IDs")
	u.ui.disk_toggle.button_pressed=false
	check(not h.disk_enabled,"disk checkbox edits the selected black hole")
	var mass: float=h.mass
	u.edit_mass(str(mass*2.0))
	check(absf(h.radius/BlackHoleSystem.schwarzschild_radius(mass*2.0)-1.0)<1e-12,"mass editor updates black-hole horizon as well as gravity")
	var valid_mass: float=h.mass
	u.edit_mass("1")
	check(h.mass==valid_mass and SaveSystem.validate(u.engine.snapshot()).is_empty(),"mass editor rejects an unrepresentable tiny horizon without corrupting saveable state")
	u.ui.search.text=""
	u.ui.search.text_changed.emit("")
	u.ui.save_game();var saved: Dictionary=u.engine.snapshot()
	u.delete_selected();u.ui.load_game()
	check(u.engine.snapshot()==saved,"Add / Delete / Save / Load restores compact objects and mass exactly")
	u.load_preset("solar");u.clock.set_running(false);u.camera_rig.tick(0);u.update_rendering()
	check(u.markers.small.has("earth") and not u.markers.pick(u.markers.centers.earth).is_empty(),"distant Solar System objects have pickable screen-space markers")
	var physical: Dictionary=u.engine.snapshot()
	u.true_scale=true;u.calculate_display_radii();u.camera_rig.focus("earth");u.camera_rig.tick(0);u.update_rendering()
	check(u.engine.snapshot()==physical and u.camera_rig.distance>u.display_radii.earth and u.camera_rig.camera.near<u.display_radii.earth,"true-size focus preserves SI state and uses safe adaptive clipping")
	u.load_preset("binary");u.clock.set_running(false);u.camera_rig.tick(0);u.update_rendering()
	check(u.markers.centers.has("star-a") and u.markers.centers.has("star-b") and u.camera_rig.mode=="orbit","binary framing puts both real star meshes in the camera")
	for entry: Array in CompactPresets.ENTRIES:
		u.load_preset(entry[1]);u.clock.set_running(false);u.camera_rig.tick(0);u.update_rendering()
		check(u.visuals.size()==u.engine.bodies.size() and u.engine.bodies.any(func(b: CelestialBody) -> bool:return b.kind=="black_hole"),"scene and physics connected for "+entry[0])
	u.ui.graphics.select_preset(0)
	var low_steps: int=u.visuals[u.engine.bodies[0].id].material.get_shader_parameter("ray_steps")
	u.update_rendering();low_steps=u.visuals[u.engine.bodies[0].id].material.get_shader_parameter("ray_steps")
	u.ui.graphics.select_preset(2);u.update_rendering()
	check(low_steps==112 and u.visuals[u.engine.bodies[0].id].material.get_shader_parameter("ray_steps")==320 and root.msaa_3d==Viewport.MSAA_4X,"Performance / Ultra changes ray integration precision and antialiasing")
	u.ui.graphics.widgets.exposure.value=0.6
	check(absf(u.world.environment.tonemap_exposure-0.6)<1e-6,"exposure slider acts on the native WorldEnvironment")
	u.ui.graphics.widgets.taa.button_pressed=true
	check(root.use_taa,"TAA checkbox sets the supported Godot 4 Forward+ viewport property")
	u.load_preset("earthhole");u.clock.set_running(false);u.select_body("earth")
	var earth: CelestialBody=u.engine.find_body("earth")
	u.ui.property_editor.inputs.velocity.text_submitted.emit("100, 20, -300")
	check(earth.velocity==PackedFloat64Array([100.0,20.0,-300.0]),"velocity editor applies SI vector values to the real N-body body")
	u.ui.property_editor.inputs.strength.text_submitted.emit("1e25")
	check(earth.strength==1e25,"strength editor controls the physical tidal resistance")
	var before: Dictionary=u.engine.snapshot()
	u.ui.property_editor.inputs.radius.text_submitted.emit("-4")
	check(u.engine.snapshot()==before,"invalid physical-property edit is rejected atomically")
	var hole: CelestialBody=u.engine.bodies[0]
	for k: int in range(3):earth.position[k]=hole.position[k]
	earth.position[0]+=hole.radius*0.5
	for button: Button in u.ui.root.find_children("*","Button",true,false):
		if button.text=="Step":button.pressed.emit();break
	check(u.engine.bodies.size()==1 and u.ui.list_ids.size()==1 and u.visuals.size()==1,"paused Step capture updates physical bodies, meshes and the object list together")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SaveSystem.save_path))
	print("\nCompact scenes: ",passed," passed; ",failed," failed.")
	quit(1 if failed else 0)
