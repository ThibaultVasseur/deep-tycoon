## Classe de base des tests (framework maison, zéro dépendance externe).
## Les méthodes commençant par "test_" sont exécutées par tests/run_tests.gd.
class_name TestCase
extends RefCounted

var _failures: Array[String] = []
var _checks := 0

func assert_true(cond: bool, msg := "") -> void:
	_checks += 1
	if not cond:
		_failures.append("assert_true a échoué. %s" % msg)

func assert_false(cond: bool, msg := "") -> void:
	assert_true(not cond, msg)

func assert_eq(a, b, msg := "") -> void:
	_checks += 1
	if a != b:
		_failures.append("assert_eq: %s != %s. %s" % [str(a), str(b), msg])

func assert_ne(a, b, msg := "") -> void:
	_checks += 1
	if a == b:
		_failures.append("assert_ne: %s == %s. %s" % [str(a), str(b), msg])

func assert_almost(a: float, b: float, eps := 0.0001, msg := "") -> void:
	_checks += 1
	if absf(a - b) > eps:
		_failures.append("assert_almost: %f vs %f (eps=%f). %s" % [a, b, eps, msg])

func assert_gt(a: float, b: float, msg := "") -> void:
	_checks += 1
	if not (a > b):
		_failures.append("assert_gt: %f <= %f. %s" % [a, b, msg])

func assert_ge(a: float, b: float, msg := "") -> void:
	_checks += 1
	if not (a >= b):
		_failures.append("assert_ge: %f < %f. %s" % [a, b, msg])

func assert_lt(a: float, b: float, msg := "") -> void:
	_checks += 1
	if not (a < b):
		_failures.append("assert_lt: %f >= %f. %s" % [a, b, msg])

func assert_between(x: float, lo: float, hi: float, msg := "") -> void:
	_checks += 1
	if x < lo or x > hi:
		_failures.append("assert_between: %f hors [%f, %f]. %s" % [x, lo, hi, msg])
