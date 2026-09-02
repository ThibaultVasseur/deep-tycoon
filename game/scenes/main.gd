## Écran principal : HUD + pipeline interactif (mines -> ascenseur -> entrepôt) + prestige/boost.
## Construit par code pour la robustesse ; se reconstruit sur Game.structure_changed,
## et rafraîchit les valeurs dynamiques dans _process. Réf : docs/specs/ui-hud.md.
extends Control

# --- Palette "tycoon premium" (tons terre + or + néon) ---
const C_BG := Color("14100c")
const C_PANEL := Color("241b13")
const C_PANEL2 := Color("2e2318")
const C_GOLD := Color("f5b942")
const C_NEON := Color("ffd35c")
const C_TEXT := Color("f0e6d2")
const C_DIM := Color("8a7c68")
const C_GREEN := Color("74c96b")
const C_RED := Color("d9694f")
const C_BAR_BG := Color("120d09")

var _cash_label: Label
var _rate_label: Label
var _super_label: Label
var _boost_btn: Button
var _prestige_btn: Button
var _stations: VBoxContainer

var _mine_rows: Array = []      # [{i, level, out, bar, tap, up, mgr}]
var _elev_row: Dictionary = {}
var _wh_row: Dictionary = {}

var _hud_cash := 0.0
var _cash_pop := 1.0
var _exped_btn: Button

# Popup hors-ligne
var _offline_panel: Control
var _offline_text: Label

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_build_background()
	_build_hud()
	_build_mine_view()
	_build_stations_area()
	_build_bottom_bar()
	_build_offline_popup()
	Game.structure_changed.connect(_rebuild)
	Game.offline_ready.connect(_on_offline_ready)
	_rebuild()

	# Dev-only : capture d'écran pour vérif visuelle (activé par `-- shot`), sans effet en jeu normal.
	if OS.get_cmdline_user_args().has("shot"):
		await _dev_capture()

func _dev_capture() -> void:
	# État de démo (dev-only) pour une capture vivante : mines débloquées + automatisées.
	Game.state.super_cash = 200.0
	var c := Game.active()
	if c != null:
		c.cash = 125000.0
		for m in c.mines:
			m.level = maxi(m.level, 3)
			m.has_manager = true
		c.elevator.level = 4
		c.elevator.has_manager = true
		c.warehouse.level = 4
		c.warehouse.has_manager = true
		Game.structure_changed.emit()
	await get_tree().create_timer(1.0).timeout
	var img := get_viewport().get_texture().get_image()
	img.save_png("user://shot.png")
	get_tree().quit()

func _process(delta: float) -> void:
	if Game.state == null:
		return
	_refresh_hud()
	_refresh_rows()
	_refresh_expedition()
	_animate_cash_pop(delta)

func _refresh_expedition() -> void:
	if _exped_btn == null:
		return
	match Game.expedition_status():
		"idle":
			_exped_btn.disabled = false
			_exped_btn.text = "🧭 Lancer une expédition"
		"running":
			_exped_btn.disabled = true
			_exped_btn.text = "Expédition en cours… %s" % NumberFormat.format_duration(Game.expedition_time_left())
		"ready":
			_exped_btn.disabled = false
			_exped_btn.text = "🎁 Récolter l'expédition"
		"cooldown":
			_exped_btn.disabled = true
			_exped_btn.text = "Expédition (repos %s)" % NumberFormat.format_duration(Game.expedition_time_left())

func _on_expedition() -> void:
	match Game.expedition_status():
		"idle":
			Game.start_expedition()
		"ready":
			Game.collect_expedition()

func _animate_cash_pop(delta: float) -> void:
	var cash := Game.cash()
	if cash > _hud_cash + 0.0001:
		_cash_pop = 1.16
	_hud_cash = cash
	_cash_pop = lerpf(_cash_pop, 1.0, clampf(delta * 9.0, 0.0, 1.0))
	_cash_label.pivot_offset = _cash_label.size * 0.5
	_cash_label.scale = Vector2(_cash_pop, _cash_pop)

# ============================ CONSTRUCTION ============================

func _build_background() -> void:
	var bg := ColorRect.new()
	bg.color = C_BG
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)

