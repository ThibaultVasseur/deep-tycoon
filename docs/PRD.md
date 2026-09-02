# PRD — **Deep Tycoon** (idle miner)

> **Statut** : validé (nom + stack). Découpage specs/tasks en cours.
> **Genre** : Idle / Incremental (tycoon minier), inspiré d'Idle Miner Tycoon, Cash Inc, Mr. Mine.
> **Stack retenu** : **Godot 4** (GDScript), cible principale **Google Play (Android)**, iOS en cible secondaire (build final signé sur Mac).
> **Environnement de dev** : Windows (Godot buildable et testable localement ; export Android depuis Windows).

---

## 1. Vision & pitch

Un jeu idle où le joueur gère une **chaîne de production minière verticale** — extraire, transporter, vendre — et où tout le plaisir vient de **repérer et corriger les goulots d'étranglement (bottlenecks)** entre les trois maillons. On tape pour accélérer au début, on **automatise via des managers**, on encaisse du **revenu hors-ligne**, puis on **prestige** pour repartir plus fort. La progression s'étale sur des continents multiples aux ordres de grandeur croissants.

**Fantaisie du joueur** : « Ma mine tourne toute seule, même la nuit, et chaque retour dans le jeu me récompense. Chaque upgrade débloque une accélération satisfaisante. »

**Piliers de design**
1. **Bottleneck management** — la boucle mentale centrale : quel maillon freine la chaîne maintenant ?
2. **Progression massive** — chaque niveau de mine plus profond produit un ordre de grandeur de plus (×50 à ×500).
3. **Récompense de l'attente** — l'idle hors-ligne et l'automatisation donnent le sentiment que « ça avance sans moi ».
4. **Lisibilité premium** — chiffres formatés (1.2K, 3.4M…), feedback visuel/haptique/sonore sur chaque action rentable.

---

## 2. Boucle de gameplay centrale

```
        ┌──────────┐   ┌────────────┐   ┌────────────┐   ┌────────┐
        │  MINES   │──▶│ ASCENSEUR  │──▶│  ENTREPÔT  │──▶│  CASH  │
        │ (extrait)│   │(transporte)│   │  (vend)    │   │        │
        └──────────┘   └────────────┘   └────────────┘   └────────┘
             ▲               ▲                ▲               │
             │               │                │               │
             └──── upgrades / managers financés par le cash ──┘

  Cash ──▶ upgrades ──▶ débit ↑ ──▶ plus de cash ──▶ … ──▶ Prestige ──▶ bonus permanents
```

**Micro-boucle (secondes)** : taper une mine → wagonnet arrive à l'ascenseur → ascenseur monte au dépôt → entrepôt vend → cash augmente (pop numérique + son + haptique).

**Méso-boucle (minutes/heures)** : accumuler du cash → upgrader mines/ascenseur/entrepôt pour rééquilibrer la chaîne → embaucher des managers pour automatiser → débloquer une mine plus profonde.

**Macro-boucle (jours)** : compléter un continent → prestige contre super-cash → relancer avec bonus multiplicatifs → débloquer le continent suivant.

---

## 3. Mécaniques — user stories & critères d'acceptation

Chaque bloc deviendra une **spec** dédiée (`docs/specs/*.md`).

### 3.1 Mines / Production — `mine-production.md`
**US-1** : En tant que joueur, je tape sur une mine pour lancer un cycle d'extraction et voir un wagonnet se remplir.
**US-2** : Je peux upgrader une mine avec du cash pour augmenter son débit (unités/s).
**US-3** : Je débloque une nouvelle mine plus profonde une fois que j'ai assez de cash.

**Critères d'acceptation**
- [ ] Une mine a : `niveau`, `débitBase`, `débitParNiveau`, `coûtBase`, `croissanceCoût`.
- [ ] Débit effectif = `débitBase × (croissanceProd ^ (niveau-1)) × multiplicateursGlobaux`.
- [ ] Coût du prochain niveau = `coûtBase × (croissanceCoût ^ niveau)` (voir §5).
- [ ] Une mine `k+1` produit une ressource dont la valeur/débit est **×50 à ×500** celle de la mine `k`.
- [ ] Sans manager, l'extraction nécessite un tap ; avec manager, elle est continue.
- [ ] Le tap déclenche feedback haptique + animation du wagonnet.

### 3.2 Ascenseur / Transport — `elevator-transport.md`
**US-4** : L'ascenseur collecte les ressources des mines et les monte à l'entrepôt.
**US-5** : J'upgrade sa **capacité** et sa **vitesse** pour qu'il ne devienne pas le goulot.

