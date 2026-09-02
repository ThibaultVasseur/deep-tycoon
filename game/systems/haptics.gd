## Feedback haptique (autoload "Haptics"). Réf : docs/PRD.md §6.
## Actif seulement sur mobile ; respecte le réglage joueur.
extends Node

var enabled := true

func tap() -> void:
	_vibrate(15)

func success() -> void:
	_vibrate(30)

func heavy() -> void:
	_vibrate(60)

func _vibrate(ms: int) -> void:
	if not enabled:
		return
	if OS.get_name() == "Android" or OS.get_name() == "iOS":
		Input.vibrate_handheld(ms)