func _build_hud() -> void:
	var panel := _panel(C_PANEL)
	panel.set_anchors_preset(Control.PRESET_TOP_WIDE)
	panel.offset_bottom = 132
	add_child(panel)

	var v := VBoxContainer.new()
	v.set_anchors_preset(Control.PRESET_FULL_RECT)
	v.add_theme_constant_override("separation", 2)
	_pad(v, 14, 10)
	panel.add_child(v)

	var title := _label("DEEP TYCOON", 16, C_GOLD)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(title)

	_cash_label = _label("0", 34, C_TEXT)
	_cash_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(_cash_label)

	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 18)
	v.add_child(row)
	_rate_label = _label("0/s", 16, C_GREEN)
	row.add_child(_rate_label)
	_super_label = _label("★ 0", 16, C_NEON)
	row.add_child(_super_label)

func _build_mine_view() -> void:
	var svc := SubViewportContainer.new()
	svc.stretch = true
	svc.set_anchors_preset(Control.PRESET_TOP_WIDE)
	svc.offset_top = 140
	svc.offset_bottom = 500
	svc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(svc)

	var sv := SubViewport.new()
	sv.disable_3d = true
	sv.transparent_bg = false
	svc.add_child(sv)

	var mine = load("res://game/scenes/mine_view.gd").new()
	sv.add_child(mine)

func _build_stations_area() -> void:
	var scroll := ScrollContainer.new()
	scroll.set_anchors_preset(Control.PRESET_FULL_RECT)
	scroll.offset_top = 508
	scroll.offset_bottom = -96
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)

	var margin := MarginContainer.new()
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	margin.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_pad(margin, 12, 8)
	scroll.add_child(margin)

	_stations = VBoxContainer.new()
	_stations.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_stations.add_theme_constant_override("separation", 10)
	margin.add_child(_stations)

func _build_bottom_bar() -> void:
	var panel := _panel(C_PANEL)
	panel.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	panel.offset_top = -88
	add_child(panel)

	var h := HBoxContainer.new()
	h.set_anchors_preset(Control.PRESET_FULL_RECT)
	h.alignment = BoxContainer.ALIGNMENT_CENTER
	h.add_theme_constant_override("separation", 12)
	_pad(h, 12, 12)
	panel.add_child(h)

	_boost_btn = _button("Boost x2 (pub)", C_NEON)
	_boost_btn.custom_minimum_size = Vector2(0, 60)
	_boost_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_boost_btn.pressed.connect(func(): Game.request_boost())
	h.add_child(_boost_btn)

	var skip := _button("Time-skip (pub)", C_GOLD)
	skip.custom_minimum_size = Vector2(0, 60)
	skip.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	skip.pressed.connect(func(): Game.request_time_skip())
	h.add_child(skip)

	_prestige_btn = _button("Prestige", C_GREEN)
	_prestige_btn.custom_minimum_size = Vector2(0, 60)
	_prestige_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_prestige_btn.pressed.connect(_on_prestige_pressed)
	h.add_child(_prestige_btn)

# ============================ RECONSTRUCTION ============================

func _rebuild() -> void:
	for c in _stations.get_children():
		c.queue_free()
	_mine_rows.clear()
	_elev_row = {}
	_wh_row = {}

	var cont := Game.active()
	if cont == null:
		return

	_stations.add_child(_build_continent_switcher())

	_exped_btn = _button("Expédition", C_NEON)
	_exped_btn.custom_minimum_size = Vector2(0, 50)
	_exped_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_exped_btn.pressed.connect(_on_expedition)
	_stations.add_child(_exped_btn)

	_stations.add_child(_section_label("MINES"))
	for i in cont.mines.size():
		_mine_rows.append(_build_mine_row(i))

	_stations.add_child(_section_label("LOGISTIQUE"))
	_elev_row = _build_component_row(
		"Ascenseur", Game.Target.ELEVATOR,
		func(): return Game.upgrade_elevator(),
		func(): Game.tap_elevator())
	_wh_row = _build_component_row(
		"Entrepôt", Game.Target.WAREHOUSE,
		func(): return Game.upgrade_warehouse(),
		func(): Game.tap_warehouse())

