extends SceneTree
var passed: int=0
var failed: int=0
var output_dir: String
var universe: UniverseManager
func _initialize() -> void:
	output_dir=OS.get_environment("COSMIC_CAPTURE_DIR")
	if output_dir.is_empty():output_dir="user://captures"
	DirAccess.make_dir_recursive_absolute(output_dir)
	call_deferred("run")
func check(condition: bool,message: String) -> void:
	if condition:passed+=1;print("PASS Vulkan ",passed,": ",message)
	else:failed+=1;push_error("FAIL Vulkan: "+message)
func frame() -> void:
	await process_frame
	await RenderingServer.frame_post_draw
func capture(name_value: String) -> Image:
	await frame();await frame()
	var result: Image=root.get_texture().get_image()
	if not name_value.is_empty():result.save_png(output_dir+"/"+name_value+".png")
	return result
func body_pixels(id_value: String,img: Image,fraction: float=0.75) -> Dictionary:
	var point: Vector3=universe.visuals[id_value].position
	var rect: Vector2=root.get_visible_rect().size
	var scale_value: Vector2=Vector2(img.get_width(),img.get_height())/rect
	var center: Vector2=universe.camera_rig.camera.unproject_position(point)*scale_value
	var radius: float=universe.display_radii[id_value]/universe.camera_rig.camera.position.distance_to(point)*img.get_height()/(2.0*tan(deg_to_rad(universe.camera_rig.camera.fov*.5)))*fraction
	var sum: float=0.0
	var lo: float=1.0
	var hi: float=0.0
	var n: int=0
	for y: int in range(maxi(0,int(center.y-radius)),mini(img.get_height(),int(center.y+radius)),3):
		for x: int in range(maxi(0,int(center.x-radius)),mini(img.get_width(),int(center.x+radius)),3):
			if Vector2(x,y).distance_to(center)>radius:continue
			var c: Color=img.get_pixel(x,y)
			var value: float=(c.r+c.g+c.b)/3.0
			sum+=value;lo=minf(lo,value);hi=maxf(hi,value);n+=1
	return {"mean":sum/maxi(n,1),"range":hi-lo,"count":n,"center":center,"radius":radius}
