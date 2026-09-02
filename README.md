# Deep Tycoon 🪏

Jeu **idle / incremental** de minage (clone inspiré d'Idle Miner Tycoon), développé en **Godot 4** (GDScript).
Cible principale : **Google Play (Android)** ; iOS en cible secondaire.

Boucle centrale : **Mines → Ascenseur → Entrepôt → Cash**, où le cœur du jeu est de repérer et corriger
les **goulots d'étranglement** entre les trois maillons, puis d'**automatiser** (managers), d'encaisser du
**revenu hors-ligne**, et de **prestige** pour progresser sur le long terme.

## Prérequis
- **Godot 4.7+** (headless inclus). Installé ici via `scoop install godot`.

## Lancer le jeu
```bash
godot --path .            # ou ouvrir le dossier dans l'éditeur Godot puis F5
```

## Lancer les tests (headless, aucune dépendance externe)
```bash
godot --headless --import
godot --headless --script res://tests/run_tests.gd
```
Code de sortie 0 si tout passe, 1 sinon (utilisable en CI). Actuellement **38 tests verts**.

## Architecture
```
game/
  core/        # LOGIQUE PURE, sans dépendance moteur -> 100% testable en headless
    balance_config.gd    # toutes les constantes d'équilibrage (source unique)
    economy.gd           # formules (production, coûts, débit, prestige, multiplicateurs)
    number_format.gd     # 1.2K / 3.4M / durées
    mine/elevator/warehouse/continent/game_state.gd  # modèles (Resource) + to_dict/from_dict + sanitize
    production_engine.gd # tick pur du pipeline + détection de bottleneck
    offline_calculator.gd# gain hors-ligne + anti-triche horloge
  data/
    content.gd           # seed des continents/mines (contenu séparé de la logique)
  systems/     # autoloads (singletons) — pont entre logique et moteur/UI
    game_controller.gd   # "Game" : état, boucle de tick, actions, signals, save à la sortie
    save_manager.gd      # "SaveManager" : JSON chiffré + HMAC + écriture atomique
    ads_manager.gd       # "Ads" : pubs rewarded (stub desktop, AdMob Android à brancher)
    haptics.gd / audio_manager.gd
  scenes/
    main.tscn / main.gd  # écran principal (UI construite par code)
tests/         # framework maison + suites unitaires
docs/          # PRD, specs par feature, roadmap, sécurité
```

### Principes
- **`core/` ne dépend jamais du moteur** : toute l'économie est testable sans UI ni scène.
- **Réactivité UI** : l'UI lit les getters du `Game` chaque frame et se reconstruit sur `structure_changed`.
- **Équilibrage** : tout se règle dans `balance_config.gd`, jamais en dur dans la logique.

## Sécurité
Voir `docs/specs/security.md`. En place : sauvegarde **chiffrée (AES)** + **signature HMAC-SHA256**
(anti-tamper), écriture **atomique**, **reset sûr** sur fichier corrompu/altéré, **anti-manipulation
d'horloge** pour le hors-ligne, **validation/bornage** de toutes les données chargées, secrets hors dépôt.
À brancher côté serveur pour la prod : vérification IAP + AdMob SSV.

## Documentation
- `docs/PRD.md` — vision, mécaniques, économie, formules.
- `docs/specs/*.md` — une spec par feature.
- `docs/tasks/roadmap.md` — avancement et reste à faire.