func _build_continent_switcher() -> Control:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 8)
	for id in Game.continent_count():
		var c := Game.continent_at(id)
		var accent := C_GOLD if id == Game.state.active_continent else C_PANEL2
		var btn := _button("", accent)
		btn.custom_minimum_size = Vector2(0, 54)
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		if c.unlocked:
			btn.text = c.name
			if id == Game.state.active_continent:
				btn.disabled = true
			else:
				btn.pressed.connect(func(): Game.switch_continent(id))
		else:
			var cost := Game.continent_unlock_cost(id)
			btn.text = "🔒 %s\n%s ★" % [c.name, NumberFormat.format(cost)]
			btn.add_theme_color_override("font_color", C_TEXT)
			btn.disabled = not Game.can_unlock_continent(id)
			btn.pressed.connect(func(): Game.unlock_continent(id))
		h.add_child(btn)
	return h

func _build_mine_row(i: int) -> Dictionary:
	var panel := _panel(C_PANEL2)
	_stations.add_child(panel)
	var v := VBoxContainer.new()
	_pad(v, 12, 10)
	v.add_theme_constant_override("separation", 6)
	panel.add_child(v)

	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 10)
	v.add_child(top)
	var name_lbl := _label("Mine", 18, C_GOLD)
	name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(name_lbl)
	var lvl_lbl := _label("Nv 0", 14, C_DIM)
	top.add_child(lvl_lbl)

	var out_lbl := _label("", 13, C_TEXT)
	v.add_child(out_lbl)

	var bar := _bar()
	v.add_child(bar)

	var btns := HBoxContainer.new()
	btns.add_theme_constant_override("separation", 8)
	v.add_child(btns)

	var tap := _button("EXTRAIRE", C_GOLD)
	tap.custom_minimum_size = Vector2(0, 52)
	tap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tap.pressed.connect(func(): Game.tap_mine(i))
	btns.add_child(tap)

	var up := _button("Améliorer", C_NEON)
	up.custom_minimum_size = Vector2(0, 52)
	up.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	up.pressed.connect(func(): Game.upgrade_or_unlock_mine(i))
	btns.add_child(up)

	var mgr := _button("Manager", C_GREEN)
	mgr.custom_minimum_size = Vector2(0, 52)
	mgr.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mgr.pressed.connect(func(): Game.hire_manager(Game.Target.MINE, i))
	btns.add_child(mgr)

	return {"i": i, "name": name_lbl, "level": lvl_lbl, "out": out_lbl,
		"bar": bar, "tap": tap, "up": up, "mgr": mgr}

func _build_component_row(title: String, target, upgrade_cb: Callable, tap_cb: Callable) -> Dictionary:
	var panel := _panel(C_PANEL2)
	_stations.add_child(panel)
	var v := VBoxContainer.new()
	_pad(v, 12, 10)
	v.add_theme_constant_override("separation", 6)
	panel.add_child(v)

	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 10)
	v.add_child(top)
	var name_lbl := _label(title, 18, C_GOLD)
	name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(name_lbl)
	var lvl_lbl := _label("Nv 1", 14, C_DIM)
	top.add_child(lvl_lbl)

	var info_lbl := _label("", 13, C_TEXT)
	v.add_child(info_lbl)

	var bar := _bar()
	v.add_child(bar)

	var btns := HBoxContainer.new()
	btns.add_theme_constant_override("separation", 8)
	v.add_child(btns)

	var tap := _button("ACTIONNER", C_GOLD)
	tap.custom_minimum_size = Vector2(0, 52)
	tap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tap.pressed.connect(func(): tap_cb.call())
	btns.add_child(tap)

	var up := _button("Améliorer", C_NEON)
	up.custom_minimum_size = Vector2(0, 52)
	up.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	up.pressed.connect(func(): upgrade_cb.call())
	btns.add_child(up)

	var mgr := _button("Manager", C_GREEN)
	mgr.custom_minimum_size = Vector2(0, 52)
	mgr.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mgr.pressed.connect(func(): Game.hire_manager(target, 0))
	btns.add_child(mgr)

	return {"target": target, "name": name_lbl, "level": lvl_lbl, "info": info_lbl,
		"bar": bar, "tap": tap, "up": up, "mgr": mgr}

# ============================ RAFRAÎCHISSEMENT ============================

