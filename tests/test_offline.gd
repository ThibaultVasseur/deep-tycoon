extends TestCase

func _auto_continent() -> Continent:
	# Pipeline entièrement automatisé, débit limité par les mines (10 u/s @ prix 1).
	var c := Continent.new()
	c.mult_permanent = 1.0
	var m := Mine.new()
	m.level = 1
	m.base_output = 10.0
	m.prod_growth = 1.0
	m.unit_price = 1.0
	m.buffer_cap = 1e12
	m.has_manager = true
	c.mines.append(m)
	var e := Elevator.new()
	e.base_capacity = 1000.0
	e.base_speed = 1.0
	e.speed_growth = 1.0
	e.has_manager = true
	c.elevator = e
	var w := Warehouse.new()
	w.base_store_cap = 1e12
	w.base_sell_rate = 1000.0
	w.sell_rate_growth = 1.0
	w.has_manager = true
	c.warehouse = w
	return c

func _state() -> GameState:
	var s := GameState.new()
	s.continents.append(_auto_continent())
	s.active_continent = 0
	return s

func test_offline_gain_formula() -> void:
	var s := _state()
	s.last_seen = 0.0
	var cfg := BalanceConfig.default()  # idle_factor=0.5, cap=8h
	# 100s d'absence : 10 u/s * prix 1 * idle_factor 0.5 * 100s * mult 1 = 500
	var r := OfflineCalculator.compute(s, 100.0, cfg)
	assert_almost(r.elapsed, 100.0)
	assert_almost(r.gain, 500.0, 0.01)

func test_offline_capped() -> void:
	var s := _state()
	s.last_seen = 0.0
	var cfg := BalanceConfig.default()
	# Absence énorme (1e9 s) -> clampée au cap 8h = 28800 s.
	var r := OfflineCalculator.compute(s, 1.0e9, cfg)
	assert_almost(r.elapsed, cfg.offline_cap_seconds)
	assert_almost(r.gain, 10.0 * 1.0 * 0.5 * cfg.offline_cap_seconds, 0.01)

func test_offline_cap_bonus_extends() -> void:
	var s := _state()
	s.last_seen = 0.0
	s.offline_cap_bonus_seconds = 3600.0  # +1h
	var cfg := BalanceConfig.default()
	var r := OfflineCalculator.compute(s, 1.0e9, cfg)
	assert_almost(r.elapsed, cfg.offline_cap_seconds + 3600.0)

func test_clock_moved_backward_gives_zero() -> void:
	var s := _state()
	s.last_seen = 5000.0
	var cfg := BalanceConfig.default()
	# now < last_seen (horloge reculée) -> aucun gain (sécurité §2).
	var r := OfflineCalculator.compute(s, 1000.0, cfg)
	assert_almost(r.elapsed, 0.0)
	assert_almost(r.gain, 0.0)

func test_partial_automation_gives_zero() -> void:
	var s := _state()
	s.last_seen = 0.0
	s.active().warehouse.has_manager = false  # maillon non automatisé
	var cfg := BalanceConfig.default()
	var r := OfflineCalculator.compute(s, 100.0, cfg)
	assert_almost(r.gain, 0.0, 0.0001, "pipeline non entièrement automatisé")

func test_prestige_multiplier_applies_offline() -> void:
	var s := _state()
	s.last_seen = 0.0
	s.active().mult_permanent = 4.0  # multiplicateur permanent de prestige
	var cfg := BalanceConfig.default()
	var r := OfflineCalculator.compute(s, 100.0, cfg)
	# 500 * 4 = 2000
	assert_almost(r.gain, 2000.0, 0.01)
