## Scène 2D animée du pipeline (esprit SpriteKit) : puits empilés, ascenseur + wagonnet animé,
## lueur d'extraction, wagonnet qui monte/descend selon le débit, particules de pièces à la vente.
## Dessinée par code (_draw) -> aucun asset requis. Lit l'état via l'autoload Game.
## Réf : docs/PRD.md §6, docs/specs/*.
extends Node2D

const C_SKY := Color("241b13")
const C_EARTH := Color("1b140d")
const C_STRATA := Color("2a2016")
const C_SHAFT := Color("100b07")
const C_RAIL := Color("3a2c1c")
const C_CART := Color("c9762f")
const C_CART_ORE := Color("ffd35c")
const C_GOLD := Color("f5b942")
const C_NEON := Color("ffd35c")
const C_TEXT := Color("f0e6d2")
const C_DIM := Color("6b5c48")
const C_LOCK := Color("0d0906")
const C_WAREHOUSE := Color("6b4a2a")
const C_ROOF := Color("f5b942")

var _t := 0.0
var _vsize := Vector2(720, 480)
var _last_cash := 0.0
var _sell_glow := 0.0
var _coins: CPUParticles2D
var _font: Font

const SHAFT_W := 96.0
const TOP_H := 96.0   # hauteur de la zone entrepôt (surface)

func _ready() -> void:
	_font = ThemeDB.fallback_font
	_coins = CPUParticles2D.new()
	_coins.amount = 24
	_coins.lifetime = 0.9
	_coins.one_shot = false
	_coins.emitting = false
	_coins.explosiveness = 0.15
	_coins.direction = Vector2(0, -1)
	_coins.spread = 55.0
	_coins.initial_velocity_min = 90.0
	_coins.initial_velocity_max = 170.0
	_coins.gravity = Vector2(0, 320)
	_coins.scale_amount_min = 2.0
	_coins.scale_amount_max = 4.0
	_coins.color = C_GOLD
	add_child(_coins)

func _process(delta: float) -> void:
	_t += delta
	_vsize = get_viewport().get_visible_rect().size

	# Détecte une vente (cash en hausse) -> lueur + particules de pièces.
	var cash := Game.cash()
	if cash > _last_cash + 0.0001:
		_sell_glow = 1.0
	_last_cash = cash
	_sell_glow = maxf(_sell_glow - delta * 2.5, 0.0)

	var warehouse_pos := Vector2(SHAFT_W * 0.5, TOP_H * 0.5)
	_coins.position = warehouse_pos
	_coins.emitting = _sell_glow > 0.05

	queue_redraw()

func _draw() -> void:
	var w := _vsize.x
	var h := _vsize.y
	if w <= 0 or h <= 0:
		return

	# Fond : surface + terre stratifiée.
	draw_rect(Rect2(0, 0, w, TOP_H), C_SKY, true)
	draw_rect(Rect2(0, TOP_H, w, h - TOP_H), C_EARTH, true)
	var strata_step := 46.0
	var y := TOP_H + strata_step
	while y < h:
		draw_line(Vector2(0, y), Vector2(w, y), C_STRATA, 2.0)
		y += strata_step

	_draw_warehouse()
	_draw_shaft(h)

	var cont: Continent = Game.active()
	if cont == null:
		return
	_draw_mines(cont, w, h)
	_draw_cart(cont, h)

func _draw_warehouse() -> void:
	# Bâtiment entrepôt en surface, au-dessus du puits.
	var bx := 6.0
	var bw := SHAFT_W - 12.0
	var by := 20.0
	var bh := TOP_H - 26.0
	draw_rect(Rect2(bx, by, bw, bh), C_WAREHOUSE, true)
	# Toit.
	var roof := PackedVector2Array([
		Vector2(bx - 6, by), Vector2(bx + bw + 6, by), Vector2(bx + bw * 0.5, by - 16)])
	draw_colored_polygon(roof, C_ROOF)
	# Lueur de vente.
	if _sell_glow > 0.05:
		draw_rect(Rect2(bx, by, bw, bh), Color(C_NEON.r, C_NEON.g, C_NEON.b, 0.35 * _sell_glow), true)