func _refresh_hud() -> void:
	_cash_label.text = NumberFormat.format(Game.cash())
	_rate_label.text = NumberFormat.format(Game.cash_per_sec()) + "/s"
	_super_label.text = "★ " + NumberFormat.format(Game.super_cash())

	if Game.boost_active():
		var left := int(Game.state.boost_end_unix - Game.now())
		_boost_btn.text = "Boost actif " + NumberFormat.format_duration(left)
	else:
		_boost_btn.text = "Boost x2 (pub)"

	var pg := Game.prestige_gain_preview()
	_prestige_btn.disabled = pg < 1
	_prestige_btn.text = ("Prestige +%d ★" % pg) if pg >= 1 else "Prestige"

func _refresh_rows() -> void:
	var cont := Game.active()
	if cont == null:
		return
	var cash := Game.cash()

	for r in _mine_rows:
		var m: Mine = cont.mines[r.i]
		r.name.text = m.ore_name
		r.level.text = "Nv %d" % m.level
		if m.is_unlocked():
			r.out.text = "%s u/s  •  prix %s" % [
				NumberFormat.format(Economy.mine_output_per_sec(m)),
				NumberFormat.format(m.unit_price)]
			r.bar.value = (m.buffer / m.buffer_cap) if m.buffer_cap > 0 else 0.0
			r.tap.visible = not m.has_manager
			_set_cost_button(r.up, "Améliorer", Economy.mine_upgrade_cost(m), cash)
			_update_manager_button(r.mgr, Game.Target.MINE, r.i, m)
		else:
			r.out.text = "Verrouillée"
			r.bar.value = 0.0
			r.tap.visible = false
			_set_cost_button(r.up, "Débloquer", Economy.mine_upgrade_cost(m), cash)
			r.mgr.visible = false

	if not _elev_row.is_empty():
		var e := cont.elevator
		_elev_row.level.text = "Nv %d" % e.level
		_elev_row.info.text = "%s u/s" % NumberFormat.format(Economy.elevator_throughput(e))
		_elev_row.bar.value = 0.5
		_elev_row.tap.visible = not e.has_manager
		_set_cost_button(_elev_row.up, "Améliorer", Economy.elevator_upgrade_cost(e), cash)
		_update_manager_button(_elev_row.mgr, Game.Target.ELEVATOR, 0, e)

	if not _wh_row.is_empty():
		var w := cont.warehouse
		var cap := Economy.warehouse_store_cap(w)
		_wh_row.level.text = "Nv %d" % w.level
		_wh_row.info.text = "%s / %s  •  %s u/s" % [
			NumberFormat.format(w.stock), NumberFormat.format(cap),
			NumberFormat.format(Economy.warehouse_sell_rate(w))]
		_wh_row.bar.value = (w.stock / cap) if cap > 0 else 0.0
		_wh_row.tap.visible = not w.has_manager
		_set_cost_button(_wh_row.up, "Améliorer", Economy.warehouse_upgrade_cost(w), cash)
		_update_manager_button(_wh_row.mgr, Game.Target.WAREHOUSE, 0, w)

func _update_manager_button(btn: Button, target, i: int, comp) -> void:
	if comp.has_manager:
		btn.visible = true
		btn.disabled = true
		btn.text = "✓ Auto"
	elif comp.level < Game.config.manager_unlock_level:
		btn.visible = true
		btn.disabled = true
		btn.text = "Manager Nv%d" % Game.config.manager_unlock_level
	else:
		btn.visible = true
		var cost := Game.manager_cost(target, i)
		btn.disabled = Game.cash() < cost
		btn.text = "Manager\n%s" % NumberFormat.format(cost)

func _set_cost_button(btn: Button, prefix: String, cost: float, cash: float) -> void:
	btn.text = "%s\n%s" % [prefix, NumberFormat.format(cost)]
	btn.disabled = cash < cost

# ============================ POPUP HORS-LIGNE ============================

