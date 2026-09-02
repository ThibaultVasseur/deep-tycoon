## Calcul du gain hors-ligne. PUR et statique -> testable en headless.
## Sécurité §2 : horloge reculée => aucun gain ; cap strict dans le temps.
## Réf : docs/specs/offline-earnings.md, docs/PRD.md §5.
class_name OfflineCalculator
extends RefCounted

## Calcule le gain hors-ligne accumulé entre state.last_seen et `now`.
## Retour : { "elapsed": secondes créditées, "gain": cash gagné (base, hors x2 pub) }
static func compute(state: GameState, now: float, cfg: BalanceConfig) -> Dictionary:
	var res := {"elapsed": 0.0, "gain": 0.0}
	if state == null or cfg == null:
		return res
	var cont: Continent = state.active()
	if cont == null:
		return res

	var raw := now - state.last_seen
	# Anti-triche horloge (sécurité §2) : temps négatif => 0, jamais de crédit.
	if raw <= 0.0:
		return res

	var cap := cfg.offline_cap_seconds + maxf(state.offline_cap_bonus_seconds, 0.0)
	var elapsed := clampf(raw, 0.0, cap)

	# Seuls les composants automatisés produisent hors-ligne (min du pipeline auto).
	var units := Economy.pipeline_units_per_sec(cont, true)
	if units <= 0.0:
		res.elapsed = elapsed
		return res  # pipeline non entièrement automatisé -> aucun gain

	var price := Economy.avg_unit_price(cont, true)
	var mult := Economy.cash_multiplier(state, cont, now)  # boost expiré ? géré via `now`
	var gain := units * price * cfg.idle_factor * elapsed * mult

	res.elapsed = elapsed
	res.gain = maxf(gain, 0.0)
	return res
