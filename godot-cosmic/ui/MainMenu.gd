extends Control

func _ready() -> void:
	theme = ThemeFactory.make()
	var bg: ColorRect = ColorRect.new()
	bg.color = Color("050b12")
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 47813
	for i: int in range(200):
		var star: ColorRect = ColorRect.new()
		star.color = Color(0.6,0.8,0.95,rng.randf_range(0.08,0.4))
		star.position = Vector2(rng.randf_range(0,1920),rng.randf_range(0,1080))
		star.size = Vector2.ONE * rng.randf_range(1.0,3.0)
		star.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(star)
	var center: CenterContainer = CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var card: PanelContainer = PanelContainer.new()
	card.custom_minimum_size = Vector2(610,0)
	center.add_child(card)
	var box: VBoxContainer = VBoxContainer.new()
	box.add_theme_constant_override("separation", 18)
	card.add_child(box)
	box.add_child(ThemeFactory.label("C O S M I C   S A N D B O X", 38))
	box.add_child(ThemeFactory.label("3D UNIVERSE SIMULATOR  /  GODOT 4", 16, Color("8ce8d3")))
	box.add_child(HSeparator.new())
	box.add_child(ThemeFactory.label("Change the mass. Watch gravity respond.\nA native laboratory for real N-body orbits.", 20, Color("92aab8")))
	var play: Button = ThemeFactory.button("ENTER SANDBOX", func() -> void: get_tree().change_scene_to_file("res://scenes/Sandbox.tscn"))
	play.name = "PlayButton"
	box.add_child(play)
	var load_button: Button = ThemeFactory.button("CONTINUE SAVED SIMULATION", continue_saved)
	box.add_child(load_button)
	var graphics: GraphicsMenu = GraphicsMenu.new()
	add_child(graphics)
	box.add_child(ThemeFactory.button("GRAPHICS & DISPLAY", func() -> void: graphics.popup_centered()))
	box.add_child(ThemeFactory.button("QUIT", func() -> void: get_tree().quit()))
	box.add_child(ThemeFactory.label("PHASE 1  ·  SI UNITS  ·  CPU FLOAT64  ·  FORWARD+", 13, Color("678596")))

func continue_saved() -> void:
	var result: Dictionary = SaveSystem.load_snapshot()
	if result.has("error"):
		var popup: AcceptDialog = AcceptDialog.new()
		popup.dialog_text = result.error
		add_child(popup)
		popup.popup_centered()
		return
	get_tree().set_meta("restore_cosmic", result.data)
	get_tree().change_scene_to_file("res://scenes/Sandbox.tscn")
