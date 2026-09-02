# Spec — Ascenseur / Transport

Réf. : PRD §3.2. Formules : PRD §5.

## Objectif
Vider les buffers des mines et livrer les unités à l'entrepôt. Débit = `capacité / vitesse`. Point de bottleneck central du jeu.

## Modèle — `game/core/elevator.gd` (Resource)
| Champ | Type | Rôle |
|---|---|---|
| `level` | int | niveau courant |
| `base_capacity` | float | unités/voyage niveau 1 |
| `capacity_growth` | float | croissance capacité/niveau |
| `base_speed` | float | secondes/voyage niveau 1 |
| `speed_growth` | float | réduction du temps/voyage (<1) |
| `base_cost` / `cost_growth` | float | coût upgrade |
| `has_manager` | bool | va-et-vient auto ou tap |
| `carrying` | float | charge en transit |

## Logique — `economy.gd`
```
capacity(elev) = elev.base_capacity * pow(elev.capacity_growth, elev.level-1)
trip_time(elev)= elev.base_speed   * pow(elev.speed_growth,   elev.level-1)   // speed_growth<1
throughput(elev)= capacity(elev) / trip_time(elev)                            // unités/s
```

## Tick (`production_engine.gd`)
Modèle simplifié « débit continu » (plus stable numériquement qu'une simulation voyage-par-voyage) :
- `pull = min(throughput(elev) * delta, somme des buffers mines, place dispo entrepôt)`
- retire `pull` des buffers mines (priorité aux mines profondes = plus de valeur), ajoute à l'entrepôt.
- Une couche visuelle (scène) rejoue l'animation des voyages à partir du débit, sans piloter l'économie.
- Sans manager : ne transporte que sur tap (déclenche un voyage de `capacity`).

## Détection de bottleneck
- `débitMines > throughput(elev)` → buffers mines saturent → **flag amont** (mines qui débordent).
- `entrepôt plein` → l'ascenseur ne peut plus déposer → **flag aval**.
- Le HUD/scene met en évidence le maillon limitant (PRD §3.10).

## Tests
- [ ] `throughput` = capacity/trip_time, croît avec le niveau.
- [ ] `speed_growth<1` réduit bien `trip_time`.
- [ ] `pull` borné par min(débit, buffers, place entrepôt).
- [ ] priorité de collecte aux mines de plus grande valeur.
