# Build & publication Android (Google Play)

Guide pour packager **Deep Tycoon** en APK (test) / AAB (Play Store) depuis Windows avec Godot 4.7.

> ⚠️ Deux prérequis nécessitent **ton action** (je ne peux pas les faire à ta place) :
> 1. **Télécharger les export templates** Godot 4.7.2 (~1 Go).
> 2. **Créer un keystore de signature** (secret, jamais committé — déjà couvert par `.gitignore`).

---

## 1. Prérequis à installer

### a) Export templates Godot (obligatoire)
Version **identique** au moteur (4.7.2.stable). Deux options :
- Éditeur Godot → `Éditeur > Gérer les modèles d'exportation > Télécharger`.
- Ou en ligne de commande :
```bash
godot --headless --export-release "Android" 2>&1   # échouera en indiquant les templates manquants, puis :
# télécharge deps depuis https://godotengine.org/download (Export Templates) et place-les via l'éditeur
```

### b) JDK 17 + Android SDK
- **OpenJDK 17** (Temurin).
- **Android SDK** (via Android Studio ou cmdline-tools) : platform-tools, build-tools, platform android-34+.
- Dans Godot : `Éditeur > Paramètres de l'éditeur > Export > Android` → renseigner les chemins du SDK, du JDK et du `debug.keystore`.

### c) Keystore de release (TON secret)
```bash
keytool -genkeypair -v -keystore deeptycoon-release.keystore \
  -alias deeptycoon -keyalg RSA -keysize 2048 -validity 10000
```
- Conserve ce fichier + les mots de passe **en lieu sûr** (sans lui, plus aucune mise à jour possible sur Play).
- **Ne jamais committer** (déjà bloqué par `.gitignore`). Injecte les chemins/mots de passe via variables d'environnement au moment de l'export, pas dans `export_presets.cfg`.

---

## 2. Configuration de l'export (dans Godot)

`Projet > Exporter > Ajouter > Android` :
- **Package unique name** : `com.<tonstudio>.deeptycoon`
- **Version code / name** : incrémenter à chaque build.
- **Min SDK** : 23+ ; **Target SDK** : 34+ (exigence Play).
- **Permissions** : cocher **uniquement** `INTERNET` (pubs/leaderboard). Rien d'autre (sécurité §7).
- **Gradle build** : activer "Use Gradle Build" (requis pour les plugins pubs/billing).
- **Encryption** : activer le chiffrement des scripts (voir §4).

## 3. Builder en ligne de commande
```bash
# APK de test
godot --headless --export-debug "Android" build/deeptycoon.apk
# AAB pour Play Store (release, signé avec ton keystore)
godot --headless --export-release "Android" build/deeptycoon.aab
adb install -r build/deeptycoon.apk    # tester sur appareil/emulateur
```

## 4. Sécurité du build (rappel `docs/specs/security.md`)
- **Script encryption** : définir une clé (32 octets hex) via l'env `GODOT_SCRIPT_ENCRYPTION_KEY` avant l'export release. **Hors repo.**
- Export **release** (pas debug) pour la prod ; `OS.is_debug_build()` protège les hooks de dev (ex : la capture `-- shot`).
- Keystore + clés serveur hors dépôt ; permissions minimales.

## 5. Monétisation Android (à brancher — actuellement en stub)
Le code est prêt (`Ads`/`iap` en stubs desktop) ; il reste à intégrer les plugins natifs :
- **Pubs** : plugin **AdMob** pour Godot 4 (Google Mobile Ads). Brancher dans `game/systems/ads_manager.gd` (remplacer le stub par les appels réels + activer **AdMob SSV** côté serveur pour les récompenses de valeur).
- **Achats** : plugin **Google Play Billing** pour Godot 4. Vérifier les achats **côté serveur** (Google Play Developer API) avant d'accorder `perm_x2` / `remove_ads`.
- **Leaderboard** : plugin **Play Games Services** ; soumettre le cash total.
- **Consentement** : UMP (GDPR/CCPA) avant pubs personnalisées.

## 6. Checklist Play Store
- [ ] Icônes (adaptatives) + feature graphic + captures.
- [ ] Fiche + politique de confidentialité (URL).
- [ ] Formulaire **Data Safety** à jour.
- [ ] AAB signé (Play App Signing).
- [ ] Test interne → fermé → production.

## 7. iOS (plus tard)
Nécessite un **Mac** (Xcode) pour l'export et la signature. Le cœur Godot est portable ; remplacer AdMob/Billing/Play Games par leurs équivalents Apple (StoreKit/GameKit) au moment du portage.
