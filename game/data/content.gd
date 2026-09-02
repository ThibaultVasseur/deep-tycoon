## Contenu de jeu (seed des continents/mines). Séparé de la logique -> facile à équilibrer/étendre.
## Chaque continent = économie fraîche à monnaie locale, débloquée au super-cash. Réf : PRD §3.7, §12.
class_name Content
extends RefCounted

# Métadonnées des continents. `unlock_super_cash` = coût de déblocage (monnaie mondiale).
const CONTINENTS := [
	{"name": "Charbonnage", "ores": ["Charbon", "Cuivre", "Fer", "Argent", "Or"], "unlock_super_cash": 0},
	{"name": "Caverne de Cristal", "ores": ["Cristal", "Améthyste", "Saphir", "Émeraude", "Diamant"], "unlock_super_cash": 50},
	{"name": "Puits de Magma", "ores": ["Soufre", "Obsidienne", "Rubis", "Magma", "Cœur de feu"], "unlock_super_cash": 750},
]

static func continent_count() -> int:
	return CONTINENTS.size()

static func continent_unlock_cost(id: int) -> int:
	if id < 0 or id >= CONTINENTS.size():
		return 0
	return int(CONTINENTS[id].unlock_super_cash)

## Construit un continent par son id (économie fraîche ; mines profondes = saut de valeur x deep_factor).
static func build_continent(id: int, cfg: BalanceConfig) -> Continent:
	id = clampi(id, 0, CONTINENTS.size() - 1)
	var meta: Dictionary = CONTINENTS[id]
	var ores: Array = meta.ores

	var c := Continent.new()
	c.id = id
	c.name = meta.name
	c.unlocked = (id == 0)                 # le 1er est débloqué d'office
	c.mult_permanent = 1.0
	c.cash = (25.0 if id == 0 else 0.0)    # petit capital de départ sur le 1er continent
	c.mines = []

	var unit_price := 1.0
	for i in range(ores.size()):
		var m := Mine.new()
		m.id = i
		m.ore_name = ores[i]
		m.level = 1 if i == 0 else 0
		m.base_output = 1.0
		m.prod_growth = cfg.prod_growth
		m.base_cost = 10.0 * pow(8.0, i)
		m.cost_growth = cfg.cost_growth
		m.unit_price = unit_price
		m.has_manager = false
		m.bonus_mult = 1.0
		m.buffer = 0.0
		m.buffer_cap = 50.0 * pow(2.0, i)
		c.mines.append(m)
		unit_price *= cfg.deep_factor

	c.elevator = Elevator.new()
	c.warehouse = Warehouse.new()
	return c

## Tous les continents (pour une nouvelle partie) : seul le premier est débloqué.
static func build_all_continents(cfg: BalanceConfig) -> Array[Continent]:
	var arr: Array[Continent] = []
	for id in range(CONTINENTS.size()):
		arr.append(build_continent(id, cfg))
	return arr

## Compat : le premier continent.
static func build_first_continent(cfg: BalanceConfig) -> Continent:
	return build_continent(0, cfg)
