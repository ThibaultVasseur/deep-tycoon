## Constantes d'équilibrage centralisées (une seule source de vérité).
## Modifier l'économie = éditer ce fichier, jamais la logique. Réf : docs/PRD.md §5.
class_name BalanceConfig
extends Resource

# --- Hors-ligne (offline) ---
@export var offline_cap_seconds: float = 28800.0   # 8 h ; extensible via bonus/IAP
@export var idle_factor: float = 0.5               # part du débit actif crédité hors-ligne
@export var min_offline_popup_seconds: float = 60.0

# --- Prestige ---
@export var prestige_threshold: float = 1.0e6      # seuil élevé -> prestige long ("pas facile")
@export var prestige_k: float = 10.0               # coefficient de la courbe racine
@export var mult_gain_per_super_cash: float = 0.02 # +2% de multiplicateur permanent par super-cash

# --- Boosts / pubs ---
@export var boost_factor: float = 2.0              # x2 par défaut
@export var boost_duration_seconds: float = 900.0  # 15 min
@export var time_skip_hours: float = 2.0

# --- Managers (automatisation) ---
@export var manager_unlock_level: int = 3      # niveau min du composant pour embaucher
@export var manager_cost_factor: float = 15.0  # coût = facteur x coût d'upgrade courant

# --- Runtime ---
@export var autosave_interval_seconds: float = 15.0
@export var manual_tap_seconds_worth: float = 1.0  # 1 tap = 1s de production

# --- Expéditions (événement) ---
@export var expedition_duration_seconds: float = 1800.0    # 30 min
@export var expedition_cooldown_seconds: float = 3600.0     # 1 h avant la suivante
@export var expedition_reward_minutes: float = 20.0         # récompense = 20 min de prod
@export var expedition_super_cash_reward: int = 1           # bonus super-cash au retour

# --- Contenu (seed du premier continent) ---
@export var deep_factor: float = 100.0             # saut de valeur entre 2 mines (cible x50..x500)
@export var cost_growth: float = 1.15              # croissance de coût standard
@export var prod_growth: float = 1.10              # croissance de production par niveau

static func default() -> BalanceConfig:
	return BalanceConfig.new()
