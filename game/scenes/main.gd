## Routeur d'écrans : navigue entre la page d'un continent et la carte du monde (fondu).
## Gère aussi la popup de retour hors-ligne (au-dessus de toute vue). Réf : docs/specs/ui-hud.md.
extends Control

var _continent: Control
var _map: Control
var _offline_panel: Control
var _offline_text: Label

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var bg := ColorRect.new()
	bg.color = Ui.C_BG
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)

	_continent = load("res://game/scenes/continent_view.gd").new()
	_continent.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_continent)
	_continent.go_to_map.connect(_show_map)

	_map = load("res://game/scenes/map_view.gd").new()
	_map.set_anchors_preset(Control.PRESET_FULL_RECT)
	_map.visible = false
	add_child(_map)
	_map.enter_continent.connect(_enter_continent)

	_build_offline_popup()
	Game.offline_ready.connect(_on_offline_ready)
	_swap_to(_continent)

	if OS.get_cmdline_user_args().has("shot"):
		await _dev_capture()

func _enter_continent(id: int) -> void:
	Game.switch_continent(id)
	_continent.refresh_all()
	_swap_to(_continent)

func _show_map() -> void:
	_map.refresh_all()
	_swap_to(_map)

func _swap_to(target: Control) -> void:
	for v in [_continent, _map]:
		v.visible = (v == target)
		v.set_process(v == target)
	target.modulate = Color(1, 1, 1, 0)
	var tw := create_tween()
	tw.tween_property(target, "modulate:a", 1.0, 0.22)

# --- Popup hors-ligne ---

func _build_offline_popup() -> void:
	_offline_panel = Ui.panel(Ui.C_PANEL)
	_offline_panel.set_anchors_preset(Control.PRESET_CENTER)
	_offline_panel.offset_left = -260
	_offline_panel.offset_right = 260
	_offline_panel.offset_top = -170
	_offline_panel.offset_bottom = 170
	_offline_panel.visible = false
	add_child(_offline_panel)
	var v := VBoxContainer.new()
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_theme_constant_override("separation", 16)
	_offline_panel.add_child(v)
	var t := Ui.label("De retour !", 24, Ui.C_GOLD)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(t)
	_offline_text = Ui.label("", 16, Ui.C_TEXT)
	_offline_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_offline_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(_offline_text)
	var x2 := Ui.button("Doubler (pub) ×2", Ui.C_NEON)
	x2.custom_minimum_size = Vector2(0, 58)
	x2.pressed.connect(func(): Game.claim_offline_double(); _offline_panel.visible = false)
	v.add_child(x2)
	var ok := Ui.button("Récupérer", Ui.C_GREEN)
	ok.custom_minimum_size = Vector2(0, 54)
	ok.pressed.connect(func(): _offline_panel.visible = false)
	v.add_child(ok)

func _on_offline_ready(elapsed: float, gain: float) -> void:
	_offline_text.text = "Absent %s\n\n+ %s récoltés par ta chaîne automatisée." % [
		NumberFormat.format_duration(elapsed), NumberFormat.format(gain)]
	_offline_panel.visible = true

# --- Capture dev (activée par `-- shot`) ---

func _dev_capture() -> void:
	Game.state.super_cash = 200.0
	var c := Game.active()
	if c != null:
		c.cash = 5.0e8
		for m in c.mines:
			m.level = maxi(m.level, 4)
			m.has_manager = true
		c.elevator.level = 6
		c.elevator.has_manager = true
		c.warehouse.level = 6
		c.warehouse.has_manager = true
		Game.structure_changed.emit()
	if OS.get_cmdline_user_args().has("map"):
		Game.continent_at(1).unlocked = true
		_show_map()
	await get_tree().create_timer(1.1).timeout
	get_viewport().get_texture().get_image().save_png("user://shot.png")
	get_tree().quit()
