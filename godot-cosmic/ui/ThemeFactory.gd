class_name ThemeFactory
extends RefCounted

static func panel(color: Color = Color("101923"), border: Color = Color("263640"), radius: int = 12) -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = color
	style.border_color = border
	style.set_border_width_all(1)
	style.set_corner_radius_all(radius)
	style.content_margin_left = 16
	style.content_margin_right = 16
	style.content_margin_top = 14
	style.content_margin_bottom = 14
	return style

static func make() -> Theme:
	var theme: Theme = Theme.new()
	theme.default_font_size = 18
	theme.set_color("font_color", "Label", Color("dae8ef"))
	theme.set_color("font_color", "Button", Color("d0e2e9"))
	theme.set_stylebox("normal", "Button", panel(Color("101a24"), Color("2a3d49"), 8))
	theme.set_stylebox("hover", "Button", panel(Color("1b303b"), Color("6bbaa9"), 8))
	theme.set_stylebox("pressed", "Button", panel(Color("254239"), Color("8ce8d3"), 8))
	theme.set_stylebox("focus", "Button", panel(Color(0,0,0,0), Color("8ce8d3"), 8))
	theme.set_stylebox("panel", "PanelContainer", panel())
	theme.set_stylebox("normal", "LineEdit", panel(Color("080f17"), Color("263c48"), 6))
	theme.set_stylebox("focus", "LineEdit", panel(Color("0a1720"), Color("8ce8d3"), 6))
	return theme

static func label(text: String, size: int = 18, color: Color = Color("d6e6ed")) -> Label:
	var l: Label = Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	return l

static func button(text: String, callback: Callable) -> Button:
	var b: Button = Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.pressed.connect(callback)
	return b
