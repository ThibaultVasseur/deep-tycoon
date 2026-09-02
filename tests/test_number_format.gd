extends TestCase

func test_small_numbers_are_integers() -> void:
	assert_eq(NumberFormat.format(0.0), "0")
	assert_eq(NumberFormat.format(7.0), "7")
	assert_eq(NumberFormat.format(523.9), "523")
	assert_eq(NumberFormat.format(999.0), "999")

func test_thousands_and_millions() -> void:
	assert_eq(NumberFormat.format(1000.0), "1K")
	assert_eq(NumberFormat.format(1234.0), "1.23K")
	assert_eq(NumberFormat.format(12340.0), "12.3K")
	assert_eq(NumberFormat.format(3_400_000.0), "3.4M")
	assert_eq(NumberFormat.format(2_100_000_000.0), "2.1B")

func test_trillions_and_beyond() -> void:
	assert_eq(NumberFormat.format(1.0e12), "1T")
	# 10^15 = 1000T -> premier palier alphabétique "aa"
	assert_eq(NumberFormat.format(1.0e15), "1aa")

func test_negatives() -> void:
	assert_eq(NumberFormat.format(-1500.0), "-1.5K")
	assert_eq(NumberFormat.format(-42.0), "-42")

func test_nan_inf_safe() -> void:
	assert_eq(NumberFormat.format(NAN), "0")
	assert_eq(NumberFormat.format(INF), "0")

func test_rounding_edge_bumps_tier() -> void:
	# 999_960 arrondi à 3 sig -> ne doit pas donner "1000K" mais "1M".
	assert_eq(NumberFormat.format(999_960.0), "1M")

func test_duration() -> void:
	assert_eq(NumberFormat.format_duration(0.0), "0s")
	assert_eq(NumberFormat.format_duration(42.0), "42s")
	assert_eq(NumberFormat.format_duration(125.0), "2m 05s")
	assert_eq(NumberFormat.format_duration(3720.0), "1h 02m")