**Critères d'acceptation**
- [ ] L'ascenseur a : `capacité` (unités/voyage), `vitesse` (s/voyage), niveaux upgradables.
- [ ] Débit ascenseur = `capacité / vitesse` (unités/s).
- [ ] Si débit(mines cumulé) > débit(ascenseur) → **bottleneck signalé visuellement** (mines pleines qui attendent).
- [ ] Avec manager : va-et-vient automatique ; sans : nécessite un tap pour partir.

### 3.3 Entrepôt / Conversion — `warehouse-conversion.md`
**US-6** : L'entrepôt stocke les ressources livrées puis les vend contre du cash.
**US-7** : J'upgrade sa **capacité de stockage** et sa **vitesse de vente**.

**Critères d'acceptation**
- [ ] L'entrepôt a : `capacitéStock`, `vitesseVente` (unités/s), `prixUnitaire` (par ressource).
- [ ] Débit vente = `min(stockDisponible, vitesseVente) × prixUnitaire`.
- [ ] Si l'entrepôt est plein → l'ascenseur ne peut plus déposer → **bottleneck aval signalé**.
- [ ] Avec manager : vente continue ; sans : nécessite un tap.

### 3.4 Managers / Automatisation — `manager-automation.md`
**US-8** : Quand un composant atteint un niveau seuil, je peux embaucher un manager qui l'automatise.

**Critères d'acceptation**
- [ ] Un manager cible **un** composant (mine X, ascenseur, entrepôt).
- [ ] Coût d'embauche fixe (ou en super-cash pour les premiums) ; automatisation permanente après achat.
- [ ] Un composant automatisé produit **même hors-ligne** (base du calcul idle, §3.5).
- [ ] Certains managers offrent un **bonus** (ex : +X % de débit sur leur composant).

### 3.5 Cash idle / Production hors-ligne — `offline-earnings.md`
**US-9** : Quand je reviens dans l'app après une absence, je reçois un gain hors-ligne, avec un récap.

**Critères d'acceptation**
- [ ] À la fermeture/mise en arrière-plan : sauvegarder `lastSeenTimestamp`.
- [ ] Au retour : `Δt = min(now − lastSeen, capHorsLigne)`.
- [ ] `capHorsLigne` = 8 h par défaut, extensible (upgrade/IAP) jusqu'à 12 h+.
- [ ] Seuls les composants **automatisés** produisent hors-ligne.
- [ ] Le débit hors-ligne respecte le **bottleneck** de la chaîne (voir formule §5).
- [ ] `gainHorsLigne = débitPipelineAutomatisé × facteurIdle × Δt`, `facteurIdle` = 0.5 par défaut (upgradable).
- [ ] Popup de retour : « Absent Xh Ym → +Z cash », avec option « doubler (pub/IAP) ».

### 3.6 Prestige — `prestige-system.md`
**US-10** : Je peux réinitialiser volontairement ma progression contre du **super-cash** permanent qui booste la run suivante.

**Critères d'acceptation**
- [ ] Le bouton prestige n'apparaît/ne devient « rentable » qu'au-delà d'un seuil de cash total.
- [ ] `superCashGagné = f(cashTotalAccumulé)` (ex : `floor(k × sqrt(cashTotal / seuil))`).
- [ ] Le prestige remet à zéro : cash, niveaux de mines/ascenseur/entrepôt, managers non-permanents.
- [ ] Le prestige **conserve** : super-cash, bonus de prestige achetés, continents débloqués (à décider §12).
- [ ] Le super-cash achète des **bonus multiplicatifs globaux** (×prod, ×vente, ×capHorsLigne…).

### 3.7 Continents / Mondes — `continents-worlds.md`
**US-11** : Je débloque des zones de minage successives (charbon → or → diamant → magma…), chacune avec sa monnaie et ses mines.

**Critères d'acceptation**
- [ ] Chaque continent a son set de mines, ses prix, sa palette visuelle.
- [ ] Débloqué par cash/super-cash ; ordres de grandeur croissants entre continents.
- [ ] (À décider §12) monnaie propre par continent vs monnaie globale convertie.

### 3.8 Événements & expéditions — `events-expeditions.md` *(post-MVP)*
**US-12** : Des mini-contenus limités dans le temps offrent des boosts ou cosmétiques.

**Critères d'acceptation**
- [ ] Un événement a une fenêtre de temps, un objectif, une récompense (boost temporaire ou cosmétique).
- [ ] N'introduit pas de dépendance réseau bloquante pour le MVP.

