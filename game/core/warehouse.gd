## Entrepôt : stocke les unités livrées puis les vend contre du cash.
## Le stock porte une valeur agrégée (prix moyen pondéré) pour gérer des ressources mixtes.
## Réf : docs/specs/warehouse-conversion.md.
class_name Warehouse
extends Resource

@export var level: int = 1
@export var base_store_cap: float = 50.0
@export var store_cap_growth: float = 1.14
@export var base_sell_rate: float = 5.0   # unités/s au niveau 1
@export var sell_rate_growth: float = 1.12
@export var base_cost: float = 50.0
@export var cost_growth: float = 1.15
@export var has_manager: bool = false
@export var bonus_mult: float = 1.0
@export var stock: float = 0.0            # unités en stock
@export var stock_value: float = 0.0      # valeur cash totale du stock courant

## Prix moyen pondéré d'une unité en stock.
func avg_price() -> float:
	return stock_value / stock if stock > 0.0 else 0.0

func to_dict() -> Dictionary:
	return {
		"level": level, "base_store_cap": base_store_cap, "store_cap_growth": store_cap_growth,
		"base_sell_rate": base_sell_rate, "sell_rate_growth": sell_rate_growth,
		"base_cost": base_cost, "cost_growth": cost_growth,
		"has_manager": has_manager, "bonus_mult": bonus_mult,
		"stock": stock, "stock_value": stock_value,
	}

static func from_dict(d: Dictionary) -> Warehouse:
	var w := Warehouse.new()
	w.level = int(d.get("level", 1))
	w.base_store_cap = float(d.get("base_store_cap", 50.0))
	w.store_cap_growth = float(d.get("store_cap_growth", 1.14))
	w.base_sell_rate = float(d.get("base_sell_rate", 5.0))
	w.sell_rate_growth = float(d.get("sell_rate_growth", 1.12))
	w.base_cost = float(d.get("base_cost", 50.0))
	w.cost_growth = float(d.get("cost_growth", 1.15))
	w.has_manager = bool(d.get("has_manager", false))
	w.bonus_mult = float(d.get("bonus_mult", 1.0))
	w.stock = float(d.get("stock", 0.0))
	w.stock_value = float(d.get("stock_value", 0.0))
	w.sanitize()
	return w

## Sécurité §4 : bornes après désérialisation.
func sanitize() -> void:
	level = maxi(level, 1)
	base_store_cap = maxf(_safe(base_store_cap, 1.0), 0.0)
	store_cap_growth = clampf(_safe(store_cap_growth, 1.0), 1.0, 100.0)
	base_sell_rate = maxf(_safe(base_sell_rate, 1.0), 0.0)
	sell_rate_growth = clampf(_safe(sell_rate_growth, 1.0), 1.0, 100.0)
	base_cost = maxf(_safe(base_cost, 1.0), 0.0)
	cost_growth = clampf(_safe(cost_growth, 1.0), 1.0, 100.0)
	bonus_mult = clampf(_safe(bonus_mult, 1.0), 0.0, 1.0e9)
	stock = maxf(_safe(stock, 0.0), 0.0)
	stock_value = maxf(_safe(stock_value, 0.0), 0.0)

static func _safe(x: float, fallback: float) -> float:
	if is_nan(x) or is_inf(x) or x < 0.0:
		return fallback
	return x
