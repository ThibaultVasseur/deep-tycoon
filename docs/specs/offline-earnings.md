# Spec — Cash idle / Production hors-ligne

Réf. : PRD §3.5. Formule : PRD §5.

## Objectif
Créditer un gain à la reprise de l'app, proportionnel au temps écoulé, au débit du pipeline **automatisé**, réduit par un facteur idle et plafonné dans le temps.

## Entrées
- `last_seen_timestamp` (Unix, sauvegardé à la mise en arrière-plan / fermeture).
- `now` (au lancement).
- `GameState` (mines/ascenseur/entrepôt + managers).
- Config : `offline_cap_seconds` (défaut 8h = 28800, extensible ≤12h+), `idle_factor` (défaut 0.5).

## Logique — `game/core/offline_calculator.gd` (statique, pure)
```
elapsed        = clamp(now - last_seen, 0, offline_cap_seconds)
auto_throughput= min(débitMines_auto, throughput_ascenseur_auto, sell_rate_entrepôt_auto)
                 // uniquement les composants avec has_manager == true
gain           = auto_throughput * prix_moyen * idle_factor * elapsed
```
- Si un maillon du pipeline n'est pas automatisé → il casse la chaîne offline (throughput de ce maillon = 0 → gain 0). C'est voulu : il faut automatiser toute la chaîne pour un vrai revenu hors-ligne.

## Sortie / UX
- Popup de retour : durée absente (formatée « 3h 12m »), montant gagné (formaté), bouton **« ×2 (pub) »** rewarded — voir `monetization-ads.md` (`offline_x2`), non bloquant.
- Créditer le cash **une seule fois** puis mettre à jour `last_seen`. Le ×2 est un crédit **additionnel** appliqué après visionnage (avec `pending_reward` en cas de crash).

## Cas limites
- `elapsed <= 0` (horloge reculée / triche) → gain 0, pas de crédit négatif.
- Absence < seuil (ex : 60s) → pas de popup (crédit silencieux).
- Cap appliqué strictement (au-delà de 8–12h, plus de gain).

## Tests (`tests/test_offline.gd`)
- [ ] gain = throughput_auto * prix * idle_factor * elapsed.
- [ ] elapsed clampé à `offline_cap_seconds`.
- [ ] pipeline partiellement automatisé → gain 0 (maillon manquant).
- [ ] `now < last_seen` → gain 0.
- [ ] idle_factor et cap lus depuis la config (modifiables).
