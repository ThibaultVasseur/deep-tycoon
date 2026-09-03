## Carte du monde : voyage entre continents + déblocage au super-cash. Réf : PRD §3.7.
extends Control

signal enter_continent(id: int)

var _super_label: Label
var _cards := VBoxContainer.new()
var _unlock_btns := {}   # id -> Button (pour rafraîchir l'état "abordable")

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var bg := ColorRect.new()
	bg.color = Ui.C_BG2
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)

	var header := Ui.panel(Ui.C_PANEL, 0, false)
	header.set_anchors_preset(Control.PRESET_TOP_WIDE)
	header.offset_bottom = 92
	add_child(header)
	var hv := VBoxContainer.new()
	hv.add_theme_constant_override("separation", 2)
	header.add_child(hv)
	var t := Ui.label("🗺  Carte du monde", 22, Ui.C_GOLD)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hv.add_child(t)
	_super_label = Ui.label("★ 0 super-cash", 16, Ui.C_NEON)
	_super_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hv.add_child(_super_label)

	var scroll := ScrollContainer.new()
	scroll.set_anchors_preset(Control.PRESET_FULL_RECT)
	scroll.offset_top = 100
	scroll.offset_bottom = -10
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)
	var margin := MarginContainer.new()
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	Ui.margins(margin, 14, 10)
	scroll.add_child(margin)
	_cards.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_cards.add_theme_constant_override("separation", 14)
	margin.add_child(_cards)

	Game.structure_changed.connect(refresh_all)
	refresh_all()

func _process(_delta: float) -> void:
	if Game.state == null:
		return
	_super_label.text = "★ %s super-cash" % NumberFormat.format(Game.super_cash())
	for id in _unlock_btns:
		_unlock_btns[id].disabled = not Game.can_unlock_continent(id)

func refresh_all() -> void:
	for c in _cards.get_children():
		c.queue_free()
	_unlock_btns.clear()
	for id in Game.continent_count():
		_cards.add_child(_build_card(id))

func _build_card(id: int) -> Control:
	var cont := Game.continent_at(id)
	var tint := Content.continent_tint(id)
	var panel := Ui.panel(Ui.C_PANEL2)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	panel.add_child(row)

	# Vignette teintée + icône du continent.
	var badge := PanelContainer.new()
	badge.custom_minimum_size = Vector2(66, 66)
	var bsb := StyleBoxFlat.new()
	bsb.bg_color = tint if cont.unlocked else tint.darkened(0.55)
	bsb.set_corner_radius_all(14)
	badge.add_theme_stylebox_override("panel", bsb)
	var icon := Ui.label(Content.continent_icon(id), 30, Ui.C_BG)
	icon.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	icon.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	var cc := CenterContainer.new()
	cc.add_child(icon)
	badge.add_child(cc)
	row.add_child(badge)

	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_theme_constant_override("separation", 4)
	row.add_child(v)
	var name_lbl := Ui.label(cont.name, 19, tint if cont.unlocked else Ui.C_DIM)
	v.add_child(name_lbl)

	var status := ""
	if id == Game.state.active_continent:
		status = "● Continent actuel"
	elif cont.unlocked:
		status = "Débloqué"
	else:
		status = "Verrouillé — %s ★ super-cash" % NumberFormat.format(Content.continent_unlock_cost(id))
	v.add_child(Ui.label(status, 13, Ui.C_TEXT if cont.unlocked else Ui.C_DIM))

	# Action.
	if cont.unlocked:
		var enter := Ui.button("Entrer", tint)
		enter.custom_minimum_size = Vector2(120, 56)
		enter.pressed.connect(func(): enter_continent.emit(id))
		row.add_child(enter)
	else:
		var unlock := Ui.button("Débloquer\n%s ★" % NumberFormat.format(Content.continent_unlock_cost(id)), Ui.C_NEON)
		unlock.custom_minimum_size = Vector2(120, 56)
		unlock.disabled = not Game.can_unlock_continent(id)
		unlock.pressed.connect(func(): Game.unlock_continent(id))
		_unlock_btns[id] = unlock
		row.add_child(unlock)

	return panel
