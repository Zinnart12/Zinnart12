class_name GraphicsMenu
extends AcceptDialog

static var selected_quality: int = 1

var quality_selected: Callable
var fullscreen: CheckButton
var quality_picker: OptionButton

func _ready() -> void:
	title = "Graphics & Display"
	size = Vector2i(470, 280)
	var box: VBoxContainer = VBoxContainer.new()
	box.add_theme_constant_override("separation", 15)
	add_child(box)
	box.add_child(ThemeFactory.label("NATIVE GODOT 4 / FORWARD+", 15, Color("8ce8d3")))
	quality_picker = OptionButton.new()
	for value: String in ["Performance", "Balanced (adaptive)", "Ultra"]: quality_picker.add_item(value)
	quality_picker.select(selected_quality)
	quality_picker.item_selected.connect(func(index: int) -> void:
		selected_quality = index
		if quality_selected.is_valid(): quality_selected.call(index))
	box.add_child(quality_picker)
	fullscreen = CheckButton.new()
	fullscreen.text = "Fullscreen (F11)"
	fullscreen.button_pressed = DisplayServer.window_get_mode() in [DisplayServer.WINDOW_MODE_FULLSCREEN, DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN]
	fullscreen.toggled.connect(func(enabled: bool) -> void: DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if enabled else DisplayServer.WINDOW_MODE_WINDOWED))
	box.add_child(fullscreen)
	var notice: Label = ThemeFactory.label("Target: 1080p / RTX 3050 Ti\nPerformance depends on scene and hardware.", 15, Color("8198a7"))
	box.add_child(notice)
