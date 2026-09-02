## Audio (autoload "Audio"). Structure prête ; les assets .ogg seront branchés plus tard.
## Réf : docs/PRD.md §6.
extends Node

var enabled := true

# Mapping nom logique -> chemin d'asset (à remplir quand les sons seront fournis).
const SFX_PATHS := {
	"tap": "",
	"upgrade": "",
	"sell": "",
	"hire": "",
	"prestige": "",
}

var _players: Dictionary = {}

func play_sfx(sfx_name: String) -> void:
	if not enabled:
		return
	var path: String = SFX_PATHS.get(sfx_name, "")
	if path == "" or not ResourceLoader.exists(path):
		return  # pas encore d'asset -> silencieux, jamais d'erreur
	var p: AudioStreamPlayer = _players.get(sfx_name)
	if p == null:
		p = AudioStreamPlayer.new()
		p.stream = load(path)
		add_child(p)
		_players[sfx_name] = p
	p.play()
