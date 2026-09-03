## Page d'un continent : HUD local + bannière animée + mode d'achat (x1/x10/Max)
## + liste des étages + logistique + expédition + prestige/boost. Réf : docs/specs/ui-hud.md.
extends Control

signal go_to_map

var _name_label: Label
var _cash_label: Label
var _rate_label: Label
var _super_label: Label
var _prestige_btn: Button
var _boost_btn: Button
var _exped_btn: Button
var _stations: VBoxContainer
var _buy_btns := {}

var _floor_rows: Array = []
var _elev_row: Dictionary = {}
var _wh_row: Dictionary = {}

var _hud_cash := 0.0
var _cash_pop := 1.0
var _last_buy_mode := 999

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_build_hud()
	_build_banner()
	_build_buy_mode_bar()
	_build_stations_area()
	_build_bottom_bar()
	Game.structure_changed.connect(_rebuild)
	_rebuild()

func refresh_all() -> void:
	# Appelé par le routeur quand on (re)entre sur ce continent.
	_rebuild()

func _process(delta: float) -> void:
	if Game.state == null:
		return
	_refresh_hud()
	_refresh_rows()
	_refresh_expedition()
	_refresh_buy_mode()
	_animate_cash_pop(delta)

# ============================ CONSTRUCTION ============================

func _build_hud() -> void:
	var panel := Ui.panel(Ui.C_PANEL, 0, false)
	panel.set_anchors_preset(Control.PRESET_TOP_WIDE)
	panel.offset_bottom = 150
	add_child(panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 2)
	panel.add_child(v)

	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 8)
	v.add_child(top)
	var map_btn := Ui.button("🗺", Ui.C_PANEL2, Ui.C_TEXT)
	map_btn.custom_minimum_size = Vector2(48, 0)
	map_btn.pressed.connect(func(): go_to_map.emit())
	top.add_child(map_btn)
	_name_label = Ui.label("Continent", 18, Ui.C_GOLD)
	_name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	top.add_child(_name_label)
	_super_label = Ui.label("★ 0", 16, Ui.C_NEON)
	_super_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	top.add_child(_super_label)

	_cash_label = Ui.label("0", 32, Ui.C_TEXT)
	_cash_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(_cash_label)

	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 16)
	v.add_child(row)
	_rate_label = Ui.label("0/s", 15, Ui.C_GREEN)
	row.add_child(_rate_label)
	_prestige_btn = Ui.button("Prestige", Ui.C_GREEN)
	_prestige_btn.pressed.connect(func(): if Game.can_prestige(): Game.do_prestige())
	row.add_child(_prestige_btn)

func _build_banner() -> void:
	var svc := SubViewportContainer.new()
	svc.stretch = true
	svc.set_anchors_preset(Control.PRESET_TOP_WIDE)
	svc.offset_top = 156
	svc.offset_bottom = 392
	svc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(svc)
	var sv := SubViewport.new()
	sv.disable_3d = true
	svc.add_child(sv)
	sv.add_child(load("res://game/scenes/mine_view.gd").new())

func _build_buy_mode_bar() -> void:
	var h := HBoxContainer.new()
	h.set_anchors_preset(Control.PRESET_TOP_WIDE)
	h.offset_top = 400
	h.offset_bottom = 448
	h.offset_left = 12
	h.offset_right = -12
	h.add_theme_constant_override("separation", 8)
	add_child(h)
	var lbl := Ui.label("Acheter :", 14, Ui.C_DIM)
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	h.add_child(lbl)
	for opt in [[1, "×1"], [10, "×10"], [-1, "Max"]]:
		var b := Ui.button(opt[1], Ui.C_PANEL2, Ui.C_TEXT)
		b.custom_minimum_size = Vector2(0, 42)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var mode: int = opt[0]
		b.pressed.connect(func(): Game.set_buy_mode(mode))
		_buy_btns[mode] = b
		h.add_child(b)

func _build_stations_area() -> void:
	var scroll := ScrollContainer.new()
	scroll.set_anchors_preset(Control.PRESET_FULL_RECT)
	scroll.offset_top = 456
	scroll.offset_bottom = -92
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)
	var margin := MarginContainer.new()
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	margin.size_flags_vertical = Control.SIZE_EXPAND_FILL
	Ui.margins(margin, 12, 6)
	scroll.add_child(margin)
	_stations = VBoxContainer.new()
	_stations.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_stations.add_theme_constant_override("separation", 9)
	margin.add_child(_stations)

func _build_bottom_bar() -> void:
	var panel := Ui.panel(Ui.C_PANEL, 0, false)
	panel.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	panel.offset_top = -84
	add_child(panel)
	var h := HBoxContainer.new()
	h.alignment = BoxContainer.ALIGNMENT_CENTER
	h.add_theme_constant_override("separation", 10)
	panel.add_child(h)
	_boost_btn = Ui.button("Boost ×2 (pub)", Ui.C_NEON)
	_boost_btn.custom_minimum_size = Vector2(0, 56)
	_boost_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_boost_btn.pressed.connect(func(): Game.request_boost())
	h.add_child(_boost_btn)
	var skip := Ui.button("Time-skip (pub)", Ui.C_GOLD)
	skip.custom_minimum_size = Vector2(0, 56)
	skip.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	skip.pressed.connect(func(): Game.request_time_skip())
	h.add_child(skip)

