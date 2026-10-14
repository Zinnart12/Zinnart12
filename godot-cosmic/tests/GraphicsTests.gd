extends SceneTree

var passed: int = 0
var failed: int = 0
var output_dir: String

func _initialize() -> void:
	output_dir = OS.get_environment("COSMIC_CAPTURE_DIR")
	if output_dir.is_empty(): output_dir = "user://captures"
	DirAccess.make_dir_recursive_absolute(output_dir)
	call_deferred("run")

func check(condition: bool, message: String) -> void:
	if condition:
		passed += 1
		print("PASS Vulkan ",passed,": ",message)
	else:
		failed += 1
		push_error("FAIL Vulkan: "+message)

func frame() -> void:
	await process_frame
	await RenderingServer.frame_post_draw

func run() -> void:
	check(RenderingServer.get_current_rendering_method()=="forward_plus","actual Forward+ rendering method")
	var menu: Control = load("res://scenes/MainMenu.tscn").instantiate()
	root.add_child(menu)
	current_scene = menu
	await frame()
	var image: Image = root.get_texture().get_image()
	check(image.get_width()>0 and image.get_height()>0,"native framebuffer capture is available")
	image.save_png(output_dir+"/godot-menu.png")
	menu.find_child("PlayButton",true,false).pressed.emit()
	await frame()
	await frame()
	var universe: UniverseManager = current_scene
	universe.clock.set_running(false)
	universe.set_quality(2)
	universe.camera_rig.focus("earth")
	await frame()
	var earth: Image = root.get_texture().get_image()
	earth.save_png(output_dir+"/godot-earth.png")
	universe.body_root.visible = false
	await frame()
	var sky: Image = root.get_texture().get_image()
	var different: int = 0
	for y: int in range(int(earth.get_height()*0.35),int(earth.get_height()*0.65),3):
		for x: int in range(int(earth.get_width()*0.4),int(earth.get_width()*0.6),3):
			var a: Color = earth.get_pixel(x,y)
			var b: Color = sky.get_pixel(x,y)
			if absf(a.r-b.r)+absf(a.g-b.g)+absf(a.b-b.b)>0.02: different += 1
	check(different>100,"Earth procedural surface actually renders pixels, independently of UI or background")
	universe.body_root.visible = true
	universe.camera_rig.focus("sun")
	await frame()
	image = root.get_texture().get_image()
	image.save_png(output_dir+"/godot-sun.png")
	var brightest: float = 0.0
	var darkest: float = 1.0
	for y: int in range(int(image.get_height()*0.42),int(image.get_height()*0.58),3):
		for x: int in range(int(image.get_width()*0.44),int(image.get_width()*0.56),3):
			var color: Color = image.get_pixel(x,y)
			var value: float = (color.r+color.g+color.b)/3.0
			brightest = maxf(brightest,value)
			darkest = minf(darkest,value)
	check(brightest>0.4 and brightest-darkest>0.03,"stellar granulation remains visible after tone mapping")
	var before: Dictionary = universe.engine.snapshot()
	universe.camera_rig.overview()
	await frame()
	check(universe.engine.snapshot()==before,"camera framing does not alter double-precision physical state")
	universe.load_preset("earthmoon")
	universe.clock.set_running(false)
	await frame()
	image = root.get_texture().get_image()
	image.save_png(output_dir+"/godot-earth-moon.png")
	check(universe.engine.bodies.size()==2 and universe.visuals.size()==2,"Earth–Moon preset also compiles and renders its native materials")
	universe.set_quality(0)
	await frame()
	check(absf(root.scaling_3d_scale-0.7)<1e-6 and not universe.world.environment.glow_enabled,"graphics menu settings act on the Vulkan viewport")
	print("\nVulkan graphics checks: ",passed," passed; ",failed," failed. GPU: ",RenderingServer.get_video_adapter_name())
	quit(1 if failed>0 else 0)
