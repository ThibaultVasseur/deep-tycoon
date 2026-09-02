## Un puits de mine. Extrait une ressource dans son buffer, vidé par l'ascenseur.
## Réf : docs/specs/mine-production.md.
class_name Mine
extends Resource

@export var id: int = 0
@export var ore_name: String = "Charbon"   # 'resource_name' est réservé par la classe Resource
@export var level: int = 0            # 0 = verrouillée (produit 0)
@export var base_output: float = 1.0  # unités/s au niveau 1
@export var prod_growth: float = 1.10
@export var base_cost: float = 10.0
@export var cost_growth: float = 1.15
@export var unit_price: float = 1.0   # valeur cash d'une unité
@export var has_manager: bool = false
@export var bonus_mult: float = 1.0   # bonus de manager (1.0 = aucun)
@export var buffer: float = 0.0       # unités extraites en attente de l'ascenseur
@export var buffer_cap: float = 50.0

func is_unlocked() -> bool:
	return level > 0

func to_dict() -> Dictionary:
	return {
		"id": id, "ore_name": ore_name, "level": level,
		"base_output": base_output, "prod_growth": prod_growth,
		"base_cost": base_cost, "cost_growth": cost_growth, "unit_price": unit_price,
		"has_manager": has_manager, "bonus_mult": bonus_mult,
		"buffer": buffer, "buffer_cap": buffer_cap,
	}

static func from_dict(d: Dictionary) -> Mine:
	var m := Mine.new()
	m.id = int(d.get("id", 0))
	m.ore_name = str(d.get("ore_name", "Charbon"))
	m.level = int(d.get("level", 0))
	m.base_output = float(d.get("base_output", 1.0))
	m.prod_growth = float(d.get("prod_growth", 1.10))
	m.base_cost = float(d.get("base_cost", 10.0))
	m.cost_growth = float(d.get("cost_growth", 1.15))
	m.unit_price = float(d.get("unit_price", 1.0))
	m.has_manager = bool(d.get("has_manager", false))
	m.bonus_mult = float(d.get("bonus_mult", 1.0))
	m.buffer = float(d.get("buffer", 0.0))
	m.buffer_cap = float(d.get("buffer_cap", 50.0))
	m.sanitize()
	return m

## Sécurité §4 : borne les champs après désérialisation (anti valeurs aberrantes / NaN).
func sanitize() -> void:
	level = maxi(level, 0)
	base_output = _safe(base_output, 0.0)
	prod_growth = clampf(_safe(prod_growth, 1.0), 1.0, 100.0)
	base_cost = _safe(base_cost, 0.0)
	cost_growth = clampf(_safe(cost_growth, 1.0), 1.0, 100.0)
	unit_price = _safe(unit_price, 0.0)
	bonus_mult = clampf(_safe(bonus_mult, 1.0), 0.0, 1.0e9)
	buffer_cap = maxf(_safe(buffer_cap, 0.0), 0.0)
	buffer = clampf(_safe(buffer, 0.0), 0.0, buffer_cap)

static func _safe(x: float, fallback: float) -> float:
	if is_nan(x) or is_inf(x) or x < 0.0:
		return fallback
	return x
