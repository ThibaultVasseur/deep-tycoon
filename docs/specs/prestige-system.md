# Spec — Prestige (par continent)

Réf. : PRD §3.6, §12. Formule : PRD §5.

## Objectif
Reset volontaire **du continent actif** contre : un **multiplicateur de cash permanent** (empilable) + une somme de **super-cash mondial**. Le super-cash débloque les autres continents et achète les bonus globaux. Jalon **long** à atteindre (« pas facile »).

## Logique — `economy.gd`
```
super_cash_gain(cash_total_continent) = floor(k * sqrt(cash_total_continent / prestige_threshold))
mult_gain(super_cash_gain)            = bonus_mult_par_prestige * super_cash_gain   // s'ajoute à mult_permanent
```
- `prestige_threshold` volontairement **élevé** → prestige rare et significatif.
- Bouton prestige visible dès `super_cash_gain >= 1` ; mis en avant (« rentable ») quand le gain dépasse un multiple du super-cash courant (ex : +25 %).

## Ce que le prestige RESET (continent actif uniquement)
- cash local du continent, niveaux mines/ascenseur/entrepôt, buffers/stock, managers non-premium de ce continent.

## Ce que le prestige CONSERVE
- **super-cash mondial** (+ `super_cash_gain`), **`mult_permanent`** (+ `mult_gain`, empilé run après run),
  continents déjà débloqués, bonus globaux achetés, IAP (`perm_x2`, remove_ads…), succès/leaderboard.

## Multiplicateur permanent
- `mult_permanent` (dans `GameState`, global ou par continent — **proposition : par continent**) multiplie production+vente de la run suivante.
- S'empile à chaque prestige → chaque cycle rend le redémarrage bien plus rapide (« bon multiplicateur »).

## Super-cash — usages (`game/core/prestige_upgrades.gd`)
- **Débloquer un continent** (coût en super-cash, croissant par continent).
- Bonus globaux : `global_prod_mult`, `global_sell_mult`, `offline_cap_bonus` (+h), `idle_factor_bonus` (+%), `start_cash`.
- Chaque bonus : coût super-cash croissant, effet appliqué dans `economy.gd`.

## UX
- Écran de confirmation : « Tu vas gagner X super-cash et +Y× permanent, et réinitialiser ce continent. Continuer ? »
- Animation de reset + récap des multiplicateurs actifs + continents débloquables.

## Tests (`tests/test_economy.gd`)
- [ ] `super_cash_gain` suit la courbe racine ; 0 sous le seuil (seuil élevé respecté).
- [ ] reset : remet à zéro les champs du continent, conserve super-cash / `mult_permanent` / continents.
- [ ] `mult_permanent` s'empile correctement sur plusieurs prestiges.
- [ ] `mult_permanent` + `perm_x2` (IAP) se combinent dans le calcul.
- [ ] déblocage de continent débité en super-cash.