func _build_offline_popup() -> void:
	_offline_panel = _panel(C_PANEL)
	_offline_panel.set_anchors_preset(Control.PRESET_CENTER)
	_offline_panel.custom_minimum_size = Vector2(520, 320)
	_offline_panel.offset_left = -260
	_offline_panel.offset_right = 260
	_offline_panel.offset_top = -160
	_offline_panel.offset_bottom = 160
	_offline_panel.visible = false
	add_child(_offline_panel)

	var v := VBoxContainer.new()
	v.set_anchors_preset(Control.PRESET_FULL_RECT)
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_theme_constant_override("separation", 16)
	_pad(v, 22, 22)
	_offline_panel.add_child(v)

	var t := _label("De retour !", 24, C_GOLD)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(t)

	_offline_text = _label("", 16, C_TEXT)
	_offline_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_offline_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(_offline_text)

	var x2 := _button("Doubler (pub) x2", C_NEON)
	x2.custom_minimum_size = Vector2(0, 60)
	x2.pressed.connect(func():
		Game.claim_offline_double()
		_offline_panel.visible = false)
	v.add_child(x2)

	var ok := _button("Récupérer", C_GREEN)
	ok.custom_minimum_size = Vector2(0, 56)
	ok.pressed.connect(func(): _offline_panel.visible = false)
	v.add_child(ok)

func _on_offline_ready(elapsed: float, gain: float) -> void:
	_offline_text.text = "Absent %s\n\n+ %s récoltés par ta chaîne automatisée." % [
		NumberFormat.format_duration(elapsed), NumberFormat.format(gain)]
	_offline_panel.visible = true

func _on_prestige_pressed() -> void:
	if Game.can_prestige():
		Game.do_prestige()

# ============================ HELPERS UI ============================

func _panel(bg: Color) -> PanelContainer:
	var p := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.corner_radius_top_left = 14
	sb.corner_radius_top_right = 14
	sb.corner_radius_bottom_left = 14
	sb.corner_radius_bottom_right = 14
	sb.border_color = Color(0, 0, 0, 0.25)
	sb.content_margin_left = 14
	sb.content_margin_right = 14
	sb.content_margin_top = 12
	sb.content_margin_bottom = 12
	p.add_theme_stylebox_override("panel", sb)
	return p

func _label(text: String, size: int, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	return l

func _section_label(text: String) -> Label:
	var l := _label(text, 13, C_DIM)
	l.add_theme_constant_override("outline_size", 0)
	return l

func _button(text: String, accent: Color) -> Button:
	var b := Button.new()
	b.text = text
	b.add_theme_font_size_override("font_size", 15)
	b.add_theme_color_override("font_color", C_BG)
	b.add_theme_color_override("font_disabled_color", C_DIM)
	var sb := StyleBoxFlat.new()
	sb.bg_color = accent
	sb.corner_radius_top_left = 10
	sb.corner_radius_top_right = 10
	sb.corner_radius_bottom_left = 10
	sb.corner_radius_bottom_right = 10
	sb.content_margin_left = 8
	sb.content_margin_right = 8
	sb.content_margin_top = 6
	sb.content_margin_bottom = 6
	b.add_theme_stylebox_override("normal", sb)
	var hover := sb.duplicate()
	hover.bg_color = accent.lightened(0.12)
	b.add_theme_stylebox_override("hover", hover)
	var pressed := sb.duplicate()
	pressed.bg_color = accent.darkened(0.15)
	b.add_theme_stylebox_override("pressed", pressed)
	var dis := sb.duplicate()
	dis.bg_color = C_PANEL2
	b.add_theme_stylebox_override("disabled", dis)
	return b

func _bar() -> ProgressBar:
	var pb := ProgressBar.new()
	pb.min_value = 0.0
	pb.max_value = 1.0
	pb.value = 0.0
	pb.show_percentage = false
	pb.custom_minimum_size = Vector2(0, 12)
	var bg := StyleBoxFlat.new()
	bg.bg_color = C_BAR_BG
	bg.corner_radius_top_left = 6
	bg.corner_radius_top_right = 6
	bg.corner_radius_bottom_left = 6
	bg.corner_radius_bottom_right = 6
	pb.add_theme_stylebox_override("background", bg)
	var fill := StyleBoxFlat.new()
	fill.bg_color = C_GOLD
	fill.corner_radius_top_left = 6
	fill.corner_radius_top_right = 6
	fill.corner_radius_bottom_left = 6
	fill.corner_radius_bottom_right = 6
	pb.add_theme_stylebox_override("fill", fill)
	return pb

func _pad(node: Control, h: int, v: int) -> void:
	node.add_theme_constant_override("margin_left", h)
	node.add_theme_constant_override("margin_right", h)
	node.add_theme_constant_override("margin_top", v)
	node.add_theme_constant_override("margin_bottom", v)