# ============================ RECONSTRUCTION ============================

func _rebuild() -> void:
	if _stations == null:
		return
	for c in _stations.get_children():
		c.queue_free()
	_floor_rows.clear()
	_elev_row = {}
	_wh_row = {}
	var cont := Game.active()
	if cont == null:
		return

	_exped_btn = Ui.button("Expédition", Ui.C_NEON)
	_exped_btn.custom_minimum_size = Vector2(0, 48)
	_exped_btn.pressed.connect(_on_expedition)
	_stations.add_child(_exped_btn)

	_stations.add_child(Ui.section("ÉTAGES DE LA MINE"))
	for i in cont.mines.size():
		_floor_rows.append(_build_floor_row(i))

	_stations.add_child(Ui.section("LOGISTIQUE"))
	_elev_row = _build_component_row("Ascenseur", Game.Target.ELEVATOR,
		func(): return Game.upgrade_elevator(), func(): Game.tap_elevator())
	_wh_row = _build_component_row("Entrepôt", Game.Target.WAREHOUSE,
		func(): return Game.upgrade_warehouse(), func(): Game.tap_warehouse())

func _build_floor_row(i: int) -> Dictionary:
	var panel := Ui.panel(Ui.C_PANEL2)
	_stations.add_child(panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	panel.add_child(v)

	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 10)
	v.add_child(top)
	var name_lbl := Ui.label("Étage", 17, Ui.C_GOLD)
	name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(name_lbl)
	var lvl_lbl := Ui.label("Nv 0", 13, Ui.C_DIM)
	top.add_child(lvl_lbl)

	var out_lbl := Ui.label("", 12, Ui.C_TEXT)
	v.add_child(out_lbl)
	var bar := Ui.bar()
	v.add_child(bar)

	var btns := HBoxContainer.new()
	btns.add_theme_constant_override("separation", 8)
	v.add_child(btns)
	var tap := Ui.button("EXTRAIRE", Ui.C_GOLD)
	tap.custom_minimum_size = Vector2(0, 50)
	tap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tap.pressed.connect(func(): Game.tap_mine(i))
	btns.add_child(tap)
	var up := Ui.button("Améliorer", Ui.C_NEON)
	up.custom_minimum_size = Vector2(0, 50)
	up.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	up.pressed.connect(func(): Game.upgrade_or_unlock_mine(i))
	btns.add_child(up)
	var mgr := Ui.button("Manager", Ui.C_GREEN)
	mgr.custom_minimum_size = Vector2(0, 50)
	mgr.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mgr.pressed.connect(func(): Game.hire_manager(Game.Target.MINE, i))
	btns.add_child(mgr)

	return {"i": i, "name": name_lbl, "level": lvl_lbl, "out": out_lbl, "bar": bar, "tap": tap, "up": up, "mgr": mgr}

func _build_component_row(title: String, target, upgrade_cb: Callable, tap_cb: Callable) -> Dictionary:
	var panel := Ui.panel(Ui.C_PANEL2)
	_stations.add_child(panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	panel.add_child(v)
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 10)
	v.add_child(top)
	var name_lbl := Ui.label(title, 17, Ui.C_GOLD)
	name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(name_lbl)
	var lvl_lbl := Ui.label("Nv 1", 13, Ui.C_DIM)
	top.add_child(lvl_lbl)
	var info_lbl := Ui.label("", 12, Ui.C_TEXT)
	v.add_child(info_lbl)
	var bar := Ui.bar(Ui.C_GREEN)
	v.add_child(bar)
	var btns := HBoxContainer.new()
	btns.add_theme_constant_override("separation", 8)
	v.add_child(btns)
	var tap := Ui.button("ACTIONNER", Ui.C_GOLD)
	tap.custom_minimum_size = Vector2(0, 50)
	tap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tap.pressed.connect(func(): tap_cb.call())
	btns.add_child(tap)
	var up := Ui.button("Améliorer", Ui.C_NEON)
	up.custom_minimum_size = Vector2(0, 50)
	up.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	up.pressed.connect(func(): upgrade_cb.call())
	btns.add_child(up)
	var mgr := Ui.button("Manager", Ui.C_GREEN)
	mgr.custom_minimum_size = Vector2(0, 50)
	mgr.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mgr.pressed.connect(func(): Game.hire_manager(target, 0))
	btns.add_child(mgr)
	return {"target": target, "name": name_lbl, "level": lvl_lbl, "info": info_lbl, "bar": bar, "tap": tap, "up": up, "mgr": mgr}

# ============================ RAFRAÎCHISSEMENT ============================

