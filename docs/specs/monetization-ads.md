# Spec — Monétisation & Pubs (rewarded, non bloquantes)

Réf. : PRD §8. Priorité : feature i (dernière). **Le MVP est 100 % jouable sans pub ni achat.**

## Règle d'or (contrainte de design non négociable)
Les pubs sont **récompensées (rewarded), opt-in, et ne servent QU'À GAGNER DU TEMPS**.
- ❌ Jamais de pub interstitielle imposée, jamais de pub qui bloque/gate la progression.
- ❌ Aucun contenu (mine, continent, manager, prestige) accessible *uniquement* via pub.
- ✅ Chaque pub = un accélérateur optionnel qui compresse du temps que le joueur aurait obtenu en jouant.
- ✅ Un joueur no-ads / no-IAP peut atteindre 100 % du contenu, juste plus lentement.

## Pubs récompensées (rewarded video)
| ID | Effet | Déclenchement | Garde-fous |
|---|---|---|---|
| `offline_x2` | Double le gain hors-ligne affiché | Bouton sur la popup de retour offline | 1×/retour ; sinon crédit normal déjà acquis |
| `boost_prod_x2` | ×2 production+vente pendant `boost_duration` (ex : 15 min) | Bouton HUD dédié | Cooldown entre deux ; ne stacke pas avec lui-même (prolonge) |
| `time_skip` | Crédite `skip_hours` de production instantanée | Bouton HUD | Cooldown ; borné par le débit auto courant |
| `upgrade_discount` | -X% (ou gratuit) sur la prochaine upgrade | Sur la popup d'upgrade | 1 charge à la fois |

Toutes les valeurs (`boost_duration`, `skip_hours`, discount, cooldowns) vivent dans `balance_config`.

## Achats intégrés (IAP)
| ID | Effet |
|---|---|
| `perm_x2` | Multiplicateur global **permanent** ×2 (définitif) |
| `remove_ads` | Retire les pubs ; les boosts rewarded deviennent activables **sans** pub (gratuits, mêmes cooldowns) |
| `supercash_pack_*` | Packs de super-cash / gemmes |
| `offline_cap_ext` | Étend le cap hors-ligne (ex : 8h → 24h) |

`remove_ads` ne doit **jamais** retirer l'accès aux boosts : il enlève seulement la vidéo.

## Architecture (Godot / Android)
- `game/systems/ads_manager.gd` (autoload) : abstraction `request_rewarded(id, on_reward)`, `is_ready(id)`.
  - Implémentation Android via plugin AdMob (Google Mobile Ads) ; **stub** en éditeur/desktop (récompense immédiate simulée) pour dev/test sous Windows.
- `game/systems/iap_manager.gd` (autoload) : Google Play Billing ; **stub** desktop.
- Les managers exposent des **signals** ; le gameplay ne dépend jamais d'une réponse pub (si la pub échoue/indispo → action simplement indisponible, aucun blocage).
- Multiplicateurs (`perm_x2`, boosts) appliqués dans `economy.gd` via des champs de `GameState` → **testables** sans SDK pub.

## Cas limites
- Pub non chargée / réseau absent → bouton grisé « indisponible », le jeu continue normalement.
- Récompense reçue mais app tuée avant crédit → re-créditer au prochain lancement (flag `pending_reward`).
- `boost` en cours à la sauvegarde → persister `boost_end_timestamp`, recalculer au chargement (peut expirer hors-ligne).

## Tests (`tests/test_monetization.gd`, logique pure via stubs)
- [ ] `offline_x2` double bien le gain calculé, une seule fois.
- [ ] boost actif → multiplicateur appliqué dans `economy` ; expire à `boost_end_timestamp`.
- [ ] `perm_x2` empilé correctement avec le multiplicateur de prestige.
- [ ] `remove_ads` = boosts activables sans pub, mêmes cooldowns.
- [ ] échec pub → aucune mutation d'état, aucun blocage.