### 3.9 Sauvegarde & état — `save-system.md`
**US-13** : Ma progression est sauvegardée localement et survit à la fermeture de l'app.

**Critères d'acceptation**
- [ ] Persistance de `GameState` complet + `lastSeenTimestamp`.
- [ ] Sauvegarde à chaque événement clé + périodiquement + à la mise en arrière-plan.
- [ ] Chargement au lancement + calcul idle (§3.5).
- [ ] Versionnage du schéma de save (migration future sans perte).

### 3.10 HUD & UI — `ui-hud.md`
**US-14** : Je vois en permanence mon cash, mon cash/seconde, et un bouton prestige qui se met en avant quand il devient rentable.

**Critères d'acceptation**
- [ ] HUD haut d'écran : cash actuel, cash/s, monnaie premium, bouton prestige (état « rentable » mis en valeur).
- [ ] Chiffres formatés (1.2K, 3.4M, 2.1B, 5.6T…).
- [ ] Indicateurs de **bottleneck** clairs sur chaque maillon.
- [ ] Popups d'upgrade avec barre de progression animée + coût du prochain niveau.

---

## 4. Formatage des nombres
- Suffixes : `K, M, B, T, aa, ab, …` (notation type idle au-delà du T).
- 3 chiffres significatifs (`1.24M`), pas de bruit visuel.
- Fonction pure `format(_ value: Double) -> String` **testable** sans UI.

---

## 5. Économie & équilibrage (formules commentées)

**Coût d'upgrade (croissance exponentielle standard)**
```
coût(niveauActuel) = coûtBase × croissanceCoût ^ niveauActuel
// croissanceCoût ∈ [1.07 ; 1.15]  (1.07 = courbe douce, 1.15 = classique tycoon)
```

**Production par niveau**
```
prod(niveau) = prodBase × croissanceProd ^ (niveau − 1) × multiplicateursGlobaux
// croissanceProd légèrement < croissanceCoût pour que chaque niveau reste "utile mais pas gratuit"
```

**Saut entre mines profondes**
```
prodBase(mine k+1) ≈ prodBase(mine k) × facteurProfondeur
// facteurProfondeur ∈ [50 ; 500]  → sentiment de progression massive
```

**Débit de chaque maillon (unités/s)**
```
débitMines      = Σ prod(mine i)                    (mines automatisées)
débitAscenseur  = capacité / vitesse
débitEntrepôt   = vitesseVente
débitPipeline   = min(débitMines, débitAscenseur, débitEntrepôt)   ← LE BOTTLENECK
cashParSeconde  = débitPipeline × prixUnitaireMoyen
```

**Idle hors-ligne (formule claire, plafonnée)**
```
Δt              = min(now − lastSeenTimestamp, capHorsLigne)   // capHorsLigne = 8h..12h
débitIdle       = débitPipelineAutomatisé × facteurIdle        // facteurIdle = 0.5 par défaut
gainHorsLigne   = débitIdle × prixUnitaireMoyen × Δt
```

**Prestige (super-cash + multiplicateur permanent)**
```
superCashGagné   = floor(k × sqrt(cashTotalContinent / seuilPrestige))
// seuilPrestige élevé → prestige = jalon long, "pas facile"
multPermanent   += bonusMultParPrestige × superCashGagné   // s'empile run après run
// à chaque prestige : reset du continent, on garde super-cash + multPermanent + continents débloqués
```
`multPermanent` multiplie la production/vente de la run suivante ; le super-cash débloque
les continents et achète les bonus globaux (voir prestige-system.md, monetization-ads.md).

Toutes ces constantes (`croissanceCoût`, `facteurProfondeur`, `facteurIdle`, `capHorsLigne`, `seuilPrestige`, `k`) vivent dans un **fichier de config d'équilibrage** unique et modifiable, séparé du code de logique.

---

## 6. Exigences visuelles, audio, haptiques
- **Palette** chaleureuse et lisible : tons terre + or, néon pour les upgrades ; identité « tycoon premium ».
- **Animations fluides** : barres d'upgrade, apparition des pièces à la vente, pop numérique du cash, transitions d'écran, wagonnets, particules.
- **Haptique** (`UIFeedbackGenerator` / équivalent) sur chaque tap productif.
- **Audio** : thème de fond discret + SFX (minage, upgrade, prestige, vente). Structure d'intégration prête même si les assets arrivent plus tard.
- **Scène animée** (SpriteKit ou équivalent) : puits empilés, wagonnets, ascenseur, particules d'or/pièces.

---

