# Spec — Sauvegarde & état

Réf. : PRD §3.9.

## Objectif
Persister `GameState` localement (JSON), avec timestamps pour l'idle offline et un `schema_version` pour les migrations.

## Composant — `game/systems/save_manager.gd` (autoload)
- `save(state)` : sérialise `state.to_dict()` → JSON → `user://save.json` (écriture atomique via fichier temp + rename).
- `load()` : lit le JSON, vérifie `schema_version`, migre si besoin, renvoie `GameState`.
- `last_seen` mis à jour dans `save()` (= `Time.get_unix_time_from_system()`).

## Format sérialisé (`GameState.to_dict` / `from_dict`)
```json
{
  "schema_version": 1,
  "last_seen": 1730000000,
  "cash": 0.0,
  "super_cash": 0.0,
  "active_continent": 0,
  "continents": [ { "mines": [...], "elevator": {...}, "warehouse": {...} } ],
  "managers": [...],
  "prestige_upgrades": {...},
  "settings": { "sound": true, "haptics": true }
}
```

## Déclencheurs de sauvegarde
- `NOTIFICATION_APPLICATION_PAUSED` / `WM_CLOSE_REQUEST` (mise en arrière-plan / fermeture) → **save immédiat** (critique pour l'offline).
- Autosave périodique (ex : toutes les 15 s) + à chaque événement clé (upgrade, embauche, prestige).

## Migration
- `migrate(dict, from_version)` : chaîne de transformations version→version, jamais de perte silencieuse.

## Cas limites
- Fichier absent/corrompu → nouvelle partie propre (log l'erreur, ne crashe pas).
- Écriture atomique pour éviter une save tronquée si l'app est tuée pendant l'écriture.

## Tests (`tests/test_save.gd`)
- [ ] `to_dict` → `from_dict` = round-trip identique (toutes les valeurs).
- [ ] `load()` sur fichier absent → état neuf.
- [ ] `load()` sur JSON corrompu → état neuf sans crash.
- [ ] `migrate` d'une v0 fictive vers v1.
