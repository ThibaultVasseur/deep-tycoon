extends TestCase

func _sm() -> Node:
	return load("res://game/systems/save_manager.gd").new()

func _sample_state() -> GameState:
	var s := GameState.new_game(BalanceConfig.default())
	s.super_cash = 123.0
	s.active().cash = 4567.0
	s.active().mines[0].level = 5
	s.active().mines[0].has_manager = true
	s.last_seen = 99999.0
	return s

func test_roundtrip_preserves_state() -> void:
	var sm := _sm()
	sm.delete_save()
	var s := _sample_state()
	assert_true(sm.save(s), "save doit réussir")
	var loaded: GameState = sm.load_state()
	assert_ne(loaded, null, "load doit renvoyer un état")
	assert_almost(loaded.super_cash, 123.0)
	assert_almost(loaded.active().cash, 4567.0)
	assert_eq(loaded.active().mines[0].level, 5)
	assert_true(loaded.active().mines[0].has_manager)
	assert_almost(loaded.last_seen, 99999.0)
	assert_eq(loaded.active().mines.size(), BalanceConfig.default().floors_per_continent)
	sm.delete_save()
	sm.free()

func test_no_save_returns_null() -> void:
	var sm := _sm()
	sm.delete_save()
	assert_eq(sm.load_state(), null)
	assert_false(sm.has_save())
	sm.free()

func test_corrupted_file_safe_reset() -> void:
	var sm := _sm()
	sm.delete_save()
	# Écrit des octets aléatoires non chiffrés -> déchiffrement échoue -> reset sûr (null).
	var f := FileAccess.open("user://save.dat", FileAccess.WRITE)
	f.store_string("ceci n'est pas une sauvegarde valide %$#@")
	f.close()
	assert_eq(sm.load_state(), null, "fichier corrompu -> null, pas de crash")
	sm.delete_save()
	sm.free()

func test_tampered_payload_rejected_by_hmac() -> void:
	var sm := _sm()
	sm.delete_save()
	sm.save(_sample_state())

	var consts: Dictionary = load("res://game/systems/save_manager.gd").get_script_constant_map()
	var enc_pass: String = consts["_ENC_PASS"]
	var path: String = consts["SAVE_PATH"]

	# Déchiffre, modifie le payload SANS recalculer la signature, ré-écrit.
	var fr := FileAccess.open_encrypted_with_pass(path, FileAccess.READ, enc_pass)
	var env = JSON.parse_string(fr.get_as_text())
	fr.close()
	env["payload"] = str(env["payload"]) + " "  # toute modification du contenu invalide le HMAC
	var fw := FileAccess.open_encrypted_with_pass(path, FileAccess.WRITE, enc_pass)
	fw.store_string(JSON.stringify(env))
	fw.close()

	assert_eq(sm.load_state(), null, "payload altéré -> rejet par HMAC")
	sm.delete_save()
	sm.free()

func test_hmac_is_deterministic_and_sensitive() -> void:
	var sm := _sm()
	assert_eq(sm._hmac_hex("charbon"), sm._hmac_hex("charbon"), "déterministe")
	assert_ne(sm._hmac_hex("charbon"), sm._hmac_hex("charbom"), "sensible au contenu")
	sm.free()
