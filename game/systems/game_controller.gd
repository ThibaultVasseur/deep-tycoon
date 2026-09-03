## Cerveau du jeu (autoload "Game") : possède l'état, charge la save, applique le hors-ligne,
## fait tourner la boucle de tick, expose les actions à l'UI et sauvegarde à la sortie.
## L'UI lit les getters dans son propre _process et se reconstruit sur `structure_changed`.
## Réf : docs/specs/ui-hud.md, docs/PRD.md §7.
extends Node

signal structure_changed                         # niveaux/managers/prestige -> l'UI reconstruit
signal offline_ready(elapsed: float, gain: float) # gain hors-ligne significatif à afficher

enum Target { MINE, ELEVATOR, WAREHOUSE }

var state: GameState
var config: BalanceConfig

var _autosave_accum := 0.0
var _last_offline := {"elapsed": 0.0, "gain": 0.0}
var _offline_x2_available := false

var buy_mode := 1  # 1, 10, ou -1 (=Max)

func set_buy_mode(m: int) -> void:
	buy_mode = m
	structure_changed.emit()

## Nombre de niveaux + coût pour l'achat courant (selon buy_mode) sur un composant.
func planned_upgrade(base_cost: float, cost_growth: float, level: int) -> Dictionary:
	var count := buy_mode
	if buy_mode < 0:
		count = Economy.max_levels_affordable(base_cost, cost_growth, level, cash())
	count = maxi(count, 0)
	var cost := Economy.bulk_upgrade_cost(base_cost, cost_growth, level, count)
	return {"count": count, "cost": cost}

func planned_mine(i: int) -> Dictionary:
	var c := active()
	if c == null or i < 0 or i >= c.mines.size():
		return {"count": 0, "cost": INF}
	var m: Mine = c.mines[i]
	return planned_upgrade(m.base_cost, m.cost_growth, m.level)

func planned_elevator() -> Dictionary:
	var c := active()
	return planned_upgrade(c.elevator.base_cost, c.elevator.cost_growth, c.elevator.level) if c != null else {"count": 0, "cost": INF}

func planned_warehouse() -> Dictionary:
	var c := active()
	return planned_upgrade(c.warehouse.base_cost, c.warehouse.cost_growth, c.warehouse.level) if c != null else {"count": 0, "cost": INF}

func _ready() -> void:
	config = BalanceConfig.default()
	_load_or_new()
	get_tree().set_auto_accept_quit(false)  # on sauvegarde avant de quitter
	_apply_offline()
	set_process(true)

func _process(delta: float) -> void:
	if state == null:
		return
	ProductionEngine.tick(state, delta, now())
	_autosave_accum += delta
	if _autosave_accum >= config.autosave_interval_seconds:
		_autosave_accum = 0.0
		_save()

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST \
			or what == NOTIFICATION_APPLICATION_PAUSED \
			or what == NOTIFICATION_WM_GO_BACK_REQUEST:
		_save()
		if what == NOTIFICATION_WM_CLOSE_REQUEST:
			get_tree().quit()

# --- Cycle de vie ---

func _load_or_new() -> void:
	var loaded: GameState = SaveManager.load_state()
	if loaded == null:
		state = GameState.new_game(config)
		state.last_seen = now()  # nouvelle partie : pas de hors-ligne fictif
		_save()
	else:
		state = loaded

func _apply_offline() -> void:
	var r := OfflineCalculator.compute(state, now(), config)
	_last_offline = r
	if r.gain > 0.0:
		active().cash += r.gain
		_offline_x2_available = true
	state.last_seen = now()
	if r.elapsed >= config.min_offline_popup_seconds and r.gain > 0.0:
		offline_ready.emit(r.elapsed, r.gain)

func _save() -> void:
	if state == null:
		return
	state.last_seen = now()  # "temps depuis la dernière persistance" = base du hors-ligne
	SaveManager.save(state)

func now() -> float:
	return Time.get_unix_time_from_system()

# --- Getters pour l'UI ---

func active() -> Continent:
	return state.active() if state != null else null

func cash() -> float:
	var c := active()
	return c.cash if c != null else 0.0

