## Formatage des nombres pour l'affichage idle (K/M/B/T puis aa, ab, ...).
## Fonctions pures et statiques -> testables sans UI (voir tests/test_number_format.gd).
## Réf : docs/PRD.md §4.
class_name NumberFormat
extends RefCounted

const SUFFIXES := ["", "K", "M", "B", "T"]

## Formate une valeur numérique en chaîne compacte à ~3 chiffres significatifs.
## Ex : 999 -> "999", 1234 -> "1.23K", 3_400_000 -> "3.4M".
static func format(value: float) -> String:
	if is_nan(value) or is_inf(value):
		return "0"
	var neg := value < 0.0
	var v := absf(value)
	if v < 1000.0:
		# Cash lisible : entier sous 1000.
		return ("-" if neg else "") + str(int(floor(v)))

	var tier := int(floor(log(v) / log(1000.0)))
	var scaled := v / pow(1000.0, tier)
	# Garde-fou : si l'arrondi d'affichage remonte à 1000, on passe au palier supérieur.
	if scaled >= 999.5:
		tier += 1
		scaled = v / pow(1000.0, tier)

	return ("-" if neg else "") + _mantissa(scaled) + _suffix_for_tier(tier)

## Mantisse à 3 chiffres significatifs, zéros de fin supprimés.
static func _mantissa(scaled: float) -> String:
	var s: String
	if scaled >= 100.0:
		s = "%.0f" % scaled
	elif scaled >= 10.0:
		s = "%.1f" % scaled
	else:
		s = "%.2f" % scaled
	if s.contains("."):
		s = s.rstrip("0").rstrip(".")
	return s

## Suffixe pour un palier : 1=K, 2=M, 3=B, 4=T, puis aa, ab, ... (notation idle).
static func _suffix_for_tier(tier: int) -> String:
	if tier <= 0:
		return ""
	if tier < SUFFIXES.size():
		return SUFFIXES[tier]
	var n := tier - SUFFIXES.size()  # 0 -> "aa"
	var c1 := n / 26
	var c2 := n % 26
	if c1 > 25:
		return "e%d" % tier  # au-delà : notation de secours, jamais atteint en pratique
	return char(97 + c1) + char(97 + c2)

## Formate une durée en secondes -> "3h 12m" / "5m 09s" / "42s".
static func format_duration(seconds: float) -> String:
	var s := int(max(seconds, 0.0))
	var h := s / 3600
	var m := (s % 3600) / 60
	var sec := s % 60
	if h > 0:
		return "%dh %02dm" % [h, m]
	if m > 0:
		return "%dm %02ds" % [m, sec]
	return "%ds" % sec
