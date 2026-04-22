Salut ! Tu es mon assistant développeur expert en Flutter et Firebase.
Voici le contexte complet de mon application mobile actuelle pour que tu saches exactement où on en est.

# 📱 NOM DE L'APP : PartyBox
Une application de jeux de soirées multijoueur (Local sur 1 téléphone, et En Ligne via des salons/lobbies).

# 🛠️ TECHNOLOGIES UTILISÉES
- Framework : Flutter / Dart
- Base de données : Firebase Firestore (Temps réel via StreamBuilders)
- UI/UX : Effets Néon, Glassmorphism, animations avec `flutter_animate`.

# 🎮 MODES DE JEUX ACTUELS
1. "Action ou Vérité"
2. "Je n'ai jamais"

# ⚙️ FONCTIONNALITÉS DÉJÀ DÉVELOPPÉES ET FONCTIONNELLES :
- Écran d'accueil avec un Easter Egg (7 clics sur le titre ouvre un popup pour un code VIP qui débloque les modes premium via SharedPreferences).
- Système de Lobby (En ligne) : Création avec MDP, pseudo, genre (H/F). Le Chef (Host) peut kick des joueurs, changer les paramètres, et lancer la partie.
- Synchronisation en temps réel de tous les joueurs via Firestore (`activePlayers`, `status`, `currentQuestion`).

# 🎯 DÉTAILS SPÉCIFIQUES DES JEUX :
**Je n'ai jamais :**
- Les joueurs votent "Déjà fait" (+1 point) ou "Jamais" (+0 point).
- Un "Mode Secret 🤫" basculable par le chef en plein jeu : cache les scores des autres joueurs jusqu'à la fin, puis révèle combien de personnes l'ont fait.
- Le chef gère le passage à la question suivante ou affiche le classement final ("Fin").
- Séparation propre de la logique Locale (variables d'état) et En Ligne (Firebase).

**Action ou Vérité :**
- Catégories par intensité (Soft, Hot, +18, etc.).
- Choix entre 2 portes (Action ou Vérité) qui s'ouvrent pour révéler la question.
- Le texte des questions s'adapte dynamiquement au sexe des joueurs présents dans la room.

# 🐛 CE SUR QUOI NOUS TRAVAILLONS ACTUELLEMENT (Prochaines étapes) :
1. Stabiliser la navigation (éviter que le bouton retour n'éjecte définitivement du lobby, mais remette le joueur en mode "attente").
2. Améliorer l'interface du lobby : Ajouter des coches vertes pour indiquer "Prêt" ou "En jeu 🎮" selon l'état du joueur.
3. Résoudre les bugs de réinitialisation : Quand le chef relance une partie depuis le lobby, bien remettre les scores, votes et l'index des joueurs à zéro pour piocher une nouvelle question sans boucler sur la précédente.

S'il te plaît, analyse ce contexte. Attends mes prochaines instructions et donne-moi toujours des réponses ciblées (fonction par fonction) sans réécrire des fichiers entiers si ce n'est pas nécessaire.