func _draw_shaft(h: float) -> void:
	draw_rect(Rect2(0, TOP_H, SHAFT_W, h - TOP_H), C_SHAFT, true)
	# Rails.
	draw_line(Vector2(SHAFT_W * 0.5 - 18, TOP_H), Vector2(SHAFT_W * 0.5 - 18, h), C_RAIL, 3.0)
	draw_line(Vector2(SHAFT_W * 0.5 + 18, TOP_H), Vector2(SHAFT_W * 0.5 + 18, h), C_RAIL, 3.0)

func _draw_mines(cont: Continent, w: float, h: float) -> void:
	var n := cont.mines.size()
	if n == 0:
		return
	var area_top := TOP_H
	var area_h := h - TOP_H
	var row_h := area_h / float(n)
	var gx := SHAFT_W + 8.0
	var gw := w - gx - 10.0

	for i in n:
		var m: Mine = cont.mines[i]
		var ry := area_top + i * row_h
		var pad := 6.0
		var inner := Rect2(gx, ry + pad, gw, row_h - pad * 2)

		if not m.is_unlocked():
			draw_rect(inner, C_LOCK, true)
			_draw_text_centered("VERROUILLÉ", Vector2(inner.position.x + inner.size.x * 0.5, inner.position.y + inner.size.y * 0.5), 15, C_DIM)
			continue

		# Galerie.
		draw_rect(inner, C_STRATA, true)

		# Lueur d'extraction (pulsée) si automatisée ou production active.
		var pulse := (sin(_t * 4.0 + i) * 0.5 + 0.5)
		var glow_a := (0.5 if m.has_manager else 0.25) * pulse
		draw_rect(Rect2(inner.position.x, inner.position.y, 26, inner.size.y),
			Color(C_NEON.r, C_NEON.g, C_NEON.b, glow_a), true)

		# Barre de buffer (remplissage).
		var frac := clampf(m.buffer / m.buffer_cap, 0.0, 1.0) if m.buffer_cap > 0 else 0.0
		var bar_y := inner.position.y + inner.size.y - 12
		draw_rect(Rect2(inner.position.x + 6, bar_y, inner.size.x - 12, 6), C_SHAFT, true)
		draw_rect(Rect2(inner.position.x + 6, bar_y, (inner.size.x - 12) * frac, 6), C_GOLD, true)

		# Libellé.
		_draw_text("%s  Nv%d" % [m.ore_name, m.level],
			Vector2(inner.position.x + 34, inner.position.y + 22), 16, C_TEXT)
		if m.has_manager:
			_draw_text("AUTO", Vector2(inner.position.x + inner.size.x - 52, inner.position.y + 20), 12, C_NEON)

func _draw_cart(cont: Continent, h: float) -> void:
	# Wagonnet : oscille entre l'entrepôt (haut) et la mine active la plus profonde.
	var deepest := TOP_H + 40.0
	for i in cont.mines.size():
		if cont.mines[i].is_unlocked():
			var area_h := h - TOP_H
			var row_h := area_h / float(cont.mines.size())
			deepest = TOP_H + (i + 0.5) * row_h
	var speed := 1.0
	if cont.elevator != null:
		var tt := Economy.elevator_trip_time(cont.elevator)
		speed = clampf(1.0 / maxf(tt, 0.2), 0.3, 3.0)
	var phase := (sin(_t * speed) * 0.5 + 0.5)
	var cy := lerpf(TOP_H * 0.6, deepest, phase)
	var cx := SHAFT_W * 0.5

	# Wagonnet.
	draw_rect(Rect2(cx - 16, cy - 12, 32, 22), C_CART, true)
	# Minerai dans le wagon (proportionnel au stock si automatisé).
	var loaded := 0.6
	draw_rect(Rect2(cx - 12, cy - 8, 24 * loaded, 8), C_CART_ORE, true)
	# Roues.
	draw_circle(Vector2(cx - 9, cy + 12), 4.0, C_RAIL)
	draw_circle(Vector2(cx + 9, cy + 12), 4.0, C_RAIL)

func _draw_text(text: String, pos: Vector2, size: int, color: Color) -> void:
	if _font == null:
		return
	draw_string(_font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)

func _draw_text_centered(text: String, center: Vector2, size: int, color: Color) -> void:
	if _font == null:
		return
	var tw := _font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	draw_string(_font, Vector2(center.x - tw * 0.5, center.y + size * 0.35), text,
		HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)
