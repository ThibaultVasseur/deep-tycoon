## Moteur de tick : fait avancer le pipeline mine -> ascenseur -> entrepôt -> cash.
## PUR (mute l'état passé en argument, aucune dépendance moteur) -> testable en headless.
## Réf : docs/specs/{mine-production,elevator-transport,warehouse-conversion}.md.
class_name ProductionEngine
extends RefCounted

const EPS := 0.0000001

## Avance la simulation de `delta` secondes sur le continent actif.
## `now` = timestamp courant (pour les boosts). Retourne un résumé pour l'UI :
##   { cash_gained, units_sold, upstream_bottleneck, downstream_bottleneck }
## Seuls les composants automatisés (has_manager) progressent ici ; les taps manuels
## sont gérés par le game_controller via manual_* .
static func tick(state: GameState, delta: float, now: float) -> Dictionary:
	var result := {
		"cash_gained": 0.0,
		"units_sold": 0.0,
		"upstream_bottleneck": false,
		"downstream_bottleneck": false,
	}
	if state == null or delta <= 0.0:
		return result
	var cont: Continent = state.active()
	if cont == null or cont.elevator == null or cont.warehouse == null:
		return result

	# 1) Mines automatisées -> buffers.
	for mine in cont.mines:
		if mine.level > 0 and mine.has_manager:
			var add := Economy.mine_output_per_sec(mine) * delta
			var space := mine.buffer_cap - mine.buffer
			if add >= space - EPS:
				add = maxf(space, 0.0)
				result.upstream_bottleneck = true  # mine pleine : ascenseur trop lent en aval
			mine.buffer += add

	# 2) Ascenseur automatisé -> entrepôt (priorité aux mines de plus grande valeur).
	var e: Elevator = cont.elevator
	var w: Warehouse = cont.warehouse
	if e.has_manager:
		var move_cap := Economy.elevator_throughput(e) * delta
		var free_space := maxf(Economy.warehouse_store_cap(w) - w.stock, 0.0)
		var total_buffer := 0.0
		for mine in cont.mines:
			total_buffer += mine.buffer

		if free_space <= EPS and total_buffer > EPS:
			result.downstream_bottleneck = true  # entrepôt plein : vente trop lente
		elif move_cap < total_buffer - EPS:
			result.upstream_bottleneck = true    # ascenseur incapable d'écouler les buffers

		var movable := minf(move_cap, minf(total_buffer, free_space))
		if movable > EPS:
			var order := cont.mines.duplicate()
			order.sort_custom(func(a, b): return a.unit_price > b.unit_price)
			var remaining := movable
			for mine in order:
				if remaining <= EPS:
					break
				var take := minf(mine.buffer, remaining)
				if take > 0.0:
					mine.buffer -= take
					w.stock += take
					w.stock_value += take * mine.unit_price
					remaining -= take

	# 3) Entrepôt automatisé -> cash.
	if w.has_manager and w.stock > EPS:
		var sold := minf(w.stock, Economy.warehouse_sell_rate(w) * delta)
		if sold > 0.0:
			var avg := w.avg_price()
			var frac := sold / w.stock
			var earned := sold * avg * Economy.cash_multiplier(state, cont, now)
			w.stock -= sold
			w.stock_value = maxf(w.stock_value - w.stock_value * frac, 0.0)
			cont.cash += earned
			cont.cash_total_earned += earned
			result.cash_gained = earned
			result.units_sold = sold

	return result

# --- Actions manuelles (avant l'automatisation par managers) ---

## Tap sur une mine : ajoute ~`seconds_worth` secondes de production au buffer.
static func manual_mine_tap(mine: Mine, seconds_worth: float = 1.0) -> void:
	if mine == null or mine.level <= 0:
		return
	var add := Economy.mine_output_per_sec(mine) * maxf(seconds_worth, 0.0)
	mine.buffer = minf(mine.buffer + add, mine.buffer_cap)

## Tap sur l'ascenseur : un voyage manuel (déplace jusqu'à `capacity` vers l'entrepôt).
static func manual_elevator_trip(cont: Continent) -> float:
	if cont == null or cont.elevator == null or cont.warehouse == null:
		return 0.0
	var e := cont.elevator
	var w := cont.warehouse
	var cap := Economy.elevator_capacity(e)
	var free_space := maxf(Economy.warehouse_store_cap(w) - w.stock, 0.0)
	var total_buffer := 0.0
	for mine in cont.mines:
		total_buffer += mine.buffer
	var movable := minf(cap, minf(total_buffer, free_space))
	if movable <= EPS:
		return 0.0
	var order := cont.mines.duplicate()
	order.sort_custom(func(a, b): return a.unit_price > b.unit_price)
	var remaining := movable
	for mine in order:
		if remaining <= EPS:
			break
		var take := minf(mine.buffer, remaining)
		if take > 0.0:
			mine.buffer -= take
			w.stock += take
			w.stock_value += take * mine.unit_price
			remaining -= take
	return movable

## Tap sur l'entrepôt : vend jusqu'à `capacity`-worth du stock, retourne le cash gagné.
static func manual_warehouse_sell(state: GameState, cont: Continent, now: float, units: float = -1.0) -> float:
	if cont == null or cont.warehouse == null:
		return 0.0
	var w := cont.warehouse
	if w.stock <= EPS:
		return 0.0
	var to_sell := w.stock if units < 0.0 else minf(units, w.stock)
	var avg := w.avg_price()
	var frac := to_sell / w.stock
	var earned := to_sell * avg * Economy.cash_multiplier(state, cont, now)
	w.stock -= to_sell
	w.stock_value = maxf(w.stock_value - w.stock_value * frac, 0.0)
	cont.cash += earned
	cont.cash_total_earned += earned
	return earned
