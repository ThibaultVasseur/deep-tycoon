# Roadmap de tâches — Deep Tycoon

## STATUT (mis à jour)
- ✅ **0. Setup** : projet Godot 4.7, arbo, framework de test maison, `.gitignore`.
- ✅ **a. Cœur logique** : modèles, `economy`, `production_engine`, `number_format` — testé.
- ✅ **b. Pipeline + bottleneck** : flux mine→ascenseur→entrepôt, priorité valeur, flags amont/aval — testé.
- ✅ **c. Save + offline** : JSON chiffré + HMAC + atomique + reset sûr ; offline + anti-horloge — testé.
- ✅ **d. UI HUD + upgrades** : `game_controller`, HUD, colonnes interactives, popups, popup offline.
- ✅ **f. Managers** : logique d'embauche + UI (intégré tôt car naturel).
- ✅ **g. Prestige** : gain super-cash + multiplicateur permanent + reset continent + bouton UI.
- ✅ **e. Scène 2D animée** : puits, ascenseur + wagonnet animé, lueur d'extraction, particules de pièces (SubViewport).
- 🟡 **h. Polish** : haptics + pop du cash + particules de vente OK ; audio en stub (assets à fournir) ; d'autres tweens possibles.
- 🟡 **i. Monétisation** : `Ads`/IAP en **stubs desktop** (jouable/testable) ; plugins Android réels + leaderboard à brancher (voir `docs/ANDROID.md`).
- ✅ **Contenu** : continents multiples (débloqués au super-cash) + **expéditions** (événement, marche hors-ligne).
- 📄 **Android** : chemin de build documenté (`docs/ANDROID.md`) — reste le téléchargement des templates (~1 Go) + keystore (action requise de ta part).

**Tests : 46/46 verts** (`godot --headless --script res://tests/run_tests.gd`).

---

Ordre imposé par le PRD §11. Effort : S (≤2h) / M (≈½ j) / L (≈1 j). Chaque feature se termine par : tests verts → build headless → validation → suivant.

---

## 0. Setup projet — **prérequis**
- [ ] Installer Godot 4 (scoop) — *bloquant pour build/test*. **S**
- [ ] `project.godot` + arbo `game/{core,systems,scenes,ui}` + `tests/`. **S**
- [ ] Installer l'addon **GUT** (tests unitaires) + config `--headless`. **S**
- [ ] `.gitignore` Godot, commit initial du scaffold. **S**
> Dépendances : aucune. Débloque tout le reste.

## a. Cœur logique (modèles + moteur de tick) — **feature 1**
Specs : mine-production, elevator-transport, warehouse-conversion (partie formules).
- [ ] `balance_config.gd` (Resource) : toutes les constantes d'équilibrage (PRD §5). **S**
- [ ] `number_format.gd` : `format(value)` (K/M/B/T/aa…). **S**
- [ ] `economy.gd` : `output_per_sec`, `upgrade_cost`, `throughput`, `sell_rate`, `prestige_gain`. **M**
- [ ] Modèles Resource : `mine`, `elevator`, `warehouse`, `manager`, `continent`, `game_state`. **M**
- [ ] `production_engine.gd` : `tick(state, delta)` pur (pipeline + bottleneck). **L**
- [ ] Tests : `test_number_format`, `test_economy`, `test_production_engine`. **M**
> Dépendances : 0. **Livrable clé** : boucle mathématique jouable et testée sans UI.

## b. Pipeline mine→ascenseur→entrepôt + bottleneck — **feature 2**
- [ ] Priorité de collecte ascenseur (mines de plus grande valeur). **S**
- [ ] Propagation du blocage aval (entrepôt plein → ascenseur → mines). **M**
- [ ] Flags de bottleneck exposés par le moteur. **S**
- [ ] Tests de scénarios de bottleneck (amont/aval). **M**
> Dépendances : (a).

## c. Sauvegarde + idle offline — **feature 3**
Specs : save-system, offline-earnings.
- [ ] `game_state.to_dict/from_dict` + `schema_version`. **S**
- [ ] `save_manager.gd` (autoload) : save atomique JSON, load, migration. **M**
- [ ] `offline_calculator.gd` + hook au lancement. **M**
- [ ] Save sur pause/fermeture + autosave périodique. **S**
- [ ] Tests : `test_save` (round-trip, corrompu, migration), `test_offline`. **M**
> Dépendances : (a).

## d. UI HUD + popups d'upgrade — **feature 4**
Spec : ui-hud.
- [ ] `game_controller.gd` (autoload) : possède l'état, boucle `_process` → tick, signals. **M**
- [ ] `hud.tscn` : cash, cash/s, super-cash, bouton prestige. **M**
- [ ] `upgrade_popup.tscn` réutilisable (×1/×10/max). **M**
- [ ] Pop numérique + états désactivés. **S**
- [ ] `theme.tres` (identité premium). **M**
> Dépendances : (a), (c).

## e. Scène SpriteKit-like animée — **feature 5**
- [ ] `mine_scene.tscn` : puits empilés, filons, jauges de buffer. **L**
- [ ] Ascenseur animé + wagonnets (rejoue le débit). **M**
- [ ] Particules pièces/or à la vente. **M**
- [ ] Indicateurs de bottleneck visuels. **S**
> Dépendances : (b), (d).

## f. Managers (automatisation) — **feature 6**
Spec : manager-automation.
- [ ] Modèle + règles d'embauche (seuil niveau, coût). **S**
- [ ] Bascule `has_manager` + `bonus_mult` dans le calcul. **S**
- [ ] UI d'embauche. **M**
- [ ] Tests d'embauche + impact offline. **S**
> Dépendances : (a), (c), (d).

## g. Prestige — **feature 7**
Spec : prestige-system.
- [ ] `prestige_gain` + reset/conserve. **M**
- [ ] Bonus super-cash (`prestige_upgrades`). **M**
- [ ] UI confirmation + écran de bonus. **M**
- [ ] Tests reset/conservation/multiplicateurs. **S**
> Dépendances : (a), (c), (d).

## h. Polish (visuel, sons, haptics) — **feature 8**
- [ ] `audio_manager.gd` + `haptics.gd` (structure même sans assets finaux). **M**
- [ ] Tweens (barres, transitions, pop cash). **M**
- [ ] Équilibrage : ajuster `balance_config` après playtest. **M**
> Dépendances : tout le gameplay.

## i. Monétisation (pubs rewarded + IAP) + leaderboard — **feature 9 (dernier)**
Spec : monetization-ads. **Règle d'or : rewarded / opt-in / non bloquant** (jamais de gate de progression).
- [ ] `ads_manager.gd` + `iap_manager.gd` (autoloads) avec **stubs desktop** (récompense simulée) pour tester sous Windows. **M**
- [ ] Multiplicateurs (`perm_x2`, boosts, `offline_x2`) dans `GameState`/`economy` — **testables sans SDK**. **M**
- [ ] Rewarded : `offline_x2`, `boost_prod_x2`, `time_skip`, `upgrade_discount` (cooldowns via config). **M**
- [ ] Plugin AdMob (Google Mobile Ads) + Google Play Billing côté Android. **L**
- [ ] Leaderboard (Play Games Services) — cash total ; équivalents iOS StoreKit/GameKit au portage. **L**
- [ ] Tests `test_monetization` (boosts, x2, échec pub sans blocage). **S**
> Dépendances : gameplay complet. Non bloquant pour un MVP jouable.

---

### Post-MVP (PRD §3.7, §3.8)
- Continents multiples (monnaie propre + saut d'ordre de grandeur).
- Événements temporaires & expéditions.
- Cosmétiques.
