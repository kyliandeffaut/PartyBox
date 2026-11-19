# PartyBox — instructions pour Claude

Appli de jeux de soirée **Flutter / Dart + Firebase Firestore**, publiée sur le Play Store (`com.deffautstudio.partybox`, projet Firebase `partybox-98bce`, plan Spark). Modes : local (1 téléphone, Pass & Play) et en ligne (lobbys Firestore en temps réel). Réponds en français, style direct.

**Plateformes** : Android (Play Store) + **version web sur Firebase Hosting**, qui sert de version iOS (pas de compte Apple Developer : les joueurs iPhone jouent depuis le navigateur). Les deux partagent la même base Firestore et doivent pouvoir jouer ensemble dans un même lobby. Toute fonctionnalité doit donc marcher **aussi sur Flutter Web** : Auth anonyme web, pas de plugin Android-only sans repli web, et pas de paiement Play Billing côté web (prévoir une autre solution pour le VIP).

## Avant de commencer / à la fin d'une session

- **Mémoire du projet** : `C:/Obsidian/SecondCerveau/40_Dev_Projets/PartyBox.md` (feuille de route, décisions, section « Reprendre ici »). Lis-la au début si elle est accessible ; à la fin, mets à jour « Reprendre ici » et ajoute une ligne au journal. Ne relis pas l'historique des conversations : cette note fait foi.
- Ne jamais écrire de code VIP, mot de passe ou clé dans le repo ni dans la note (le repo est **public**).

## Commandes

- `flutter pub get` · `flutter analyze` · `flutter test` · `dart format lib test`
- Build Android : `flutter build appbundle` · Web : `flutter build web` (Firebase Hosting → `build/web`)
- Règles Firestore : `firestore.rules` (déployées à la main depuis la console, **jamais** de `firebase deploy` sans accord explicite)
- Émulateurs : `firebase emulators:start` (Auth 9099, Firestore 8080, UI `localhost:4000`) · appli sur les émulateurs : `flutter run --dart-define=USE_EMULATORS=true` (web → `localhost`, émulateur Android → `10.0.2.2`, vrai téléphone → `--dart-define=EMULATOR_HOST=<IP du PC>`). Ne jamais déployer un `build/web` compilé avec `USE_EMULATORS`.
- Tests des règles : `cd firestore-tests && npm install && npm test` (émulateur Firestore lancé). **Toute modif de `firestore.rules` doit passer ces tests**, et en ajouter pour le nouveau comportement.

**Toujours lancer `flutter analyze` (et `flutter test` s'il y a des tests concernés) avant de dire qu'une tâche est finie.**

## Structure (`lib/`)

| Fichier | Rôle |
|---|---|
| `main.dart` | Entrée, sons globaux (`playSfx`, `startGlobalBgm`…), nettoyage des lobbys expirés (`expireAt`, côté client : le TTL Firestore exige Blaze) |
| `firebase_setup.dart` | Émulateurs, Auth anonyme (`ensureSignedIn`, `currentUid`), `lobbyNameKey`, suppression complète d'un lobby |
| `home_screen.dart` | Accueil, création / rejoindre un lobby, QR, easter egg VIP (7 taps sur le titre) |
| `waiting_room_screen.dart` | Lobby : joueurs, kick, choix du jeu par le chef, lancement / reset de partie |
| `action_verite_screen.dart`, `je_nai_jamais_screen.dart`, `tribunal_screen.dart`, `tu_prefere_screen.dart`, `mr_white_screen.dart` | Un écran par jeu, logique locale + en ligne dans le même fichier |
| `live_chat_widget.dart`, `live_chat_fab.dart` | Chat du lobby |
| `qr_scanner_screen.dart` | Scan du QR `lobbyId|password` |

Contenu des jeux : `assets/*.json` (`action_verite`, `je_nai_jamais` par catégorie Soft / Interdit / +18, `tribunal`, `tu_prefere`, `mr_white`). Style : néon, glassmorphism, `flutter_animate`. Pas encore de gestion d'état dédiée (`setState` partout).

## Schéma Firestore

Tout accès demande l'**Auth anonyme** (`ensureSignedIn()` avant toute opération en ligne).

- `lobbies/{id}` — lisible **par ses membres seulement**. Création (batch avec `lobbyNames`) : `lobbyName`, `nameKey`, `password`, `status` (`waiting` | `playing`), `host` (pseudo), `hostUid`, `members` {uid: pseudo}, `gameMode` (`Action ou Vérité` | `Je n'ai jamais` | `Le Tribunal` | `Tu préfères ?` | `Mr White`), `players` [{`name`, `gender` H/F}], `createdAt` (serverTimestamp), `expireAt` (+24 h)
  - Figés : `lobbyName`, `nameKey`, `password`, `createdAt`, `expireAt`. `host`/`hostUid` : seul le chef les transmet. `members` : on rejoint (soi seul, avec le mot de passe), on part (soi), le chef exclut (un autre).
  - Rejoindre = un batch : `joins/{uid}` {`password`} + `members.{uid}` + `players: arrayUnion` ; puis suppression de `joins/{uid}` (illisible).
  - En jeu : `activePlayers` [...], `currentQuestion`, `currentPlayerIndex`, `jnjVisibility`, `jnjGameEnded`, `tpChoice`, champs Mr White `mw*` (`mwPhase`, `mwRound`, `mwTurnIndex`, `mwCivilWord`, `mwRole`, `mwWords`, `mwMaxWords`, `mwHasMrWhite`, `mwHasUndercover`, `mwEliminated`, `mwEliminatedRole`, `mwGameResult`)
  - Sous-collection `messages/{id}` : `text`, `sender` (= `members[uid]`), `senderUid`, `timestamp`
  - Suppression : par le dernier membre (`members.size() <= 1`, avec messages et nom) ou par n'importe qui après `expireAt`.
- `lobbyNames/{nameKey}` — `lobbyId`, `expireAt`. `nameKey = lobbyNameKey(nom)` (minuscules, encodé). `get` seulement : sert à rejoindre par nom et à garantir l'unicité.
- `vipCodes/{code}` — `action` = `unlock` | `lock`. L'appli fait un `get` sur le code tapé ; jamais de `list`.

Dans les jeux, les joueurs restent identifiés par leur **pseudo** (`players`, `activePlayers`) ; l'uid sert aux droits (`members`, `hostUid`). Toute modif de schéma doit rester compatible avec `firestore.rules` : si tu ajoutes un champ à la création d'un lobby ou d'un message, mets à jour `hasOnly([...])` dans les règles **et** les tests `firestore-tests/`.

## Règles de travail

- Travailler sur une **branche** + PR, jamais de push direct sur `main`.
- Gros chantier (sécurité, refacto, schéma Firestore) : **Plan mode d'abord** et consulter l'advisor avant de choisir l'approche et avant de déclarer fini.
- Tâches de nuit / sans surveillance : branche dédiée, PR à relire, pas de déploiement Firebase, pas de modification des règles en prod.
- Modifs ciblées : ne pas réécrire un écran entier quand une fonction suffit, sauf refacto demandée.
- Contenu JSON : garder la structure existante, pas de doublons, texte en français.

## Connu / en cours (détails dans la note Obsidian)

- Les règles ne valident pas l'état de jeu : un membre peut modifier `players`, `activePlayers`, `currentQuestion`… (phase 3).
- Les messages d'un lobby expiré ou supprimé sont lisibles par tout utilisateur connecté (nécessaire au nettoyage côté client).
- Pas de détection de déconnexion ; le reset de partie et le bouton retour du lobby sont fragiles.
- `test/widget_test.dart` est le test par défaut (cassé).
