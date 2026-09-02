# Spec — HUD & UI

Réf. : PRD §3.10, §4, §6.

## Objectif
UI claire et « premium » : HUD permanent, popups d'upgrade animées, indicateurs de bottleneck, chiffres formatés.

## HUD — `game/ui/hud.tscn` / `hud.gd`
- Haut d'écran : **cash actuel**, **cash/seconde**, **super-cash/gemmes**, bouton **prestige** (état « rentable » mis en valeur : glow/pulse quand `prestige_gain` devient intéressant).
- Se met à jour via signals du `game_controller` (`cash_changed`, `rate_changed`) — pas de polling.
- Tous les nombres via `NumberFormat.format()` (PRD §4 : 1.2K, 3.4M, 2.1B, aa…).

## Popups d'upgrade — `upgrade_popup.tscn`
- Composant réutilisable (mine / ascenseur / entrepôt) : nom, niveau, débit actuel → débit après upgrade, **coût formaté**, barre de progression animée, bouton acheter (désactivé si cash insuffisant).
- Achat multiple (×1 / ×10 / max) — option.

## Indicateurs de bottleneck
- Sur chaque maillon de la scène : icône/couleur signalant amont saturé vs aval bloqué (données du `production_engine`).

## Feedback (PRD §6)
- Pop numérique animé quand le cash augmente (tween scale+fade).
- Haptique sur tap productif (`haptics.gd`), son sur upgrade/vente/prestige (`audio_manager.gd`).
- Palette : tons terre + or, néon sur les upgrades.

## Style / thème
- Un `theme.tres` global (polices, couleurs, styleboxes des boutons/panels) pour l'identité « tycoon premium ».
- Layout responsive (safe areas Android/iOS).

## Tests
- Logique UI minimale (surtout du binding) → tests manuels + tests sur `NumberFormat` (unitaires) et sur les valeurs exposées par le `game_controller`.