## 7. Architecture (MVVM strict, indépendant du rendu)
- **Models** : `GameState`, `Mine`, `Elevator`, `Warehouse`, `Manager`, `Continent`, `BalanceConfig`.
- **Moteur** : `ProductionEngine` (tick pur, testable), `OfflineEarningsCalculator`, `EconomyFormulas`.
- **ViewModels** : `GameViewModel` observable, expose l'état formaté à l'UI, orchestre le tick.
- **Views** : HUD, boutiques/upgrades, popups, scène de mine.
- **Persistance** : couche `SaveRepository` abstraite (implémentation SwiftData/Core Data ou autre selon stack).

> Le **cœur logique** (moteur + formules + formatage) ne dépend d'aucun framework UI → 100 % testable unitairement, quel que soit le stack final.

---

## 8. Monétisation & social *(implémentée en dernier, jamais bloquante)*

**Philosophie pub (règle d'or)** : toutes les pubs sont **rewarded (récompensées), opt-in, et ne font que faire GAGNER DU TEMPS**. Aucune pub n'est imposée, aucune ne bloque ou ne gate la progression. Un joueur qui ne regarde jamais de pub peut tout finir — juste plus lentement. Détails : `docs/specs/monetization-ads.md`.

**Pubs récompensées (rewarded)**
- **×2 gains hors-ligne** au retour (bouton sur la popup offline).
- **Boost temporaire** ×2 production/vente pendant N minutes (bouton dédié, cooldown).
- **Time-skip** : « saute X h de production » d'un coup contre une pub.
- **Coup de pouce upgrade** : réduction/instant sur la prochaine amélioration.

**Achats intégrés (IAP — Google Play Billing, iOS StoreKit au portage)**
- **×2 permanent** (multiplicateur global définitif).
- **Suppression des pubs** (les boosts rewarded restent accessibles sans pub après achat).
- Packs de **super-cash / gemmes**, extension du **cap hors-ligne**.

**Social** : leaderboard du cash total via **Google Play Games Services** (GameKit à l'équivalent iOS).

> Priorité **dernière** (feature i). Le MVP est entièrement jouable sans pub ni IAP.

---

## 9. KPIs / critères de « beau et complet »
- Boucle jouable de bout en bout : taper → automatiser → prestige.
- Idle hors-ligne fonctionnel et vérifiable (fermer/rouvrir → gain crédité correct).
- Aucun blocage de progression (courbe d'équilibrage testée).
- 60 fps sur la scène animée ; chiffres toujours lisibles.
- Tests unitaires verts sur toute la logique d'économie avant chaque passage à la feature suivante.

---

## 10. Périmètre

**MVP** : mines + ascenseur + entrepôt (pipeline + bottleneck) → sauvegarde + idle → HUD/upgrades → scène animée → managers → prestige → polish.

**Post-MVP** : continents multiples, événements/expéditions, StoreKit, GameKit, cosmétiques.

---

## 11. Ordre d'implémentation (rappel du prompt)
1. Modèles + moteur de tick de production (cœur mathématique)
2. Mine + Ascenseur + Entrepôt en pipeline avec détection de bottleneck
3. Sauvegarde locale + idle cash au retour
4. UI HUD + popups d'upgrade
5. Scène animée de la mine
6. Managers (automatisation)
7. Prestige
8. Polish (visuel, sons, haptics)
9. Achats (StoreKit) + leaderboard (GameKit)

Après **chaque** feature : tests unitaires de la logique → build → vérification → feature suivante.

---

## 12. Décisions

**Tranchées**
1. ✅ **Nom** : Deep Tycoon (modifiable).
2. ✅ **Stack** : Godot 4 / GDScript, cible Google Play d'abord, iOS ensuite.

3. ✅ **Monnaies** : monnaie locale par continent + **super-cash mondial** (global, jamais perdu).
4. ✅ **Prestige** (par continent) : reset du continent (mines/ascenseur/entrepôt, cash local, managers non-premium) ; **conserve** super-cash mondial + continents débloqués ; **récompense** = multiplicateur de cash permanent (empilable) + somme de super-cash. Seuil élevé (long). Super-cash → débloque continents + bonus globaux.
5. ✅ **Pubs** : rewarded / opt-in / non bloquantes, uniquement pour gagner du temps (voir §8).

**Encore ouvertes (à ajuster en cours de route)**
6. **Valeurs d'équilibrage initiales** : défauts en §5, à ajuster après playtest.

---

*Prochaine étape proposée : une fois le nom et le stack validés, je découpe les specs (`docs/specs/*.md`) puis les tâches (`docs/tasks/*.md`), et je commence par le cœur logique (modèles + moteur de tick + tests), avant toute UI.*
