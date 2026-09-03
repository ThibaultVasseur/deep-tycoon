extends TestCase

func test_build_all_continents() -> void:
	var arr := Content.build_all_continents(BalanceConfig.default())
	assert_eq(arr.size(), Content.continent_count())
	assert_true(arr[0].unlocked, "le 1er continent est débloqué")
	for i in range(1, arr.size()):
		assert_false(arr[i].unlocked, "continent %d verrouillé au départ" % i)

func test_continent_metadata() -> void:
	var cfg := BalanceConfig.default()
	var c1 := Content.build_continent(1, cfg)
	assert_eq(c1.id, 1)
	assert_almost(c1.cash, 0.0, 0.0001, "continents >0 démarrent sans cash")
	assert_gt(Content.continent_unlock_cost(1), 0.0, "déblocage coûte du super-cash")
	assert_eq(Content.continent_unlock_cost(0), 0)

func test_continent_ore_names_differ() -> void:
	var cfg := BalanceConfig.default()
	var c0 := Content.build_continent(0, cfg)
	var c1 := Content.build_continent(1, cfg)
	assert_ne(c0.mines[0].ore_name, c1.mines[0].ore_name)

func test_floor_scaling_each_continent() -> void:
	var cfg := BalanceConfig.default()
	for id in Content.continent_count():
		var c := Content.build_continent(id, cfg)
		assert_eq(c.mines.size(), cfg.floors_per_continent, "continent %d a N étages" % id)
		for i in range(c.mines.size() - 1):
			var ratio := c.mines[i + 1].unit_price / c.mines[i].unit_price
			assert_almost(ratio, cfg.floor_value_factor, 0.001, "continent %d étage %d" % [id, i])

func test_out_of_range_id_clamped() -> void:
	var cfg := BalanceConfig.default()
	var c := Content.build_continent(999, cfg)
	assert_eq(c.id, Content.continent_count() - 1)
