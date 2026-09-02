# Spec — Sécurité (transverse)

> Priorité **transverse** : chaque feature applique les points la concernant. Modèle de menace d'un
> idle game **offline-first** : le joueur lui-même est l'attaquant principal (triche : édition de save,
> manipulation d'horloge, faux rewards). Objectif : **élever fortement le coût de la triche** sans
> jamais dégrader l'expérience du joueur honnête ni bloquer le jeu hors-ligne.

## 1. Intégrité de la sauvegarde (anti-tamper) — *feature c*
Menace : édition manuelle de `save.json` pour se donner du cash/super-cash infini.
- Save stockée dans `user://` (répertoire privé de l'app sur Android).
- **HMAC-SHA256** du payload sérialisé, calculé avec une clé embarquée obfusquée (`HMACContext` / `Crypto`).
  - Au chargement : recalculer et comparer. Mismatch → save considérée **altérée** → retour à un état sûr (voir §4), jamais de crash.
- **Chiffrement au repos** : `FileAccess.open_encrypted_with_pass()` (AES intégré Godot) par-dessus le HMAC.
- La clé client n'est pas un secret absolu (elle est dans le binaire) mais le combo chiffrement + HMAC + script encryption (§7) écarte 99 % des triches « bloc-notes ».
- Écriture **atomique** (temp + rename) pour éviter une save corrompue.

## 2. Anti-manipulation d'horloge (exploit offline) — *feature c / offline*
Menace : avancer l'horloge système pour farmer le cash hors-ligne.
- Persister `last_seen` (horloge murale) **et** un compteur de temps de jeu.
- Au retour : `elapsed = clamp(now - last_seen, 0, offline_cap)`.
  - `now < last_seen` (horloge reculée) → `elapsed = 0`, **aucun** gain (pas de crédit négatif, pas de reset punitif).
- Cap strict sur l'offline (PRD §5) : borne l'exploit même si l'horloge est avancée.
- **Optionnel (online)** : valider l'heure via une source réseau de confiance (HTTP time/NTP) quand le réseau est là ; sinon best-effort local. Non bloquant hors-ligne.

## 3. Achats & rewards — *feature i*
- **IAP** : ne jamais faire confiance au client. Vérifier les achats **côté serveur** (Google Play Developer API via un petit backend / cloud function) avant d'accorder un entitlement durable (`perm_x2`, `remove_ads`). À défaut de backend au lancement : acquittement + vérification de signature locale de Play Billing, avec re-vérification serveur prévue.
- **Rewarded ads** : activer l'**AdMob Server-Side Verification (SSV)** pour créditer les récompenses de valeur → un client modifié ne peut pas simuler la fin d'une pub.
- Idempotence : `pending_reward` + identifiant de transaction pour ne créditer **qu'une fois**.

## 4. Robustesse & validation des données — *toutes features*
- À la désérialisation : valider **types et plages** de chaque champ (pas de `NaN`/`inf`, pas de négatif, bornes hautes raisonnables) ; clamp ou rejet.
- Données invalides/corrompues → état sûr (nouvelle partie propre ou dernier bon état), log, **jamais de crash**.
- `economy.gd` : garde-fous contre division par zéro (`trip_time > 0`, etc.) et valeurs aberrantes.

## 5. Secrets & signing — *build / repo*
- **Aucun secret dans le repo** : keystore de signature, clés de service, clés serveur → hors dépôt (`.gitignore` déjà en place).
- Clés injectées via variables d'environnement / secrets CI au moment de l'export.
- Les identifiants AdMob/Play (semi-publics) OK côté client ; les clés **serveur** jamais côté client.

## 6. Réseau — *feature i / optionnel*
- Tout appel backend en **HTTPS/TLS** avec validation de certificat (par défaut Godot).
- Pas de donnée personnelle dans les URLs ; payloads minimaux.

## 7. Durcissement du build — *export*
- **Script encryption** à l'export (`export --encrypt` / clé PCK) pour compliquer la décompilation du GDScript ; clé hors repo.
- Export **release** sans symboles de debug, `OS.is_debug_build()` gate les triches de dev.
- Minimiser les permissions Android (INTERNET seulement si pubs/leaderboard).

## 8. Confidentialité / conformité — *store*
- Formulaire **Data Safety** Google Play à jour.
- **Consentement pub** (UMP / GDPR/CCPA) avant pubs personnalisées ; option non-personnalisées.
- Politique de confidentialité liée dans la fiche Play. COPPA/politique enfants si ciblage concerné.

## Checklist d'application par feature
- [ ] core (a) : validation de plages + garde-fous `economy` (division par zéro, NaN).
- [ ] save (c) : HMAC + chiffrement + écriture atomique + reset sûr.
- [ ] offline (c) : anti-horloge (backward = 0 gain) + cap strict.
- [ ] monétisation (i) : SSV rewarded, vérif IAP serveur, idempotence.
- [ ] build : script encryption, secrets hors repo, permissions minimales.
- [ ] store : Data Safety, consentement pub, politique de confidentialité.
