## Runner de tests headless (aucune dépendance externe).
## Lancer : godot --headless --path <projet> --script res://tests/run_tests.gd
## Code de sortie : 0 si tout passe, 1 sinon (utilisable en CI).
extends SceneTree

const TEST_SCRIPTS := [
	"res://tests/test_number_format.gd",
	"res://tests/test_economy.gd",
	"res://tests/test_production_engine.gd",
	"res://tests/test_offline.gd",
	"res://tests/test_save.gd",
	"res://tests/test_continents.gd",
	"res://tests/test_events.gd",
]

func _initialize() -> void:
	var total := 0
	var failed := 0
	print("\n=== Deep Tycoon : tests unitaires ===\n")

	for path in TEST_SCRIPTS:
		var script: GDScript = load(path)
		if script == null:
			print("[XX] impossible de charger %s" % path)
			failed += 1
			continue
		var probe = script.new()
		var names: Array[String] = []
		for m in probe.get_method_list():
			var n: String = m.name
			if n.begins_with("test_") and not names.has(n):
				names.append(n)

		print("-- %s (%d tests)" % [path.get_file(), names.size()])
		for n in names:
			var t = script.new()
			if t.has_method("before_each"):
				t.before_each()
			t.call(n)
			total += 1
			if t._failures.size() > 0:
				failed += 1
				print("  [XX] %s" % n)
				for f in t._failures:
					print("        - %s" % f)
			elif t._checks == 0:
				# Aucune assertion exécutée = test avorté par une erreur runtime -> échec.
				failed += 1
				print("  [XX] %s (aucune assertion executee : test avorte ?)" % n)
			else:
				print("  [OK] %s" % n)
		print("")

	print("=== Bilan : %d tests, %d echec(s) ===" % [total, failed])
	quit(1 if failed > 0 else 0)
