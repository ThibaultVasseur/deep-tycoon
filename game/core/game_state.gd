## État global du jeu, sérialisable (save). Une seule instance vit dans le game_controller.
## Réf : docs/specs/save-system.md, docs/PRD.md §7.
class_name GameState
extends Resource

@export var schema_version: int = 1
@export var super_cash: float = 0.0            # monnaie mondiale (prestige)
@export var active_continent: int = 0
@export var continents: Array[Continent] = []

# Multiplicateurs globaux (prestige upgrades + IAP + boosts) — appliqués au cash dans economy.gd.
@export var perm_x2: bool = false              # IAP x2 permanent
@export var global_prod_mult: float = 1.0      # bonus prestige (production)
@export var global_sell_mult: float = 1.0      # bonus prestige (vente)
@export var boost_factor: float = 2.0
@export var boost_end_unix: float = 0.0        # timestamp de fin de boost rewarded
@export var offline_cap_bonus_seconds: float = 0.0  # extension du cap hors-ligne (prestige/IAP)

# Expéditions (événement temporaire, fonctionne hors-ligne via timestamps)
@export var expedition_end_unix: float = 0.0        # 0 = aucune en cours
@export var expedition_cooldown_end_unix: float = 0.0
@export var expedition_reward_cash: float = 0.0
@export var expedition_reward_super: int = 0

# Anti-triche / offline (sécurité §2)
@export var last_seen: float = 0.0             # horloge murale à la dernière sauvegarde
@export var pending_reward: Dictionary = {}    # récompense en attente (idempotence)

@export var settings: Dictionary = {"sound": true, "haptics": true}

## Continent actif (ou null si index invalide).
func active() -> Continent:
	if active_continent >= 0 and active_continent < continents.size():
		return continents[active_continent]
	return null

## Nouvelle partie propre.
static func new_game(cfg: BalanceConfig) -> GameState:
	var s := GameState.new()
	s.schema_version = 1
	s.super_cash = 0.0
	s.active_continent = 0
	s.continents = Content.build_all_continents(cfg)
	s.perm_x2 = false
	s.global_prod_mult = 1.0
	s.global_sell_mult = 1.0
	s.boost_factor = cfg.boost_factor
	s.boost_end_unix = 0.0
	s.last_seen = 0.0
	s.pending_reward = {}
	return s

func to_dict() -> Dictionary:
	var cont_dicts := []
	for c in continents:
		cont_dicts.append(c.to_dict())
	return {
		"schema_version": schema_version,
		"super_cash": super_cash,
		"active_continent": active_continent,
		"continents": cont_dicts,
		"perm_x2": perm_x2,
		"global_prod_mult": global_prod_mult,
		"global_sell_mult": global_sell_mult,
		"boost_factor": boost_factor,
		"boost_end_unix": boost_end_unix,
		"offline_cap_bonus_seconds": offline_cap_bonus_seconds,
		"expedition_end_unix": expedition_end_unix,
		"expedition_cooldown_end_unix": expedition_cooldown_end_unix,
		"expedition_reward_cash": expedition_reward_cash,
		"expedition_reward_super": expedition_reward_super,
		"last_seen": last_seen,
		"pending_reward": pending_reward,
		"settings": settings,
	}

static func from_dict(d: Dictionary) -> GameState:
	var s := GameState.new()
	s.schema_version = int(d.get("schema_version", 1))
	s.super_cash = float(d.get("super_cash", 0.0))
	s.active_continent = int(d.get("active_continent", 0))
	var arr: Array[Continent] = []
	for cd in d.get("continents", []):
		if cd is Dictionary:
			arr.append(Continent.from_dict(cd))
	s.continents = arr
	s.perm_x2 = bool(d.get("perm_x2", false))
	s.global_prod_mult = float(d.get("global_prod_mult", 1.0))
	s.global_sell_mult = float(d.get("global_sell_mult", 1.0))
	s.boost_factor = float(d.get("boost_factor", 2.0))
	s.boost_end_unix = float(d.get("boost_end_unix", 0.0))
	s.offline_cap_bonus_seconds = float(d.get("offline_cap_bonus_seconds", 0.0))
	s.expedition_end_unix = float(d.get("expedition_end_unix", 0.0))
	s.expedition_cooldown_end_unix = float(d.get("expedition_cooldown_end_unix", 0.0))
	s.expedition_reward_cash = float(d.get("expedition_reward_cash", 0.0))
	s.expedition_reward_super = int(d.get("expedition_reward_super", 0))
	s.last_seen = float(d.get("last_seen", 0.0))
	var pr = d.get("pending_reward", {})
	s.pending_reward = pr if pr is Dictionary else {}
	var st = d.get("settings", {})
	s.settings = st if st is Dictionary else {"sound": true, "haptics": true}
	s.sanitize()
	return s

## Sécurité §4 : validation/bornage global après chargement.
func sanitize() -> void:
	schema_version = maxi(schema_version, 1)
	super_cash = maxf(_safe(super_cash, 0.0), 0.0)
	global_prod_mult = clampf(_safe(global_prod_mult, 1.0), 1.0, 1.0e12)
	global_sell_mult = clampf(_safe(global_sell_mult, 1.0), 1.0, 1.0e12)
	boost_factor = clampf(_safe(boost_factor, 2.0), 1.0, 1000.0)
	boost_end_unix = maxf(_safe(boost_end_unix, 0.0), 0.0)
	offline_cap_bonus_seconds = clampf(_safe(offline_cap_bonus_seconds, 0.0), 0.0, 604800.0)
	expedition_end_unix = maxf(_safe(expedition_end_unix, 0.0), 0.0)
	expedition_cooldown_end_unix = maxf(_safe(expedition_cooldown_end_unix, 0.0), 0.0)
	expedition_reward_cash = maxf(_safe(expedition_reward_cash, 0.0), 0.0)
	expedition_reward_super = maxi(expedition_reward_super, 0)
	last_seen = maxf(_safe(last_seen, 0.0), 0.0)
	if continents.is_empty():
		active_continent = 0
	else:
		active_continent = clampi(active_continent, 0, continents.size() - 1)
	for c in continents:
		if c != null:
			c.sanitize()

static func _safe(x: float, fallback: float) -> float:
	if is_nan(x) or is_inf(x) or x < 0.0:
		return fallback
	return x
