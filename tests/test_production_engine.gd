extends TestCase

const NOW := 1000.0  # > boost_end_unix par défaut (0) -> pas de boost sauf test dédié

func _state_with(cont: Continent) -> GameState:
	var s := GameState.new()
	s.continents.append(cont)
	s.active_continent = 0
	return s

func _mine(level: int, out: float, price := 1.0, cap := 1000.0, auto := true) -> Mine:
	var m := Mine.new()
	m.level = level
	m.base_output = out
	m.prod_growth = 1.0
	m.unit_price = price
	m.buffer_cap = cap
	m.has_manager = auto
	return m

func _elevator(capacity: float, speed: float, auto := true) -> Elevator:
	var e := Elevator.new()
	e.level = 1
	e.base_capacity = capacity
	e.base_speed = speed
	e.speed_growth = 1.0
	e.min_speed = 0.001
	e.has_manager = auto
	return e

func _warehouse(store_cap: float, sell_rate: float, auto := true) -> Warehouse:
	var w := Warehouse.new()
	w.level = 1
	w.base_store_cap = store_cap
	w.base_sell_rate = sell_rate
	w.sell_rate_growth = 1.0
	w.has_manager = auto
	return w

func test_basic_flow_produces_cash() -> void:
	var c := Continent.new()
	c.mult_permanent = 1.0
	c.mines.append(_mine(1, 10.0))
	c.elevator = _elevator(1000.0, 1.0)
	c.warehouse = _warehouse(1000.0, 1000.0)
	var s := _state_with(c)

	var r := ProductionEngine.tick(s, 1.0, NOW)
	assert_almost(r.cash_gained, 10.0, 0.001, "1s @ 10 u/s @ prix 1")
	assert_almost(c.cash, 10.0)
	assert_almost(c.warehouse.stock, 0.0, 0.001, "tout vendu")

func test_upstream_bottleneck_flag() -> void:
	var c := Continent.new()
	c.mult_permanent = 1.0
	c.mines.append(_mine(1, 100.0))          # 100 u/s
	c.elevator = _elevator(10.0, 1.0)        # 10 u/s -> trop lent
	c.warehouse = _warehouse(10000.0, 10000.0)
	var s := _state_with(c)

	var r := ProductionEngine.tick(s, 1.0, NOW)
	assert_true(r.upstream_bottleneck, "mines plus rapides que l'ascenseur")

func test_downstream_bottleneck_flag() -> void:
	var c := Continent.new()
	c.mult_permanent = 1.0
	var m := _mine(1, 0.0, 1.0, 1000.0, false)   # pas de manager -> ne produit pas
	m.buffer = 20.0                               # mais a du stock à évacuer
	c.mines.append(m)
	c.elevator = _elevator(1000.0, 1.0)
	c.warehouse = _warehouse(50.0, 0.0)          # plein d'avance, vente nulle
	c.warehouse.stock = 50.0
	c.warehouse.stock_value = 50.0
	var s := _state_with(c)

	var r := ProductionEngine.tick(s, 1.0, NOW)
	assert_true(r.downstream_bottleneck, "entrepôt plein bloque l'ascenseur")

func test_boost_doubles_cash() -> void:
	var c := Continent.new()
	c.mult_permanent = 1.0
	c.mines.append(_mine(1, 10.0))
	c.elevator = _elevator(1000.0, 1.0)
	c.warehouse = _warehouse(1000.0, 1000.0)
	var s := _state_with(c)
	s.boost_factor = 2.0
	s.boost_end_unix = NOW + 100.0               # boost actif

	var r := ProductionEngine.tick(s, 1.0, NOW)
	assert_almost(r.cash_gained, 20.0, 0.001, "x2 boost")

func test_manual_mine_tap_fills_buffer_and_caps() -> void:
	var m := _mine(1, 10.0, 1.0, 15.0, false)
	ProductionEngine.manual_mine_tap(m, 1.0)
	assert_almost(m.buffer, 10.0)
	ProductionEngine.manual_mine_tap(m, 1.0)     # +10 mais plafonné à 15
	assert_almost(m.buffer, 15.0)

func test_manual_warehouse_sell() -> void:
	var c := Continent.new()
	c.mult_permanent = 1.0
	c.warehouse = _warehouse(1000.0, 1000.0, false)
	c.warehouse.stock = 10.0
	c.warehouse.stock_value = 10.0
	var s := _state_with(c)
	var earned := ProductionEngine.manual_warehouse_sell(s, c, NOW)
	assert_almost(earned, 10.0)
	assert_almost(c.cash, 10.0)
	assert_almost(c.warehouse.stock, 0.0)

func test_elevator_priority_to_valuable_mines() -> void:
	# Ascenseur limité : doit d'abord évacuer la mine de plus grande valeur.
	var c := Continent.new()
	c.mult_permanent = 1.0
	var cheap := _mine(1, 0.0, 1.0, 1000.0, false)
	cheap.buffer = 100.0
	var rich := _mine(1, 0.0, 50.0, 1000.0, false)
	rich.buffer = 100.0
	c.mines.append(cheap)
	c.mines.append(rich)
	c.elevator = _elevator(100.0, 1.0)           # ne peut déplacer que 100 u/tick
	c.warehouse = _warehouse(10000.0, 0.0)       # stocke sans vendre
	var s := _state_with(c)

	ProductionEngine.tick(s, 1.0, NOW)
	assert_almost(rich.buffer, 0.0, 0.001, "mine de valeur évacuée en priorité")
	assert_almost(cheap.buffer, 100.0, 0.001, "mine bon marché laissée en attente")

func test_null_state_safe() -> void:
	var r := ProductionEngine.tick(null, 1.0, NOW)
	assert_almost(r.cash_gained, 0.0)
