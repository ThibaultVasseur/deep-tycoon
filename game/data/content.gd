## Contenu de jeu (seed des continents et de leurs étages). Séparé de la logique -> équilibrage facile.
## Chaque continent = économie fraîche à monnaie locale, avec N étages de plus en plus profonds/chers.
## Débloqué au super-cash. Réf : PRD §3.7, §12.
class_name Content
extends RefCounted

# Métadonnées des continents. `unlock_super_cash` = coût de déblocage (monnaie mondiale).
# `tint` = teinte visuelle du continent (thème). `ore` = ressource extraite.
const CONTINENTS := [
	{"name": "Charbonnage", "ore": "Charbon", "unlock_super_cash": 0, "tint": "8a8f98", "icon": "⛏"},
	{"name": "Caverne de Cristal", "ore": "Cristal", "unlock_super_cash": 60, "tint": "5fd0e6", "icon": "💎"},
	{"name": "Puits de Magma", "ore": "Magma", "unlock_super_cash": 900, "tint": "ff6b3d", "icon": "🌋"},
	{"name": "Cité d'Or", "ore": "Or", "unlock_super_cash": 12000, "tint": "f5c542", "icon": "🏆"},
]

static func continent_icon(id: int) -> String:
	if id < 0 or id >= CONTINENTS.size():
		return "?"
	return CONTINENTS[id].icon

static func continent_count() -> int:
	return CONTINENTS.size()

static func continent_unlock_cost(id: int) -> int:
	if id < 0 or id >= CONTINENTS.size():
		return 0
	return int(CONTINENTS[id].unlock_super_cash)

static func continent_tint(id: int) -> Color:
	if id < 0 or id >= CONTINENTS.size():
		return Color.WHITE
	return Color(CONTINENTS[id].tint)

static func continent_name(id: int) -> String:
	if id < 0 or id >= CONTINENTS.size():
		return "?"
	return CONTINENTS[id].name

## Construit un continent par son id, avec `floors_per_continent` étages de plus en plus chers.
static func build_continent(id: int, cfg: BalanceConfig) -> Continent:
	id = clampi(id, 0, CONTINENTS.size() - 1)
	var meta: Dictionary = CONTINENTS[id]
	var ore: String = meta.ore

	var c := Continent.new()
	c.id = id
	c.name = meta.name
	c.unlocked = (id == 0)
	c.mult_permanent = 1.0
	c.cash = (25.0 if id == 0 else 0.0)
	c.mines = []

	var floors: int = maxi(cfg.floors_per_continent, 1)
	for i in range(floors):
		var m := Mine.new()
		m.id = i                                   # numéro d'étage (0 = surface)
		m.ore_name = ore
		m.level = 1 if i == 0 else 0               # seul le 1er étage démarre débloqué
		m.base_output = 1.0
		m.prod_growth = cfg.prod_growth
		m.base_cost = cfg.floor_base_unlock * pow(cfg.floor_cost_factor, i)
		m.cost_growth = cfg.cost_growth
		m.unit_price = pow(cfg.floor_value_factor, i)
		m.has_manager = false
		m.bonus_mult = 1.0
		m.buffer = 0.0
		m.buffer_cap = 30.0 * (1.0 + i * 0.6)
		c.mines.append(m)

	c.elevator = Elevator.new()
	c.warehouse = Warehouse.new()
	return c

static func build_all_continents(cfg: BalanceConfig) -> Array[Continent]:
	var arr: Array[Continent] = []
	for id in range(CONTINENTS.size()):
		arr.append(build_continent(id, cfg))
	return arr

static func build_first_continent(cfg: BalanceConfig) -> Continent:
	return build_continent(0, cfg)
