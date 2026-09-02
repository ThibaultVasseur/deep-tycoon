## Ascenseur : vide les buffers des mines vers l'entrepôt. Débit = capacité / temps de voyage.
## Point de bottleneck central. Réf : docs/specs/elevator-transport.md.
class_name Elevator
extends Resource

@export var level: int = 1
@export var base_capacity: float = 10.0   # unités/voyage au niveau 1
@export var capacity_growth: float = 1.12
@export var base_speed: float = 3.0       # secondes/voyage au niveau 1
@export var speed_growth: float = 0.98    # < 1 : réduit le temps de voyage
@export var min_speed: float = 0.2        # plancher du temps de voyage
@export var base_cost: float = 50.0
@export var cost_growth: float = 1.15
@export var has_manager: bool = false
@export var bonus_mult: float = 1.0

func to_dict() -> Dictionary:
	return {
		"level": level, "base_capacity": base_capacity, "capacity_growth": capacity_growth,
		"base_speed": base_speed, "speed_growth": speed_growth, "min_speed": min_speed,
		"base_cost": base_cost, "cost_growth": cost_growth,
		"has_manager": has_manager, "bonus_mult": bonus_mult,
	}

static func from_dict(d: Dictionary) -> Elevator:
	var e := Elevator.new()
	e.level = int(d.get("level", 1))
	e.base_capacity = float(d.get("base_capacity", 10.0))
	e.capacity_growth = float(d.get("capacity_growth", 1.12))
	e.base_speed = float(d.get("base_speed", 3.0))
	e.speed_growth = float(d.get("speed_growth", 0.98))
	e.min_speed = float(d.get("min_speed", 0.2))
	e.base_cost = float(d.get("base_cost", 50.0))
	e.cost_growth = float(d.get("cost_growth", 1.15))
	e.has_manager = bool(d.get("has_manager", false))
	e.bonus_mult = float(d.get("bonus_mult", 1.0))
	e.sanitize()
	return e

## Sécurité §4 : bornes après désérialisation.
func sanitize() -> void:
	level = maxi(level, 1)
	base_capacity = maxf(_safe(base_capacity, 1.0), 0.0)
	capacity_growth = clampf(_safe(capacity_growth, 1.0), 1.0, 100.0)
	base_speed = maxf(_safe(base_speed, 1.0), 0.01)
	speed_growth = clampf(_safe(speed_growth, 1.0), 0.01, 1.0)
	min_speed = clampf(_safe(min_speed, 0.2), 0.01, base_speed)
	base_cost = maxf(_safe(base_cost, 1.0), 0.0)
	cost_growth = clampf(_safe(cost_growth, 1.0), 1.0, 100.0)
	bonus_mult = clampf(_safe(bonus_mult, 1.0), 0.0, 1.0e9)

static func _safe(x: float, fallback: float) -> float:
	if is_nan(x) or is_inf(x) or x < 0.0:
		return fallback
	return x
