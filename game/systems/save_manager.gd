## Sauvegarde/chargement sécurisés (autoload "SaveManager").
## Sécurité §1 : chiffrement AES au repos + signature HMAC-SHA256 (anti-tamper) + écriture atomique.
## Format JSON uniquement (jamais de .res/.tres non fiable = pas d'exécution de code).
## Réf : docs/specs/save-system.md, docs/specs/security.md.
extends Node

const SAVE_PATH := "user://save.dat"
const TMP_PATH := "user://save.tmp"
const SAVE_FILE := "save.dat"
const TMP_FILE := "save.tmp"

# Clé HMAC embarquée (obfusquée par assemblage). Ce n'est pas un secret absolu côté client,
# mais combinée au chiffrement + script encryption à l'export, elle écarte la triche "bloc-notes".
const _K_A := "dT-9f2"
const _K_B := "Qx!7mB"
const _K_C := "z0#Lp4"
const _ENC_PASS := "DeepTycoon::at-rest::v1::$k9Wm2"

## Sauvegarde l'état (l'appelant met à jour state.last_seen avant l'appel, ex : sur pause).
func save(state: GameState) -> bool:
	if state == null:
		return false
	var payload := JSON.stringify(state.to_dict())
	var envelope := {"payload": payload, "sig": _hmac_hex(payload)}
	var envelope_json := JSON.stringify(envelope)

	# Écriture atomique : temp puis rename.
	var f := FileAccess.open_encrypted_with_pass(TMP_PATH, FileAccess.WRITE, _ENC_PASS)
	if f == null:
		push_error("SaveManager: impossible d'ouvrir le fichier temp (%d)" % FileAccess.get_open_error())
		return false
	f.store_string(envelope_json)
	f.close()

	var d := DirAccess.open("user://")
	if d == null:
		return false
	if d.file_exists(SAVE_FILE):
		d.remove(SAVE_FILE)
	return d.rename(TMP_FILE, SAVE_FILE) == OK

## Charge l'état. Retourne null si absent / corrompu / altéré (l'appelant fait new_game).
func load_state() -> GameState:
	if not FileAccess.file_exists(SAVE_PATH):
		return null
	var f := FileAccess.open_encrypted_with_pass(SAVE_PATH, FileAccess.READ, _ENC_PASS)
	if f == null:
		push_warning("SaveManager: sauvegarde illisible (mauvaise clé / corrompue) -> reset sûr")
		return null
	var text := f.get_as_text()
	f.close()

	var env = JSON.parse_string(text)
	if not (env is Dictionary) or not env.has("payload") or not env.has("sig"):
		push_warning("SaveManager: enveloppe invalide -> reset sûr")
		return null
	var payload := str(env["payload"])
	# Vérification d'intégrité (sécurité §1).
	if _hmac_hex(payload) != str(env["sig"]):
		push_warning("SaveManager: signature HMAC invalide (sauvegarde altérée) -> reset sûr")
		return null

	var data = JSON.parse_string(payload)
	if not (data is Dictionary):
		push_warning("SaveManager: payload invalide -> reset sûr")
		return null
	return GameState.from_dict(data)  # from_dict() appelle sanitize()

func has_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH)

func delete_save() -> void:
	var d := DirAccess.open("user://")
	if d != null and d.file_exists(SAVE_FILE):
		d.remove(SAVE_FILE)

## HMAC-SHA256(payload) en hexadécimal.
func _hmac_hex(payload: String) -> String:
	var ctx := HMACContext.new()
	if ctx.start(HashingContext.HASH_SHA256, _key_bytes()) != OK:
		return ""
	ctx.update(payload.to_utf8_buffer())
	return ctx.finish().hex_encode()

func _key_bytes() -> PackedByteArray:
	return (_K_B + _K_A + _K_C).to_utf8_buffer()
