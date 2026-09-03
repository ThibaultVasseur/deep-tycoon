## Bannière 2D animée du continent actif (esprit SpriteKit) : entrepôt + pièces, puits d'ascenseur
## avec wagonnet animé, jauge de profondeur (1 pastille par étage). Dessinée par code (_draw).
## Réf : docs/PRD.md §6.
extends Node2D

const C_SKY := Color("2a2016")
const C_EARTH := Color("1b140d")
const C_STRATA := Color("241a10")
const C_SHAFT := Color("0d0906")
const C_RAIL := Color("3a2c1c")
const C_CART := Color("c9762f")
const C_CART_ORE := Color("ffd35c")
const C_GOLD := Color("f5b942")
const C_NEON := Color("ffd35c")
const C_TEXT := Color("f0e6d2")
const C_DIM := Color("4a3c2c")
const C_WAREHOUSE := Color("6b4a2a")
const C_ROOF := Color("f5b942")

var _t := 0.0
var _vsize := Vector2(720, 240)
var _last_cash := 0.0
var _sell_glow := 0.0
var _coins: CPUParticles2D
var _font: Font

const SHAFT_W := 88.0
const TOP_H := 74.0

func _ready() -> void:
	_font = ThemeDB.fallback_font
	_coins = CPUParticles2D.new()
	_coins.amount = 22
	_coins.lifetime = 0.85
	_coins.one_shot = false
	_coins.emitting = false
	_coins.explosiveness = 0.1
	_coins.direction = Vector2(0.3, -1)
	_coins.spread = 50.0
	_coins.initial_velocity_min = 80.0
	_coins.initial_velocity_max = 160.0
	_coins.gravity = Vector2(0, 340)
	_coins.scale_amount_min = 2.0
	_coins.scale_amount_max = 3.5
	_coins.color = C_GOLD
	add_child(_coins)

func _process(delta: float) -> void:
	_t += delta
	_vsize = get_viewport().get_visible_rect().size
	var cash := Game.cash()
	if cash > _last_cash + 0.0001:
		_sell_glow = 1.0
	_last_cash = cash
	_sell_glow = maxf(_sell_glow - delta * 2.5, 0.0)
	_coins.position = Vector2(SHAFT_W * 0.5, TOP_H * 0.55)
	_coins.emitting = _sell_glow > 0.05
	queue_redraw()

func _draw() -> void:
	var w := _vsize.x
	var h := _vsize.y
	if w <= 0 or h <= 0:
		return
	var cont: Continent = Game.active()
	var tint := Content.continent_tint(cont.id) if cont != null else C_GOLD

	# Fond terre stratifiée.
	draw_rect(Rect2(0, 0, w, TOP_H), C_SKY, true)
	draw_rect(Rect2(0, TOP_H, w, h - TOP_H), C_EARTH, true)
	var y := TOP_H + 34.0
	while y < h:
		draw_line(Vector2(0, y), Vector2(w, y), C_STRATA, 2.0)
		y += 34.0

	_draw_warehouse()
	_draw_shaft(h)
	if cont != null:
		_draw_depth_gauge(cont, w, h, tint)
		_draw_cart(cont, h)
		_draw_title(cont, w, tint)

func _draw_warehouse() -> void:
	var bx := 6.0
	var bw := SHAFT_W - 12.0
	var by := 16.0
	var bh := TOP_H - 22.0
	draw_rect(Rect2(bx, by, bw, bh), C_WAREHOUSE, true)
	var roof := PackedVector2Array([Vector2(bx - 6, by), Vector2(bx + bw + 6, by), Vector2(bx + bw * 0.5, by - 14)])
	draw_colored_polygon(roof, C_ROOF)
	if _sell_glow > 0.05:
		draw_rect(Rect2(bx, by, bw, bh), Color(C_NEON.r, C_NEON.g, C_NEON.b, 0.4 * _sell_glow), true)

func _draw_shaft(h: float) -> void:
	draw_rect(Rect2(0, TOP_H, SHAFT_W, h - TOP_H), C_SHAFT, true)
	draw_line(Vector2(SHAFT_W * 0.5 - 16, TOP_H), Vector2(SHAFT_W * 0.5 - 16, h), C_RAIL, 3.0)
	draw_line(Vector2(SHAFT_W * 0.5 + 16, TOP_H), Vector2(SHAFT_W * 0.5 + 16, h), C_RAIL, 3.0)

func _draw_depth_gauge(cont: Continent, w: float, h: float, tint: Color) -> void:
	# Une pastille par étage : allumée si débloqué (vive si automatisé), sombre si verrouillé.
	var n := cont.mines.size()
	if n == 0:
		return
	var gx := SHAFT_W + 34.0
	var top := TOP_H + 26.0
	var gap := (h - top - 14.0) / float(n)
	var pulse := sin(_t * 3.0) * 0.5 + 0.5
	for i in n:
		var m: Mine = cont.mines[i]
		var cy := top + i * gap
		# Rail latéral.
		if i < n - 1:
			draw_line(Vector2(gx, cy), Vector2(gx, cy + gap), C_STRATA, 2.0)
		var r := 6.0
		if m.is_unlocked():
			var col := tint if m.has_manager else tint.darkened(0.25)
			if m.has_manager:
				draw_circle(Vector2(gx, cy), r + 3.0 + pulse * 2.0, Color(tint.r, tint.g, tint.b, 0.22))
			draw_circle(Vector2(gx, cy), r, col)
			# Mini-jauge de buffer à droite de la pastille (largeur selon la place dispo).
			var frac := clampf(m.buffer / m.buffer_cap, 0.0, 1.0) if m.buffer_cap > 0 else 0.0
			var bw: float = maxf(w - gx - 26.0, 20.0)
			draw_rect(Rect2(gx + 14, cy - 2.5, bw, 5), C_SHAFT, true)
			draw_rect(Rect2(gx + 14, cy - 2.5, bw * frac, 5), C_GOLD, true)
		else:
			draw_circle(Vector2(gx, cy), r - 1.0, C_DIM)

func _draw_cart(cont: Continent, h: float) -> void:
	var deepest := TOP_H + 30.0
	var n := cont.mines.size()
	for i in n:
		if cont.mines[i].is_unlocked():
			deepest = TOP_H + 26.0 + i * ((h - TOP_H - 40.0) / float(n))
	var speed := 1.0
	if cont.elevator != null:
		speed = clampf(1.0 / maxf(Economy.elevator_trip_time(cont.elevator), 0.2), 0.3, 3.0)
	var cy := lerpf(TOP_H * 0.7, deepest, sin(_t * speed) * 0.5 + 0.5)
	var cx := SHAFT_W * 0.5
	draw_rect(Rect2(cx - 15, cy - 11, 30, 20), C_CART, true)
	draw_rect(Rect2(cx - 11, cy - 7, 20, 7), C_CART_ORE, true)
	draw_circle(Vector2(cx - 8, cy + 10), 3.5, C_RAIL)
	draw_circle(Vector2(cx + 8, cy + 10), 3.5, C_RAIL)

func _draw_title(cont: Continent, w: float, tint: Color) -> void:
	var unlocked := 0
	for m in cont.mines:
		if m.is_unlocked():
			unlocked += 1
	_draw_text(cont.name, Vector2(SHAFT_W + 34, TOP_H - 30), 18, tint)
	_draw_text("%d / %d étages" % [unlocked, cont.mines.size()], Vector2(SHAFT_W + 34, TOP_H - 12), 12, C_TEXT)

func _draw_text(text: String, pos: Vector2, size: int, color: Color) -> void:
	if _font != null:
		draw_string(_font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)
