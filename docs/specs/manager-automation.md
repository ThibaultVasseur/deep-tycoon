# Spec — Managers / Automatisation

Réf. : PRD §3.4.

## Objectif
Automatiser un composant (mine / ascenseur / entrepôt) une fois un niveau seuil atteint : plus besoin de taper, et production **hors-ligne** activée pour ce composant.

## Modèle — `game/core/manager.gd` (Resource)
| Champ | Type | Rôle |
|---|---|---|
| `id` | String | identifiant unique |
| `target_type` | enum | MINE / ELEVATOR / WAREHOUSE |
| `target_id` | int | index (pour les mines) |
| `hire_cost` | float | coût d'embauche (cash, ou super-cash si premium) |
| `unlock_level` | int | niveau min du composant pour débloquer l'embauche |
| `bonus_mult` | float | bonus optionnel de débit sur la cible (1.0 = aucun) |
| `hired` | bool | embauché ou non |

## Logique
- Embauche possible si `component.level >= unlock_level` et cash suffisant.
- À l'embauche : `component.has_manager = true`, applique `bonus_mult` au calcul de débit du composant.
- Permanent (survit aux saves ; **reset au prestige** sauf managers marqués premium — voir prestige-system).

## Impact sur le tick
- `has_manager == true` → le composant progresse en continu (pas de tap requis).
- Base du calcul **offline** : seuls les composants automatisés produisent hors-ligne (offline-earnings).

## Tests
- [ ] embauche refusée si `level < unlock_level` ou cash insuffisant.
- [ ] après embauche : `has_manager` vrai, `bonus_mult` appliqué au débit.
- [ ] composant automatisé compté dans le débit pipeline offline.
