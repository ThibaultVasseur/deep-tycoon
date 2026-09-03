## Kit UI partagé : palette "tycoon premium" + fabriques de composants stylés.
## Centralise le look pour la cohérence et la maintenabilité (une seule source de style).
class_name Ui
extends RefCounted

const C_BG := Color("14100c")
const C_BG2 := Color("1c1710")
const C_PANEL := Color("261d14")
const C_PANEL2 := Color("30251a")
const C_GOLD := Color("f5b942")
const C_NEON := Color("ffd35c")
const C_TEXT := Color("f2e8d5")
const C_DIM := Color("8a7c68")
const C_GREEN := Color("74c96b")
const C_RED := Color("d9694f")
const C_BAR_BG := Color("100b07")

static func panel(bg: Color, radius: int = 16, shadow: bool = true) -> PanelContainer:
	var p := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.set_corner_radius_all(radius)
	sb.content_margin_left = 14
	sb.content_margin_right = 14
	sb.content_margin_top = 12
	sb.content_margin_bottom = 12
	sb.border_color = Color(1, 1, 1, 0.05)
	sb.set_border_width_all(1)
	if shadow:
		sb.shadow_color = Color(0, 0, 0, 0.35)
		sb.shadow_size = 6
		sb.shadow_offset = Vector2(0, 3)
	p.add_theme_stylebox_override("panel", sb)
	return p

static func label(text: String, size: int, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	return l

static func section(text: String) -> Label:
	var l := label(text, 12, C_DIM)
	return l

static func button(text: String, accent: Color, fg: Color = C_BG) -> Button:
	var b := Button.new()
	b.text = text
	b.add_theme_font_size_override("font_size", 15)
	b.add_theme_color_override("font_color", fg)
	b.add_theme_color_override("font_hover_color", fg)
	b.add_theme_color_override("font_pressed_color", fg)
	b.add_theme_color_override("font_disabled_color", C_DIM)
	_apply_button_style(b, accent)
	return b

static func _apply_button_style(b: Button, accent: Color) -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = accent
	sb.set_corner_radius_all(11)
	sb.content_margin_left = 8
	sb.content_margin_right = 8
	sb.content_margin_top = 7
	sb.content_margin_bottom = 7
	b.add_theme_stylebox_override("normal", sb)
	var hover := sb.duplicate()
	hover.bg_color = accent.lightened(0.12)
	b.add_theme_stylebox_override("hover", hover)
	var pressed := sb.duplicate()
	pressed.bg_color = accent.darkened(0.16)
	b.add_theme_stylebox_override("pressed", pressed)
	var dis := sb.duplicate()
	dis.bg_color = C_PANEL2
	b.add_theme_stylebox_override("disabled", dis)

static func recolor(b: Button, accent: Color, fg: Color = C_BG) -> void:
	b.add_theme_color_override("font_color", fg)
	b.add_theme_color_override("font_disabled_color", C_DIM)
	_apply_button_style(b, accent)

static func bar(fill: Color = C_GOLD, height: int = 10) -> ProgressBar:
	var pb := ProgressBar.new()
	pb.min_value = 0.0
	pb.max_value = 1.0
	pb.value = 0.0
	pb.show_percentage = false
	pb.custom_minimum_size = Vector2(0, height)
	var bg := StyleBoxFlat.new()
	bg.bg_color = C_BAR_BG
	bg.set_corner_radius_all(height / 2)
	pb.add_theme_stylebox_override("background", bg)
	var fs := StyleBoxFlat.new()
	fs.bg_color = fill
	fs.set_corner_radius_all(height / 2)
	pb.add_theme_stylebox_override("fill", fs)
	return pb

static func margins(node: Control, h: int, v: int) -> void:
	node.add_theme_constant_override("margin_left", h)
	node.add_theme_constant_override("margin_right", h)
	node.add_theme_constant_override("margin_top", v)
	node.add_theme_constant_override("margin_bottom", v)
