# Spec — Mine / Production

Réf. user stories & critères : PRD §3.1. Formules : PRD §5.

## Objectif
Chaque mine extrait une ressource à un débit fonction de son niveau. Upgradable au cash. Déblocable en profondeur avec un saut d'ordre de grandeur.

## Modèle de données — `game/core/mine.gd` (Resource)
| Champ | Type | Rôle |
|---|---|---|
| `id` | int | index du puits (0 = surface) |
| `resource_name` | String | "charbon", "or"… (cosmétique + prix) |
| `level` | int | niveau courant (0 = verrouillée) |
| `base_output` | float | unités/s au niveau 1 |
| `prod_growth` | float | croissance prod/niveau (≈1.07–1.12) |
| `base_cost` | float | coût du niveau 1 |
| `cost_growth` | float | croissance coût (≈1.15) |
| `unit_price` | float | valeur d'une unité de cette ressource |
| `has_manager` | bool | automatisée ou non |
| `buffer` | float | unités extraites en attente de l'ascenseur |
| `buffer_cap` | float | capacité tampon avant blocage amont |

## Logique — `economy.gd` (statique, pure)
```
output_per_sec(mine)  = mine.base_output * pow(mine.prod_growth, max(mine.level-1,0)) * global_mult
upgrade_cost(mine)    = mine.base_cost   * pow(mine.cost_growth, mine.level)
```
- `level == 0` → sortie 0 (mine verrouillée) ; « débloquer » = passer au niveau 1 en payant `base_cost`.
- Mine `k+1` : `base_output`/`unit_price` calibrés pour un produit **×50 à ×500** vs mine `k` (config, PRD §5).

## Comportement de tick (dans `production_engine.gd`)
- Si `has_manager` : `buffer += output_per_sec(mine) * delta`, plafonné à `buffer_cap` (surplus perdu = signal bottleneck amont).
- Sinon : l'extraction n'avance que sur tap joueur (ajoute un lot fixe au buffer + cooldown court).
- L'ascenseur puise dans `buffer` (voir elevator-transport).

## Scène / UI
- Représentation d'un puits dans `mine_scene.tscn` : sprite du filon, animation d'extraction, jauge de `buffer` (remplissage), bouton tap si non automatisée.
- Bouton d'upgrade (popup) affichant `upgrade_cost` formaté et le gain de débit.

## Cas limites
- Buffer plein sans manager d'ascenseur → aucun tap ne progresse (feedback « bloqué »).
- Multiplicateurs globaux (prestige/boost) appliqués **au calcul**, jamais stockés dans le buffer.

## Tests (`tests/test_economy.gd`)
- [ ] `output_per_sec` croît géométriquement avec le niveau.
- [ ] `upgrade_cost` suit `base_cost * cost_growth^level`.
- [ ] mine verrouillée (level 0) produit 0.
- [ ] saut ×50–×500 respecté entre deux mines consécutives de la config par défaut.
- [ ] buffer plafonné à `buffer_cap`.