func super_cash() -> float:
	return state.super_cash if state != null else 0.0

func cash_per_sec() -> float:
	var c := active()
	return Economy.cash_per_sec(state, c, now()) if c != null else 0.0

func boost_active() -> bool:
	return state != null and Economy.is_boost_active(state, now())

# --- Actions : mines ---

func tap_mine(i: int) -> void:
	var c := active()
	if c == null or i < 0 or i >= c.mines.size():
		return
	var m: Mine = c.mines[i]
	if not m.is_unlocked():
		return
	ProductionEngine.manual_mine_tap(m, config.manual_tap_seconds_worth)
	Haptics.tap()
	Audio.play_sfx("tap")

func upgrade_or_unlock_mine(i: int) -> bool:
	var c := active()
	if c == null or i < 0 or i >= c.mines.size():
		return false
	var m: Mine = c.mines[i]
	var p := planned_mine(i)
	if p.count <= 0 or c.cash < p.cost:
		return false
	c.cash -= p.cost
	m.level += p.count
	_after_change("upgrade")
	return true

# --- Actions : ascenseur / entrepôt (tap manuel + upgrade) ---

func tap_elevator() -> void:
	var c := active()
	if c != null:
		ProductionEngine.manual_elevator_trip(c)
		Haptics.tap()
		Audio.play_sfx("tap")

func tap_warehouse() -> void:
	var c := active()
	if c != null:
		ProductionEngine.manual_warehouse_sell(state, c, now())
		Haptics.tap()
		Audio.play_sfx("sell")

func upgrade_elevator() -> bool:
	var c := active()
	if c == null:
		return false
	var p := planned_elevator()
	if p.count <= 0 or c.cash < p.cost:
		return false
	c.cash -= p.cost
	c.elevator.level += p.count
	_after_change("upgrade")
	return true

func upgrade_warehouse() -> bool:
	var c := active()
	if c == null:
		return false
	var p := planned_warehouse()
	if p.count <= 0 or c.cash < p.cost:
		return false
	c.cash -= p.cost
	c.warehouse.level += p.count
	_after_change("upgrade")
	return true

# --- Actions : managers ---

func manager_cost(target: Target, i: int = 0) -> float:
	var c := active()
	if c == null:
		return INF
	match target:
		Target.MINE:
			if i < 0 or i >= c.mines.size():
				return INF
			return Economy.manager_hire_cost(Economy.mine_upgrade_cost(c.mines[i]), config.manager_cost_factor)
		Target.ELEVATOR:
			return Economy.manager_hire_cost(Economy.elevator_upgrade_cost(c.elevator), config.manager_cost_factor)
		Target.WAREHOUSE:
			return Economy.manager_hire_cost(Economy.warehouse_upgrade_cost(c.warehouse), config.manager_cost_factor)
	return INF

func _target_component(target: Target, i: int):
	var c := active()
	match target:
		Target.MINE:
			return c.mines[i] if (i >= 0 and i < c.mines.size()) else null
		Target.ELEVATOR:
			return c.elevator
		Target.WAREHOUSE:
			return c.warehouse
	return null

func can_hire_manager(target: Target, i: int = 0) -> bool:
	var comp = _target_component(target, i)
	if comp == null or comp.has_manager:
		return false
	if comp.level < config.manager_unlock_level:
		return false
	return cash() >= manager_cost(target, i)

func hire_manager(target: Target, i: int = 0) -> bool:
	if not can_hire_manager(target, i):
		return false
	var comp = _target_component(target, i)
	active().cash -= manager_cost(target, i)
	comp.has_manager = true
	_after_change("hire")
	Haptics.success()
	return true

# --- Prestige ---

func prestige_gain_preview() -> int:
	var c := active()
	if c == null:
		return 0
	return Economy.prestige_super_cash_gain(c.cash_total_earned, config.prestige_threshold, config.prestige_k)

func can_prestige() -> bool:
	return prestige_gain_preview() >= 1

