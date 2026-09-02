extends TestCase

func test_expedition_reward_formula() -> void:
	# 20 min à 10 cash/s = 10 * 20 * 60 = 12000
	assert_almost(Economy.expedition_reward(10.0, 20.0), 12000.0)

func test_expedition_reward_zero_guards() -> void:
	assert_almost(Economy.expedition_reward(0.0, 20.0), 0.0)
	assert_almost(Economy.expedition_reward(-5.0, 20.0), 0.0)
	assert_almost(Economy.expedition_reward(10.0, 0.0), 0.0)

func test_expedition_fields_survive_save_roundtrip() -> void:
	var s := GameState.new_game(BalanceConfig.default())
	s.expedition_end_unix = 5000.0
	s.expedition_reward_cash = 777.0
	s.expedition_reward_super = 3
	var d := s.to_dict()
	var loaded := GameState.from_dict(d)
	assert_almost(loaded.expedition_end_unix, 5000.0)
	assert_almost(loaded.expedition_reward_cash, 777.0)
	assert_eq(loaded.expedition_reward_super, 3)
