## Formules économiques : PURES et STATIQUES (aucune dépendance moteur/UI) -> 100% testables.
## Toute la maths du jeu vit ici. Réf : docs/PRD.md §5, docs/specs/*.
class_name Economy
extends RefCounted

# --- Mines ---

## Débit d'extraction en unités/s (0 si verrouillée). bonus_mult = bonus manager.
static func mine_output_per_sec(mine: Mine) -> float:
	if mine == null or mine.level <= 0:
		return 0.0
	return mine.base_output * pow(mine.prod_growth, mine.level - 1) * maxf(mine.bonus_mult, 0.0)

## Coût du prochain niveau (ou du déblocage si level 0). cost = base * growth^level.
static func mine_upgrade_cost(mine: Mine) -> float:
	return mine.base_cost * pow(mine.cost_growth, mine.level)

# --- Ascenseur ---

static func elevator_capacity(e: Elevator) -> float:
	return e.base_capacity * pow(e.capacity_growth, e.level - 1) * maxf(e.bonus_mult, 0.0)

## Temps par voyage (plancher min_speed pour éviter division par ~0).
static func elevator_trip_time(e: Elevator) -> float:
	return maxf(e.base_speed * pow(e.speed_growth, e.level - 1), e.min_speed)

## Débit de transport en unités/s.
static func elevator_throughput(e: Elevator) -> float:
	var t := elevator_trip_time(e)
	if t <= 0.0:
		return 0.0
	return elevator_capacity(e) / t

static func elevator_upgrade_cost(e: Elevator) -> float:
	return e.base_cost * pow(e.cost_growth, e.level)

# --- Entrepôt ---

static func warehouse_store_cap(w: Warehouse) -> float:
	return w.base_store_cap * pow(w.store_cap_growth, w.level - 1)

## Débit de vente en unités/s.
static func warehouse_sell_rate(w: Warehouse) -> float:
	return w.base_sell_rate * pow(w.sell_rate_growth, w.level - 1) * maxf(w.bonus_mult, 0.0)

static func warehouse_upgrade_cost(w: Warehouse) -> float:
	return w.base_cost * pow(w.cost_growth, w.level)

# --- Achat en lot (x10 / Max) : somme géométrique des coûts ---

## Coût pour acheter `count` niveaux consécutifs à partir de `level`.
static func bulk_upgrade_cost(base_cost: float, cost_growth: float, level: int, count: int) -> float:
	if count <= 0:
		return 0.0
	if absf(cost_growth - 1.0) < 0.0000001:
		return base_cost * count
	var first := base_cost * pow(cost_growth, level)
	return first * (pow(cost_growth, count) - 1.0) / (cost_growth - 1.0)

## Nombre max de niveaux achetables avec `budget` à partir de `level` (>= 0).
static func max_levels_affordable(base_cost: float, cost_growth: float, level: int, budget: float) -> int:
	if budget <= 0.0 or base_cost <= 0.0:
		return 0
	if absf(cost_growth - 1.0) < 0.0000001:
		return int(floor(budget / base_cost))
	var first := base_cost * pow(cost_growth, level)
	var ratio := 1.0 + budget * (cost_growth - 1.0) / first
	if ratio <= 1.0:
		return 0
	return int(floor(log(ratio) / log(cost_growth)))

# --- Multiplicateurs globaux (appliqués au CASH, pas aux unités) ---

static func is_boost_active(state: GameState, now: float) -> bool:
	return now < state.boost_end_unix

## Multiplicateur de cash = prestige permanent x bonus vente x IAP x2 x boost actif.
static func cash_multiplier(state: GameState, cont: Continent, now: float) -> float:
	var m := maxf(cont.mult_permanent, 0.0)
	m *= maxf(state.global_sell_mult, 0.0)
	if state.perm_x2:
		m *= 2.0
	if is_boost_active(state, now):
		m *= maxf(state.boost_factor, 1.0)
	return m

# --- Pipeline / bottleneck ---

## Débit du pipeline en unités/s = min des trois maillons (LE bottleneck).
## only_automated=true : ne compte que les composants avec manager (base du calcul offline).
static func pipeline_units_per_sec(cont: Continent, only_automated: bool) -> float:
	var mines_rate := 0.0
	for mine in cont.mines:
		if mine.level > 0 and (not only_automated or mine.has_manager):
			mines_rate += mine_output_per_sec(mine)
	var elev_rate := 0.0
	if not only_automated or cont.elevator.has_manager:
		elev_rate = elevator_throughput(cont.elevator)
	var wh_rate := 0.0
	if not only_automated or cont.warehouse.has_manager:
		wh_rate = warehouse_sell_rate(cont.warehouse)
	return minf(mines_rate, minf(elev_rate, wh_rate))

## Prix unitaire moyen pondéré par le débit des mines actives (pour estimer le cash/s).
static func avg_unit_price(cont: Continent, only_automated: bool) -> float:
	var num := 0.0
	var den := 0.0
	for mine in cont.mines:
		if mine.level > 0 and (not only_automated or mine.has_manager):
			var r := mine_output_per_sec(mine)
			num += r * mine.unit_price
			den += r
	return num / den if den > 0.0 else 0.0

## Cash/seconde effectif (pipeline automatisé x prix moyen x multiplicateurs).
static func cash_per_sec(state: GameState, cont: Continent, now: float) -> float:
	var units := pipeline_units_per_sec(cont, true)
	return units * avg_unit_price(cont, true) * cash_multiplier(state, cont, now)

# --- Prestige ---

## Super-cash gagné (courbe racine ; 0 sous le seuil).
static func prestige_super_cash_gain(cash_total: float, threshold: float, k: float) -> int:
	if threshold <= 0.0 or cash_total < threshold:
		return 0
	return int(floor(k * sqrt(cash_total / threshold)))

## Gain de multiplicateur permanent pour un montant de super-cash gagné.
static func prestige_mult_gain(super_cash_gain: int, mult_per_super_cash: float) -> float:
	return maxf(super_cash_gain, 0) * maxf(mult_per_super_cash, 0.0)

# --- Managers ---

## Coût d'embauche d'un manager = facteur x coût d'upgrade courant du composant.
static func manager_hire_cost(current_upgrade_cost: float, cost_factor: float) -> float:
	return current_upgrade_cost * maxf(cost_factor, 0.0)

# --- Expéditions ---

## Récompense cash d'une expédition = X minutes de production au taux courant.
static func expedition_reward(cash_per_sec: float, minutes: float) -> float:
	return maxf(cash_per_sec, 0.0) * maxf(minutes, 0.0) * 60.0