func do_prestige() -> bool:
	var c := active()
	var gain := prestige_gain_preview()
	if gain < 1:
		return false
	state.super_cash += gain
	var new_mult: float = c.mult_permanent + Economy.prestige_mult_gain(gain, config.mult_gain_per_super_cash)

	# Reset du continent actif via son builder dédié, en conservant multiplicateur + statut débloqué.
	var fresh := Content.build_continent(c.id, config)
	fresh.mult_permanent = new_mult
	fresh.unlocked = c.unlocked
	fresh.cash = 0.0
	state.continents[state.active_continent] = fresh

	_after_change("prestige")
	Haptics.heavy()
	return true

# --- Continents ---

func continent_count() -> int:
	return state.continents.size() if state != null else 0

func continent_at(id: int) -> Continent:
	if state != null and id >= 0 and id < state.continents.size():
		return state.continents[id]
	return null

func continent_unlock_cost(id: int) -> int:
	return Content.continent_unlock_cost(id)

func can_unlock_continent(id: int) -> bool:
	var c := continent_at(id)
	return c != null and not c.unlocked and super_cash() >= Content.continent_unlock_cost(id)

func unlock_continent(id: int) -> bool:
	if not can_unlock_continent(id):
		return false
	state.super_cash -= Content.continent_unlock_cost(id)
	continent_at(id).unlocked = true
	_after_change("upgrade")
	return true

func switch_continent(id: int) -> bool:
	var c := continent_at(id)
	if c == null or not c.unlocked:
		return false
	state.active_continent = id
	structure_changed.emit()
	return true

# --- Pubs récompensées / boosts (non bloquant) ---

func request_boost() -> void:
	Ads.show_rewarded("boost_prod_x2", func(ok: bool):
		if ok:
			state.boost_end_unix = now() + config.boost_duration_seconds
			_after_change("boost"))

func can_claim_offline_double() -> bool:
	return _offline_x2_available and _last_offline.gain > 0.0

func claim_offline_double() -> void:
	if not can_claim_offline_double():
		return
	Ads.show_rewarded("offline_x2", func(ok: bool):
		if ok:
			active().cash += _last_offline.gain
			_offline_x2_available = false
			_after_change("offline_x2"))

func request_time_skip() -> void:
	Ads.show_rewarded("time_skip", func(ok: bool):
		if ok:
			var secs := config.time_skip_hours * 3600.0
			active().cash += cash_per_sec() * secs
			_after_change("time_skip"))

# --- Expéditions (événement) ---

## "idle" (dispo) | "running" (en cours) | "ready" (à récolter) | "cooldown"
func expedition_status() -> String:
	if state == null:
		return "idle"
	var t := now()
	if state.expedition_end_unix > 0.0:
		return "running" if t < state.expedition_end_unix else "ready"
	return "cooldown" if t < state.expedition_cooldown_end_unix else "idle"

## Secondes restantes avant fin d'expédition (running) ou fin de cooldown.
func expedition_time_left() -> float:
	var t := now()
	match expedition_status():
		"running":
			return maxf(state.expedition_end_unix - t, 0.0)
		"cooldown":
			return maxf(state.expedition_cooldown_end_unix - t, 0.0)
	return 0.0

func start_expedition() -> bool:
	if expedition_status() != "idle":
		return false
	# La récompense est fixée au lancement (taux courant) -> déterministe, marche hors-ligne.
	state.expedition_reward_cash = Economy.expedition_reward(cash_per_sec(), config.expedition_reward_minutes)
	state.expedition_reward_super = config.expedition_super_cash_reward
	state.expedition_end_unix = now() + config.expedition_duration_seconds
	_after_change("hire")
	return true

func collect_expedition() -> bool:
	if expedition_status() != "ready":
		return false
	active().cash += state.expedition_reward_cash
	state.super_cash += state.expedition_reward_super
	state.expedition_end_unix = 0.0
	state.expedition_reward_cash = 0.0
	state.expedition_reward_super = 0
	state.expedition_cooldown_end_unix = now() + config.expedition_cooldown_seconds
	_after_change("prestige")
	return true

# --- Interne ---

func _after_change(sfx: String) -> void:
	Audio.play_sfx(sfx)
	_save()
	structure_changed.emit()
