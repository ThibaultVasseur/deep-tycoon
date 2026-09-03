extends TestCase

func _mine(level: int, base_out := 10.0, growth := 1.10) -> Mine:
	var m := Mine.new()
	m.level = level
	m.base_output = base_out
	m.prod_growth = growth
	m.base_cost = 10.0
	m.cost_growth = 1.15
	m.unit_price = 1.0
	return m

func test_mine_output_grows_geometrically() -> void:
	var m1 := _mine(1)
	var m2 := _mine(2)
	var m3 := _mine(3)
	assert_almost(Economy.mine_output_per_sec(m1), 10.0)
	assert_almost(Economy.mine_output_per_sec(m2), 11.0)      # 10 * 1.1
	assert_almost(Economy.mine_output_per_sec(m3), 12.1)      # 10 * 1.1^2

func test_locked_mine_produces_zero() -> void:
	assert_almost(Economy.mine_output_per_sec(_mine(0)), 0.0)

func test_upgrade_cost_curve() -> void:
	var m := _mine(0)  # base_cost=10, growth=1.15
	assert_almost(Economy.mine_upgrade_cost(m), 10.0)         # level 0 -> 10 * 1.15^0
	m.level = 1
	assert_almost(Economy.mine_upgrade_cost(m), 11.5)         # 10 * 1.15^1
	m.level = 5
	assert_almost(Economy.mine_upgrade_cost(m), 10.0 * pow(1.15, 5))

func test_elevator_throughput() -> void:
	var e := Elevator.new()
	e.level = 1
	e.base_capacity = 20.0
	e.base_speed = 2.0        # trip_time = 2s
	e.speed_growth = 1.0      # pas de réduction au niveau 1
	assert_almost(Economy.elevator_throughput(e), 10.0)       # 20 / 2

func test_elevator_speed_growth_reduces_trip_time() -> void:
	var e := Elevator.new()
	e.base_speed = 4.0
	e.speed_growth = 0.5
	e.min_speed = 0.01
	e.level = 3
	assert_almost(Economy.elevator_trip_time(e), 4.0 * pow(0.5, 2))  # 4 * 0.25 = 1.0

func test_elevator_min_speed_floor() -> void:
	var e := Elevator.new()
	e.base_speed = 4.0
	e.speed_growth = 0.1
	e.min_speed = 0.5
	e.level = 10
	assert_almost(Economy.elevator_trip_time(e), 0.5)        # planché

func test_warehouse_rates() -> void:
	var w := Warehouse.new()
	w.level = 1
	w.base_sell_rate = 5.0
	w.sell_rate_growth = 1.2
	assert_almost(Economy.warehouse_sell_rate(w), 5.0)
	w.level = 3
	assert_almost(Economy.warehouse_sell_rate(w), 5.0 * pow(1.2, 2))

func test_cash_multiplier_stacks() -> void:
	var s := GameState.new()
	var c := Continent.new()
	c.mult_permanent = 3.0
	s.global_sell_mult = 2.0
	s.perm_x2 = true
	s.boost_factor = 2.0
	s.boost_end_unix = 100.0
	# now < boost_end -> boost actif : 3 * 2 * 2(perm) * 2(boost) = 24
	assert_almost(Economy.cash_multiplier(s, c, 50.0), 24.0)
	# now >= boost_end -> boost inactif : 3 * 2 * 2 = 12
	assert_almost(Economy.cash_multiplier(s, c, 150.0), 12.0)

func test_floor_value_factor_between_floors() -> void:
	var cfg := BalanceConfig.default()
	var cont := Content.build_first_continent(cfg)
	assert_eq(cont.mines.size(), cfg.floors_per_continent, "15 étages par défaut")
	for i in range(cont.mines.size() - 1):
		var ratio := cont.mines[i + 1].unit_price / cont.mines[i].unit_price
		assert_almost(ratio, cfg.floor_value_factor, 0.001, "valeur étage %d->%d" % [i, i + 1])

func test_floor_cost_increases() -> void:
	var cont := Content.build_first_continent(BalanceConfig.default())
	for i in range(cont.mines.size() - 1):
		assert_gt(cont.mines[i + 1].base_cost, cont.mines[i].base_cost, "étage plus profond plus cher")

func test_bulk_upgrade_cost() -> void:
	assert_almost(Economy.bulk_upgrade_cost(10.0, 1.15, 0, 1), 10.0)
	# 10*(1 + 1.15 + 1.15^2) = 34.725
	assert_almost(Economy.bulk_upgrade_cost(10.0, 1.15, 0, 3), 34.725, 0.01)
	# croissance 1.0 -> coût linéaire
	assert_almost(Economy.bulk_upgrade_cost(10.0, 1.0, 0, 5), 50.0)
	assert_almost(Economy.bulk_upgrade_cost(10.0, 1.15, 0, 0), 0.0)

func test_max_levels_affordable() -> void:
	assert_eq(Economy.max_levels_affordable(10.0, 1.15, 0, 35.0), 3)
	assert_eq(Economy.max_levels_affordable(10.0, 1.15, 0, 5.0), 0)
	assert_eq(Economy.max_levels_affordable(10.0, 1.0, 0, 55.0), 5)
	assert_eq(Economy.max_levels_affordable(10.0, 1.15, 0, -1.0), 0)

func test_prestige_gain_curve() -> void:
	# threshold=1e6, k=10 : sous le seuil -> 0
	assert_eq(Economy.prestige_super_cash_gain(999_999.0, 1.0e6, 10.0), 0)
	# à 4x le seuil : floor(10 * sqrt(4)) = 20
	assert_eq(Economy.prestige_super_cash_gain(4.0e6, 1.0e6, 10.0), 20)

func test_pipeline_bottleneck_is_min() -> void:
	var cont := Content.build_first_continent(BalanceConfig.default())
	cont.mines[0].has_manager = true
	cont.elevator.has_manager = true
	cont.warehouse.has_manager = true
	var units := Economy.pipeline_units_per_sec(cont, true)
	var mn: float = Economy.mine_output_per_sec(cont.mines[0])
	var el: float = Economy.elevator_throughput(cont.elevator)
	var wh: float = Economy.warehouse_sell_rate(cont.warehouse)
	assert_almost(units, minf(mn, minf(el, wh)))

func test_pipeline_zero_if_not_fully_automated() -> void:
	var cont := Content.build_first_continent(BalanceConfig.default())
	cont.mines[0].has_manager = true
	cont.elevator.has_manager = true
	cont.warehouse.has_manager = false   # maillon manquant
	assert_almost(Economy.pipeline_units_per_sec(cont, true), 0.0)
