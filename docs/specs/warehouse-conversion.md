# Spec — Entrepôt / Conversion

Réf. : PRD §3.3. Formules : PRD §5.

## Objectif
Stocker les unités livrées par l'ascenseur, puis les vendre contre du cash au fil de l'eau.

## Modèle — `game/core/warehouse.gd` (Resource)
| Champ | Type | Rôle |
|---|---|---|
| `level` | int | niveau courant |
| `base_store_cap` | float | capacité de stock niveau 1 |
| `store_cap_growth` | float | croissance capacité/niveau |
| `base_sell_rate` | float | unités/s vendues niveau 1 |
| `sell_rate_growth` | float | croissance vitesse de vente |
| `base_cost` / `cost_growth` | float | coût upgrade |
| `has_manager` | bool | vente auto ou tap |
| `stock` | float | unités en stock (par ressource si multi-ressources) |

## Logique — `economy.gd`
```
store_cap(w) = w.base_store_cap * pow(w.store_cap_growth, w.level-1)
sell_rate(w) = w.base_sell_rate * pow(w.sell_rate_growth, w.level-1)   // unités/s
```

## Tick (`production_engine.gd`)
- `sold = min(w.stock, sell_rate(w) * delta)`
- `cash += sold * unit_price_moyen` (ou par ressource) `* global_sell_mult`
- `w.stock -= sold`
- L'ascenseur ne peut déposer que jusqu'à `store_cap(w)` (sinon flag aval).
- Sans manager : vente seulement sur tap (vend un lot ou vide partiellement).

## Cas limites
- Entrepôt plein → propage le bottleneck en amont (ascenseur bloqué → mines bloquées).
- Multi-ressources (continents) : stock et prix séparés par ressource ; `cashParSeconde` = somme.

## Tests
- [ ] `store_cap`/`sell_rate` croissent avec le niveau.
- [ ] `sold` borné par min(stock, sell_rate*delta).
- [ ] cash crédité = sold * prix * mult.
- [ ] dépôt refusé au-delà de `store_cap`.
