## Un continent (zone de minage) : ses mines, son ascenseur, son entrepôt, sa monnaie locale.
## Le prestige réinitialise le continent mais conserve super-cash + mult_permanent. Réf : PRD §3.7, §12.
class_name Continent
extends Resource

@export var id: int = 0
@export var name: String = "Charbonnage"
@export var mines: Array[Mine] = []
@export var elevator: Elevator
@export var warehouse: Warehouse
@export var cash: float = 0.0              # monnaie locale du continent
@export var cash_total_earned: float = 0.0 # cumul (base du calcul de prestige)
@export var mult_permanent: float = 1.0    # multiplicateur de cash empilé par les prestiges
@export var unlocked: bool = false

## Réinitialise la progression du continent (prestige), en gardant mult_permanent.
func reset_for_prestige(fresh: Continent) -> void:
	mines = fresh.mines
	elevator = fresh.elevator
	warehouse = fresh.warehouse
	cash = 0.0
	cash_total_earned = 0.0
	# mult_permanent et unlocked sont conservés (gérés par l'appelant).

func to_dict() -> Dictionary:
	var mine_dicts := []
	for m in mines:
		mine_dicts.append(m.to_dict())
	return {
		"id": id, "name": name, "mines": mine_dicts,
		"elevator": elevator.to_dict() if elevator != null else {},
		"warehouse": warehouse.to_dict() if warehouse != null else {},
		"cash": cash, "cash_total_earned": cash_total_earned,
		"mult_permanent": mult_permanent, "unlocked": unlocked,
	}

static func from_dict(d: Dictionary) -> Continent:
	var c := Continent.new()
	c.id = int(d.get("id", 0))
	c.name = str(d.get("name", "Charbonnage"))
	var arr: Array[Mine] = []
	for md in d.get("mines", []):
		if md is Dictionary:
			arr.append(Mine.from_dict(md))
	c.mines = arr
	c.elevator = Elevator.from_dict(d.get("elevator", {}))
	c.warehouse = Warehouse.from_dict(d.get("warehouse", {}))
	c.cash = float(d.get("cash", 0.0))
	c.cash_total_earned = float(d.get("cash_total_earned", 0.0))
	c.mult_permanent = float(d.get("mult_permanent", 1.0))
	c.unlocked = bool(d.get("unlocked", false))
	c.sanitize()
	return c

## Sécurité §4 : bornes + propagation aux sous-modèles.
func sanitize() -> void:
	cash = maxf(_safe(cash, 0.0), 0.0)
	cash_total_earned = maxf(_safe(cash_total_earned, 0.0), 0.0)
	mult_permanent = clampf(_safe(mult_permanent, 1.0), 1.0, 1.0e12)
	for m in mines:
		if m != null:
			m.sanitize()
	if elevator != null:
		elevator.sanitize()
	if warehouse != null:
		warehouse.sanitize()

static func _safe(x: float, fallback: float) -> float:
	if is_nan(x) or is_inf(x) or x < 0.0:
		return fallback
	return x
