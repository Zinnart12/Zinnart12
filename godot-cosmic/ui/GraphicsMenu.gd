class_name GraphicsMenu
extends AcceptDialog

static var selected_quality: int = 1
static var settings: Dictionary = {"render_scale":1.0,"msaa":1,"taa":false,"glow":true,"exposure":1.0,"shadow_quality":1,"planet_detail":1,"star_detail":1,"particle_quality":1,"black_hole_quality":1,"lod":true,"vsync":true,"fps_limit":60,"texture_detail":1}
var quality_selected: Callable
var fullscreen: CheckButton
var quality_picker: OptionButton
var widgets: Dictionary = {}
var refreshing: bool = false

func _ready() -> void:
	title="Graphics & Display / Forward+"
	size=Vector2i(650,660)
	var scroll: ScrollContainer=ScrollContainer.new()
	scroll.custom_minimum_size=Vector2(620,540)
	scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)
	var box: VBoxContainer=VBoxContainer.new()
	box.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override("separation",8)
	scroll.add_child(box)
	box.add_child(ThemeFactory.label("VULKAN · LINEAR HDR · ACES",16,Color("8ce8d3")))
	quality_picker=OptionButton.new()
	for value: String in ["Performance","Balanced (adaptive)","Ultra"]:quality_picker.add_item(value)
	quality_picker.select(selected_quality)
	quality_picker.item_selected.connect(select_preset)
	box.add_child(quality_picker)
	add_slider(box,"Render resolution scale","render_scale",0.5,1.5,0.05)
	add_choice(box,"MSAA","msaa",["Off","2x","4x","8x"])
	add_check(box,"TAA (Forward+)","taa")
	add_check(box,"HDR glow","glow")
	add_slider(box,"Exposure","exposure",0.25,2.5,0.05)
	add_choice(box,"Analytic ring / planet shadows","shadow_quality",["Off","Hard","Filtered"])
	for entry: Array in [["Procedural texture detail","texture_detail"],["Planet mesh detail","planet_detail"],["Star surface detail","star_detail"],["Corona / pulsar effects","particle_quality"],["Black hole ray precision","black_hole_quality"]]:
		add_choice(box,entry[0],entry[1],["Low","Medium","High"])
	add_check(box,"Angular mesh LOD","lod")
	add_check(box,"VSync","vsync")
	add_slider(box,"FPS limit (0 = unlimited)","fps_limit",0,144,1)
	fullscreen=CheckButton.new()
	fullscreen.text="Fullscreen (F11)"
	fullscreen.button_pressed=DisplayServer.window_get_mode()==DisplayServer.WINDOW_MODE_FULLSCREEN
	fullscreen.toggled.connect(func(enabled: bool) -> void:DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if enabled else DisplayServer.WINDOW_MODE_WINDOWED))
	box.add_child(fullscreen)
	box.add_child(ThemeFactory.label("1080p target / RTX 3050 Ti. CPU physics keeps its own substeps.\nProcedural assets need no image texture packs. HDR is the internal pipeline.",13,Color("8198a7")))

func add_slider(box: VBoxContainer,text_value: String,key: String,minimum: float,maximum: float,step_value: float) -> void:
	var row: HBoxContainer=HBoxContainer.new()
	var label: Label=ThemeFactory.label(text_value,14)
	label.custom_minimum_size.x=280
	row.add_child(label)
	var slider: HSlider=HSlider.new()
	slider.custom_minimum_size.x=235
	slider.min_value=minimum;slider.max_value=maximum;slider.step=step_value;slider.value=float(settings[key])
	slider.value_changed.connect(func(value: float) -> void:change(key,value))
	widgets[key]=slider;row.add_child(slider);box.add_child(row)

func add_choice(box: VBoxContainer,text_value: String,key: String,choices: Array) -> void:
	var row: HBoxContainer=HBoxContainer.new()
	var label: Label=ThemeFactory.label(text_value,14)
	label.custom_minimum_size.x=280
	row.add_child(label)
	var picker: OptionButton=OptionButton.new()
	for choice: String in choices:picker.add_item(choice)
	picker.select(int(settings[key]))
	picker.item_selected.connect(func(index: int) -> void:change(key,index))
	widgets[key]=picker;row.add_child(picker);box.add_child(row)

func add_check(box: VBoxContainer,text_value: String,key: String) -> void:
	var check: CheckBox=CheckBox.new()
	check.text=text_value;check.button_pressed=bool(settings[key])
	check.toggled.connect(func(value: bool) -> void:change(key,value))
	widgets[key]=check;box.add_child(check)

func change(key: String,value: Variant) -> void:
	if refreshing:return
	settings[key]=value
	if quality_selected.is_valid():quality_selected.call(selected_quality)

func select_preset(index: int) -> void:
	selected_quality=index
	if quality_picker!=null:quality_picker.select(index)
	settings={"render_scale":0.7 if index==0 else 1.0,"msaa":0 if index==0 else 1 if index==1 else 2,"taa":false,"glow":index!=0,"exposure":1.0,"shadow_quality":index,"planet_detail":index,"star_detail":index,"particle_quality":index,"black_hole_quality":index,"lod":true,"vsync":true,"fps_limit":60,"texture_detail":index}
	refreshing=true
	for key: String in widgets:
		var widget: Control=widgets[key]
		if widget is Range:widget.set_value_no_signal(float(settings[key]))
		elif widget is OptionButton:widget.select(int(settings[key]))
		elif widget is BaseButton:widget.set_pressed_no_signal(bool(settings[key]))
	refreshing=false
	if quality_selected.is_valid():quality_selected.call(index)

func apply_to(universe: UniverseManager) -> void:
	var viewport: Viewport=universe.get_viewport()
	viewport.scaling_3d_scale=float(settings.render_scale)
	viewport.msaa_3d=int(settings.msaa)
	viewport.use_taa=bool(settings.taa)
	universe.world.environment.glow_enabled=bool(settings.glow)
	universe.world.environment.tonemap_exposure=float(settings.exposure)
	universe.adaptive_scale=float(settings.render_scale)
	if DisplayServer.get_name()!="headless":DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED if settings.vsync else DisplayServer.VSYNC_DISABLED)
	Engine.max_fps=int(settings.fps_limit)
