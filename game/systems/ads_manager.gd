## Gestion des pubs RÉCOMPENSÉES (autoload "Ads"). Règle d'or : opt-in, non bloquant.
## Stub desktop/dev = récompense immédiate. Android = à brancher sur AdMob (Google Mobile Ads).
## Réf : docs/specs/monetization-ads.md, docs/specs/security.md §3.
extends Node

signal reward_granted(id: String, success: bool)

## Affiche une pub récompensée. `on_result` (Callable(bool)) est rappelé avec le succès.
## Le gameplay ne dépend jamais du résultat : si indisponible, l'action est simplement sans effet.
func show_rewarded(id: String, on_result: Callable = Callable()) -> void:
	if _is_real_ads_platform():
		# TODO(Android) : afficher la pub AdMob réelle + AdMob SSV côté serveur (sécurité §3).
		push_warning("Ads: plugin réel non branché — fallback stub.")
	# Stub : récompense accordée immédiatement (dev/desktop).
	if on_result.is_valid():
		on_result.call(true)
	reward_granted.emit(id, true)

func is_ready(_id: String) -> bool:
	return true  # stub toujours prêt ; Android renverra l'état réel du cache pub.

func _is_real_ads_platform() -> bool:
	# Passera à true quand le plugin Android sera intégré.
	return OS.get_name() == "Android" and false