func _refresh_hud() -> void:
	var cont := Game.active()
	if cont != null:
		_name_label.text = cont.name
	_cash_label.text = NumberFormat.format(Game.cash())
	_rate_label.text = NumberFormat.format(Game.cash_per_sec()) + "/s"
	_super_label.text = "★ " + NumberFormat.format(Game.super_cash())
	if Game.boost_active():
		_boost_btn.text = "Boost actif " + NumberFormat.format_duration(Game.state.boost_end_unix - Game.now())
	else:
		_boost_btn.text = "Boost ×2 (pub)"
	var pg := Game.prestige_gain_preview()
	_prestige_btn.disabled = pg < 1
	_prestige_btn.text = ("Prestige +%d ★" % pg) if pg >= 1 else "Prestige"

func _refresh_buy_mode() -> void:
	if Game.buy_mode == _last_buy_mode:
		return
	_last_buy_mode = Game.buy_mode
	for mode in _buy_btns:
		var active: bool = (mode == Game.buy_mode)
		Ui.recolor(_buy_btns[mode], Ui.C_GOLD if active else Ui.C_PANEL2, Ui.C_BG if active else Ui.C_TEXT)

func _refresh_rows() -> void:
	var cont := Game.active()
	if cont == null:
		return
	var cash := Game.cash()
	for r in _floor_rows:
		var m: Mine = cont.mines[r.i]
		r.name.text = "Étage %d — %s" % [m.id + 1, m.ore_name]
		r.level.text = "Nv %d" % m.level
		if m.is_unlocked():
			r.out.text = "%s u/s  •  prix %s" % [NumberFormat.format(Economy.mine_output_per_sec(m)), NumberFormat.format(m.unit_price)]
			r.bar.value = (m.buffer / m.buffer_cap) if m.buffer_cap > 0 else 0.0
			r.tap.visible = not m.has_manager
			_set_upgrade_button(r.up, "Améliorer", Game.planned_mine(r.i), cash)
			_update_manager_button(r.mgr, Game.Target.MINE, r.i, m)
		else:
			r.out.text = "Verrouillé"
			r.bar.value = 0.0
			r.tap.visible = false
			_set_upgrade_button(r.up, "Débloquer", Game.planned_mine(r.i), cash)
			r.mgr.visible = false

	if not _elev_row.is_empty():
		var e := cont.elevator
		_elev_row.level.text = "Nv %d" % e.level
		_elev_row.info.text = "%s u/s" % NumberFormat.format(Economy.elevator_throughput(e))
		_elev_row.bar.value = 0.5
		_elev_row.tap.visible = not e.has_manager
		_set_upgrade_button(_elev_row.up, "Améliorer", Game.planned_elevator(), cash)
		_update_manager_button(_elev_row.mgr, Game.Target.ELEVATOR, 0, e)
	if not _wh_row.is_empty():
		var w := cont.warehouse
		var cap := Economy.warehouse_store_cap(w)
		_wh_row.level.text = "Nv %d" % w.level
		_wh_row.info.text = "%s / %s  •  %s u/s" % [NumberFormat.format(w.stock), NumberFormat.format(cap), NumberFormat.format(Economy.warehouse_sell_rate(w))]
		_wh_row.bar.value = (w.stock / cap) if cap > 0 else 0.0
		_wh_row.tap.visible = not w.has_manager
		_set_upgrade_button(_wh_row.up, "Améliorer", Game.planned_warehouse(), cash)
		_update_manager_button(_wh_row.mgr, Game.Target.WAREHOUSE, 0, w)

func _set_upgrade_button(btn: Button, prefix: String, plan: Dictionary, cash: float) -> void:
	var count: int = plan.count
	var cost: float = plan.cost
	if count <= 0:
		btn.text = "%s\n—" % prefix
		btn.disabled = true
		return
	var suffix := (" ×%d" % count) if count > 1 else ""
	btn.text = "%s%s\n%s" % [prefix, suffix, NumberFormat.format(cost)]
	btn.disabled = cash < cost

func _update_manager_button(btn: Button, target, i: int, comp) -> void:
	btn.visible = true
	if comp.has_manager:
		btn.disabled = true
		btn.text = "✓ Auto"
	elif comp.level < Game.config.manager_unlock_level:
		btn.disabled = true
		btn.text = "Manager Nv%d" % Game.config.manager_unlock_level
	else:
		var cost := Game.manager_cost(target, i)
		btn.disabled = Game.cash() < cost
		btn.text = "Manager\n%s" % NumberFormat.format(cost)

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
		"idle": Game.start_expedition()
		"ready": Game.collect_expedition()

func _animate_cash_pop(delta: float) -> void:
	var cash := Game.cash()
	if cash > _hud_cash + 0.0001:
		_cash_pop = 1.16
	_hud_cash = cash
	_cash_pop = lerpf(_cash_pop, 1.0, clampf(delta * 9.0, 0.0, 1.0))
	_cash_label.pivot_offset = _cash_label.size * 0.5
	_cash_label.scale = Vector2(_cash_pop, _cash_pop)