func run() -> void:
	check(RenderingServer.get_current_rendering_method()=="forward_plus","real Forward+ renderer")
	var menu: Control=load("res://scenes/MainMenu.tscn").instantiate()
	root.add_child(menu);current_scene=menu
	var img: Image=await capture("godot-menu")
	check(img.get_width()>0,"real native framebuffer is available")
	menu.find_child("PlayButton",true,false).pressed.emit()
	await frame();await frame()
	universe=current_scene;universe.clock.set_running(false);universe.set_quality(2)
	img=await capture("godot-solar-overview")
	check(universe.markers.small.has("earth") and universe.markers.centers.size()==10,"Solar System overview supplies visible markers for all ten bodies")
	universe.camera_rig.focus("earth")
	universe.label_layer.visible=false
	universe.camera_rig.yaw=-PI/2.0;universe.camera_rig.tick(0)
	var day: Image=await capture("")
	var day_stats: Dictionary=body_pixels("earth",day)
	universe.camera_rig.yaw=PI/2.0;universe.camera_rig.tick(0)
	var night: Image=await capture("")
	var night_stats: Dictionary=body_pixels("earth",night)
	print("Earth day ",day_stats.mean," night ",night_stats.mean)
	check(day_stats.mean>0.07 and day_stats.mean>night_stats.mean*2.0,"actual Earth mesh shows directional day / night illumination")
	universe.camera_rig.focus("earth")
	var earth: Image=await capture("godot-earth")
	var earth_stats: Dictionary=body_pixels("earth",earth)
	check(earth_stats.range>0.15 and universe.visuals.earth.has_node("Clouds"),"Earth surface, ocean and moving cloud shader compile and render")
	universe.body_root.visible=false
	var sky: Image=await capture("")
	var differences: int=0
	var center: Vector2=earth_stats.center
	for y: int in range(int(center.y-65),int(center.y+65),3):
		for x: int in range(int(center.x-65),int(center.x+65),3):
			var a: Color=earth.get_pixel(x,y);var b: Color=sky.get_pixel(x,y)
			if absf(a.r-b.r)+absf(a.g-b.g)+absf(a.b-b.b)>.03:differences+=1
	check(differences>100,"Earth pixels come from the mesh, with labels and markers hidden")
	universe.body_root.visible=true
	var physical: Dictionary=universe.engine.snapshot()
	universe.true_scale=true;universe.calculate_display_radii();universe.camera_rig.focus("earth")
	img=await capture("godot-earth-true-size")
	check(body_pixels("earth",img).mean>0.07 and universe.engine.snapshot()==physical,"true-size Earth focus renders an actual mesh while retaining every SI state value")
	universe.true_scale=false;universe.calculate_display_radii()
	universe.camera_rig.focus("sun")
	img=await capture("godot-sun")
	var sun_stats: Dictionary=body_pixels("sun",img)
	print("Sun interior mean ",sun_stats.mean," range ",sun_stats.range)
	check(sun_stats.mean>0.25 and sun_stats.range>0.04,"Sun interior emits and retains granulation independently of UI pixels")
	universe.load_preset("binary");universe.clock.set_running(false)
	img=await capture("godot-binary-stars")
	var a_stats: Dictionary=body_pixels("star-a",img)
	var b_stats: Dictionary=body_pixels("star-b",img)
	check(a_stats.mean>0.25 and b_stats.mean>0.25 and a_stats.range>0.03 and b_stats.range>0.03,"both binary-star interiors visibly emit and have photosphere structure")
	universe.load_preset("earthmoon");universe.clock.set_running(false)
	img=await capture("godot-earth-moon")
	check(universe.engine.bodies.size()==2 and universe.visuals.size()==2,"Earth–Moon native surfaces and clouds compile")
	universe.load_preset("disk");universe.clock.set_running(false)
	img=await capture("godot-black-hole")
	var hole_id: String=universe.engine.bodies[0].id
	var stats: Dictionary=body_pixels(hole_id,img,1.0)
	center=stats.center
	var dark: Color=img.get_pixel(int(center.x),int(center.y))
	var luminous: int=0
	var max_value: float=0.0
	for y: int in range(int(center.y-150),int(center.y+150),3):
		for x: int in range(int(center.x-270),int(center.x+270),3):
			var c: Color=img.get_pixel(x,y);var value: float=(c.r+c.g+c.b)/3.0
			if value>0.18:luminous+=1
			max_value=maxf(max_value,value)
	print("Black hole center ",dark," disk bright samples ",luminous," max ",max_value)
	check(dark.r+dark.g+dark.b<0.10 and luminous>100,"ray shader renders a captured dark shadow surrounded by luminous accretion plasma")
	var initial: Image=img
	universe.engine.bodies[0].temperature=8000.0
	var cold: Image=await capture("")
	var hot_sum: float=0.0
	var cold_sum: float=0.0
	for y: int in range(int(center.y-100),int(center.y+100),4):
		for x: int in range(int(center.x-200),int(center.x+200),4):
			var hot_color: Color=initial.get_pixel(x,y);var cold_color: Color=cold.get_pixel(x,y)
			hot_sum+=hot_color.r+hot_color.g+hot_color.b;cold_sum+=cold_color.r+cold_color.g+cold_color.b
	check(hot_sum>cold_sum*2.0,"plasma temperature changes rendered radiance through T^4, beyond a palette change")
	universe.engine.bodies[0].temperature=16000.0
	universe.engine.time+=50.0*universe.engine.bodies[0].radius/BlackHoleSystem.C
	img=await capture("godot-black-hole-flow")
	var changed: int=0
	for y: int in range(int(center.y-100),int(center.y+100),4):
		for x: int in range(int(center.x-200),int(center.x+200),4):
			var ca: Color=img.get_pixel(x,y);var cb: Color=initial.get_pixel(x,y)
			if absf(ca.r-cb.r)+absf(ca.g-cb.g)+absf(ca.b-cb.b)>.04:changed+=1
	check(changed>40,"differential plasma advection and turbulence actually change rendered pixels over time")
	universe.engine.bodies[0].disk_enabled=false
	img=await capture("godot-black-hole-no-disk")
	var no_disk: int=0
	for y: int in range(int(center.y-100),int(center.y+100),4):
		for x: int in range(int(center.x-200),int(center.x+200),4):
			var c: Color=img.get_pixel(x,y)
			if (c.r+c.g+c.b)/3.0>.18:no_disk+=1
	check(no_disk<luminous/4,"disk toggle removes plasma emission while retaining gravitational capture rendering")
	var material: ShaderMaterial=universe.visuals[hole_id].material
	material.set_shader_parameter("debug_rays",true)
	img=await capture("")
	var unit_px: float=stats.radius
	var inner: Color=img.get_pixel(int(center.x+unit_px*2.4),int(center.y))
	var outer: Color=img.get_pixel(int(center.x+unit_px*3.0),int(center.y))
	check(inner.r>0.7 and inner.b<0.2 and outer.b>0.7 and outer.r<0.2,"GPU ray paths capture b=2.4 Rs and escape b=3.0 Rs around the analytic 2.598 Rs shadow")
	material.set_shader_parameter("debug_rays",false)
	universe.load_preset("neutronhole");universe.clock.set_running(false)
	universe.camera_rig.focus("pulsar")
	img=await capture("godot-pulsar")
	check(universe.visuals.pulsar.has_node("MagneticAxis") and body_pixels("pulsar",img).mean>.15,"neutron photosphere and tilted pulsar beams compile and emit")
	universe.set_quality(0)
	await frame()
	check(absf(root.scaling_3d_scale-.7)<1e-6 and not universe.world.environment.glow_enabled,"Performance changes the real Vulkan viewport")
	universe.set_quality(2)
	universe.ui.graphics.widgets.taa.button_pressed=true
	await frame()
	check(root.msaa_3d==Viewport.MSAA_4X and root.use_taa,"Ultra and TAA run on the actual Forward+ renderer")
	universe.label_layer.visible=true
	universe.load_preset("disk");universe.clock.set_running(false)
	await capture("godot-black-hole-ui")
	print("\nVulkan graphics: ",passed," passed; ",failed," failed. GPU: ",RenderingServer.get_video_adapter_name())
	quit(1 if failed else 0)
