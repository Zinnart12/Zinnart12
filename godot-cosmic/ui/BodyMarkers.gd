class_name BodyMarkers
extends Control

var universe: UniverseManager
var centers: Dictionary = {}
var small: Dictionary = {}
var reasons: Dictionary = {}

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func rebuild() -> void:
	centers.clear(); small.clear(); reasons.clear()
	var camera: Camera3D = universe.camera_rig.camera
	var size_value: Vector2 = get_viewport_rect().size
	var factor: float = size_value.y/(2.0*tan(deg_to_rad(camera.fov*0.5)))
	var occupied: Array[Rect2] = []
	# Selected labels get space first; subsequent labels avoid their rectangles.
	var ordered: Array[CelestialBody] = universe.engine.bodies.duplicate()
	ordered.sort_custom(func(a: CelestialBody,b: CelestialBody) -> bool: return a.id==universe.selected_id and b.id!=universe.selected_id)
	for body: CelestialBody in ordered:
		var label: Label = universe.labels[body.id]
		label.visible = false
		var point: Vector3 = universe.visuals[body.id].position
		var distance: float = camera.position.distance_to(point)
		if camera.is_position_behind(point): reasons[body.id]="Behind camera"; continue
		if distance>camera.far: reasons[body.id]="Beyond far clip"; continue
		var center: Vector2 = camera.unproject_position(point)
		if not Rect2(Vector2.ZERO,size_value).has_point(center): reasons[body.id]="Outside camera frame"; continue
		centers[body.id] = center
		var pixels: float = float(universe.display_radii[body.id])/maxf(distance,1e-12)*factor
		if pixels < 5.0:
			small[body.id]=true
			reasons[body.id]="Sub-pixel mesh / selection marker active" if pixels<1.0 else "Small mesh / marker active"
		else: reasons[body.id]="Mesh in frame"
		if universe.show_labels:
			label.text = body.body_name
			label.modulate=Color("8ce8d3") if body.id==universe.selected_id else Color.WHITE
			var label_size: Vector2 = label.get_minimum_size()
			for offset: int in range(8):
				var anchor: Vector2 = center+Vector2(14,-8-offset*19)
				var rect: Rect2 = Rect2(anchor,label_size+Vector2(6,4))
				if anchor.y<75 or rect.end.x>size_value.x-350 or rect.position.x<330: continue
				if occupied.any(func(other: Rect2) -> bool: return other.intersects(rect)): continue
				occupied.append(rect);label.position=anchor;label.visible=true;break
	queue_redraw()

func _draw() -> void:
	if universe == null:return
	for id_value: String in centers:
		var body: CelestialBody = universe.engine.find_body(id_value)
		var p: Vector2 = centers[id_value]
		if small.has(id_value):
			var radius: float = 7.0 if body.is_luminous() else 5.0
			var tint: Color = StarSystem.temperature_color(body.temperature) if body.is_luminous() else body.color
			if body.kind=="black_hole":
				draw_circle(p,6.0,Color.BLACK)
				draw_arc(p,7.0,0,TAU,32,Color("ffb660"),1.5,true)
			else:
				draw_circle(p,radius,tint*0.45)
				draw_circle(p-Vector2(radius*.2,radius*.2),radius*.65,tint)
				draw_arc(p,radius+1,0,TAU,24,Color(tint,0.45),1.0,true)
		if id_value==universe.selected_id:
			draw_arc(p,12,0,TAU,40,Color("8ce8d3"),1.4,true)

func pick(screen: Vector2) -> String:
	var closest: float = 14.0
	var result: String = ""
	for id_value: String in centers:
		var distance: float = screen.distance_to(centers[id_value])
		if distance<closest: closest=distance;result=id_value
	return result
