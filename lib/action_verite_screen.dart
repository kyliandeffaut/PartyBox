import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:convert';
import 'dart:math';

class GamePlayer {
  final String name;
  final String gender;
  GamePlayer({required this.name, required this.gender});
}

// --- L'ÉCRAN DE JEU HYBRIDE (Local & Online) ---
class ActionVeriteScreen extends StatefulWidget {
  final String category;
  final bool isOnline; 
  final String? lobbyId;
  final List<GamePlayer>? localPlayers;
  final String? currentPlayerName;
  final String? currentPlayerGender;
  
  const ActionVeriteScreen({
    super.key, 
    required this.category,
    required this.isOnline,
    this.lobbyId,
    this.localPlayers,
    this.currentPlayerName,
    this.currentPlayerGender,
  });

  @override
  State<ActionVeriteScreen> createState() => _ActionVeriteScreenState();
}

class _ActionVeriteScreenState extends State<ActionVeriteScreen> {
  List<dynamic> allQuestions = [];
  List<GamePlayer> players = [];
  
  // Variables locales (utilisées UNIQUEMENT si on joue hors-ligne sur 1 seul téléphone)
  int localCurrentPlayerIndex = 0;
  String localCurrentQuestion = "Appuie sur un bouton !";
  bool localShowNextButton = false;

  @override
  void initState() {
    super.initState();
    loadQuestions();
    
    // Au lancement, on récupère les joueurs
    if (widget.isOnline && widget.lobbyId != null) {
      fetchPlayersFromFirebase(); 
    } else {
      setState(() {
        players = widget.localPlayers ?? [];
      });
    }
  }

  Future<void> loadQuestions() async {
    final String response = await rootBundle.loadString('assets/action_verite.json');
    final data = await json.decode(response);
    setState(() { allQuestions = data; });
  }

  Future<void> fetchPlayersFromFirebase() async {
    DocumentSnapshot doc = await FirebaseFirestore.instance.collection('lobbies').doc(widget.lobbyId).get();
    
    if (doc.exists) {
      var data = doc.data() as Map<String, dynamic>;
      List rawPlayers = data['players'] ?? [];
      
      setState(() {
        players = rawPlayers.map((p) => GamePlayer(
          name: p['name'], 
          gender: p['gender']
        )).toList();
      });
    }
  }

  // 🔄 LA MAGIE : On envoie la question dans Firebase pour que tout le monde la voie !
  void _updateGameState(String question, bool showNext) {
    if (widget.isOnline && widget.lobbyId != null) {
      FirebaseFirestore.instance.collection('lobbies').doc(widget.lobbyId).update({
        'currentQuestion': question,
        'showNextButton': showNext,
      });
    } else {
      setState(() {
        localCurrentQuestion = question;
        localShowNextButton = showNext;
      });
    }
  }

  // 🔄 LA MAGIE : On change de tour dans Firebase
  void _updateTurn(int currentIndex) {
    int nextIndex = (currentIndex + 1) % players.length;
    
    if (widget.isOnline && widget.lobbyId != null) {
      FirebaseFirestore.instance.collection('lobbies').doc(widget.lobbyId).update({
        'currentPlayerIndex': nextIndex,
        'currentQuestion': "Appuie sur un bouton !",
        'showNextButton': false,
      });
    } else {
      setState(() {
        localCurrentPlayerIndex = nextIndex;
        localCurrentQuestion = "Appuie sur un bouton !";
        localShowNextButton = false;
      });
    }
  }

  // Tirage de la question
  void pickQuestion(String type, int cIndex) {
    if (allQuestions.isEmpty || players.isEmpty) return;

    var filtered = allQuestions.where((q) => q['type'] == type && q['category'] == widget.category).toList();
    if (filtered.isEmpty) {
      filtered = allQuestions.where((q) => q['type'] == type).toList();
    }
    if (filtered.isEmpty) return;

    final random = Random();
    var questionData = filtered[random.nextInt(filtered.length)];
    String text = questionData['text'];

    GamePlayer currentPlayer = players[cIndex];
    List<GamePlayer> potentialTargets = players.where((p) => p.name != currentPlayer.name).toList();

    bool hasMen = players.any((p) => p.gender == 'H');
    bool hasWomen = players.any((p) => p.gender == 'F');
    bool isMixedGroup = hasMen && hasWomen;

    if (isMixedGroup) {
      if (questionData['target'] == 'opposite') {
        potentialTargets = potentialTargets.where((p) => p.gender != currentPlayer.gender).toList();
      } else if (questionData['target'] == 'same') {
        potentialTargets = potentialTargets.where((p) => p.gender == currentPlayer.gender).toList();
      } else if (questionData['target'] == 'homme') {
        potentialTargets = potentialTargets.where((p) => p.gender == 'H').toList();
      } else if (questionData['target'] == 'femme') {
        potentialTargets = potentialTargets.where((p) => p.gender == 'F').toList();
      }
    }

    if (potentialTargets.isEmpty) {
      potentialTargets = List.from(players)..removeWhere((p) => p.name == currentPlayer.name);
    }
    
    if (potentialTargets.isNotEmpty) {
      potentialTargets.shuffle();
      GamePlayer target = potentialTargets[0];
      text = text.replaceAll("{target}", target.name);
    } else {
      text = text.replaceAll("{target}", "quelqu'un"); 
    }
    text = text.replaceAll("{player}", currentPlayer.name); 

    // On met à jour pour TOUT LE MONDE
    _updateGameState(text, true); 
  }

  @override
  Widget build(BuildContext context) {
    if (players.isEmpty) {
      return const Scaffold(
        backgroundColor: Color(0xFF101012),
        body: Center(child: CircularProgressIndicator(color: Colors.pinkAccent)),
      );
    }

    // MODE ONLINE : On "écoute" Firebase en permanence
    if (widget.isOnline && widget.lobbyId != null) {
      return StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance.collection('lobbies').doc(widget.lobbyId).snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData || !snapshot.data!.exists) return const SizedBox();
          
          var data = snapshot.data!.data() as Map<String, dynamic>;
          
          // 1. On récupère TOUS les joueurs du lobby (ceux présents dans le salon)
          List rawAllPlayers = data['players'] ?? [];
          players = rawAllPlayers.map((p) => GamePlayer(name: p['name'], gender: p['gender'])).toList();

          // 🛡️ LE BOUCLIER : On ne quitte l'écran QUE si on n'est plus dans le lobby du tout
          bool stillInLobby = players.any((p) => p.name == widget.currentPlayerName);  

          if (!stillInLobby) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (context.mounted) Navigator.pop(context);
            });
            return const Scaffold(backgroundColor: Color(0xFF101012));
          }

          int cIndex = data['currentPlayerIndex'] ?? 0;
          String cQuestion = data['currentQuestion'] ?? "Appuie sur un bouton !";
          bool showNext = data['showNextButton'] ?? false;
          
          // 🔥 MAGIE : Si c'était au tour de Romain, et que Romain quitte, 
          // le jeu passe automatiquement au joueur suivant sans planter !
          if (cIndex >= players.length) {
            cIndex = 0; 
          }

          return _buildGameUI(cIndex, cQuestion, showNext);
        }
      );
    } 
    // 🏠 MODE LOCAL : On utilise l'état du téléphone
    else {
      return _buildGameUI(localCurrentPlayerIndex, localCurrentQuestion, localShowNextButton);
    }
  }

  // L'INTERFACE GRAPHIQUE (Déplacée ici pour ne pas écrire le code en double)
  Widget _buildGameUI(int cIndex, String cQuestion, bool showNext) {
    GamePlayer currentPlayer = players[cIndex];

    // 1. ON AJOUTE LA VARIABLE ICI
    bool isMyTurn = widget.isOnline 
        ? (widget.currentPlayerName == currentPlayer.name) 
        : true;

    final Color themeColor = widget.category == 'Hot' || widget.category == 'Extrême' || widget.category == 'Séduction'
      ? Colors.red.shade900
      : Colors.indigo.shade900;

    return PopScope(
      canPop: false, // Bloque le retour auto pour exécuter notre logique
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;

        // LOGIQUE DE SORTIE : On retire seulement de 'activePlayers'
        if (widget.isOnline && widget.lobbyId != null) {
          // On retrouve ton genre dans la liste locale pour le remove
          String myGender = 'H';
          var me = players.where((p) => p.name == widget.currentPlayerName);
          if (me.isNotEmpty) myGender = me.first.gender;

          await FirebaseFirestore.instance
              .collection('lobbies')
              .doc(widget.lobbyId)
              .update({
            'activePlayers': FieldValue.arrayRemove([
              {
                'name': widget.currentPlayerName, 
                'gender': myGender
              }
            ])
          });
        }

        // On revient au lobby sans le quitter
        if (context.mounted) {
          Navigator.of(context).pop();
        }
      },
      child: Scaffold(
        extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
          onPressed: () async {
            if (widget.isOnline && widget.lobbyId != null) {
              // ASTUCE : On retrouve ton genre directement dans la mémoire du jeu !
              String myGender = 'H'; 
              var me = players.where((p) => p.name == widget.currentPlayerName);
              if (me.isNotEmpty) myGender = me.first.gender;

              // On se retire seulement de 'activePlayers', mais on RESTE dans le lobby !
              await FirebaseFirestore.instance.collection('lobbies').doc(widget.lobbyId).update({
                'activePlayers': FieldValue.arrayRemove([
                  {'name': widget.currentPlayerName, 'gender': myGender}
                ]),
                'lastAction': '${widget.currentPlayerName} est retourné au salon.'
              });
            } else {
              // En mode local, on fait juste un retour arrière normal
              Navigator.pop(context);
            }
          },
        ),
      ),
      body: AnimatedContainer(
        duration: const Duration(seconds: 1),
        decoration: BoxDecoration(
          gradient: RadialGradient(
            center: const Alignment(-0.5, -0.6),
            radius: 1.5,
            colors: [themeColor.withValues(alpha: 0.8), const Color(0xFF101012)],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              const SizedBox(height: 20),
              
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 5),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20)
                ),
                child: Text(
                  "Action ou Vérité • ${widget.category}", 
                  style: const TextStyle(color: Colors.white70, fontSize: 12)
                ),
              ),
              
              const SizedBox(height: 30),
              
              const Text("C'EST AU TOUR DE :", style: TextStyle(color: Colors.white54, letterSpacing: 2)),
              Text(
                currentPlayer.name.toUpperCase(), 
                style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w900, color: Colors.white)
              ),              
              
              Expanded(
                child: Center(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 600),
                    transitionBuilder: (Widget child, Animation<double> animation) {
                      return SlideTransition(
                        position: Tween<Offset>(begin: const Offset(0, 0.2), end: Offset.zero).animate(animation),
                        child: FadeTransition(opacity: animation, child: child),
                      );
                    },
                    child: Padding(
                      key: ValueKey(cQuestion),
                      padding: const EdgeInsets.all(30),
                      child: Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.9), 
                          borderRadius: BorderRadius.circular(30),
                          boxShadow: [
                            BoxShadow(color: themeColor.withValues(alpha: 0.5), blurRadius: 20, spreadRadius: 5)
                          ]
                        ),
                        child: Text(
                          cQuestion,
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w600, color: Colors.black87),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              
              // 2. ON A MODIFIÉ LA ZONE DES BOUTONS ICI
              Padding(
                padding: const EdgeInsets.all(40),
                child: !isMyTurn 
                    ? // SI CE N'EST PAS MON TOUR : On affiche un message d'attente
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(15),
                        ),
                        child: Text(
                          "Attends que ${currentPlayer.name} joue...",
                          style: const TextStyle(color: Colors.white70, fontStyle: FontStyle.italic, fontSize: 16),
                          textAlign: TextAlign.center,
                        ),
                      )
                    : // SI C'EST MON TOUR : On affiche les boutons normalement
                      showNext
                          ? SizedBox(
                              width: double.infinity, 
                              child: _gameButton("TOUR SUIVANT ➔", Colors.blueAccent, () => _updateTurn(cIndex)),
                            )
                          : Row(
                              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                              children: [
                                _gameButton("VÉRITÉ", const Color(0xFF22C55E), () => pickQuestion('verite', cIndex)),
                                _gameButton("ACTION", const Color(0xFFEC4899), () => pickQuestion('action', cIndex)),
                              ],
                            ),
              ),
            ],
          ),
        ),
      ),
    ),
    );
  }

  Widget _gameButton(String label, Color color, VoidCallback onPress) {
    return ElevatedButton(
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 35, vertical: 20),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        elevation: 10,
      ),
      onPressed: onPress,
      child: Text(label, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
    );
  }
}

// --- ÉCRAN 2 : SÉLECTION DES CATÉGORIES (SPÉCIAL MODE LOCAL) ---
class CategoryScreen extends StatelessWidget {
  final List<dynamic> players; 

  CategoryScreen({super.key, required this.players});

  final List<Map<String, dynamic>> categories = [
  {'name': 'Soft', 'color': const Color(0xFF4ADE80), 'emoji': '🍭'},
  {'name': 'Famille', 'color': const Color(0xFF2DD4BF), 'emoji': '🏠'},
  {'name': 'Dehors', 'color': const Color(0xFF3B82F6), 'emoji': '🌳'},
  {'name': 'Bar', 'color': const Color(0xFF8B5CF6), 'emoji': '🍻'},
  {'name': 'Sans Filtre', 'color': const Color(0xFFF59E0B), 'emoji': '🙊'},
  {'name': 'Séduction', 'color': const Color(0xFFF43F5E), 'emoji': '🫦'},
  {'name': 'Couple', 'color': const Color(0xFFEC4899), 'emoji': '💞'},
  {'name': 'Hot', 'color': const Color(0xFFE11D48), 'emoji': '🔥'},
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF101012),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text("CHOISIS UNE CATÉGORIE", style: TextStyle(color: Colors.white, fontSize: 16)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: GridView.builder(
        padding: const EdgeInsets.all(20),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2, childAspectRatio: 1.5, crossAxisSpacing: 15, mainAxisSpacing: 15
        ),
        itemCount: categories.length,
        itemBuilder: (context, index) {
          final cat = categories[index];
          return ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: cat['color'].withValues(alpha: 0.2),
              side: BorderSide(color: cat['color'], width: 2),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            ),
            onPressed: () {
              List<GamePlayer> formattedPlayers = players.map((p) => GamePlayer(
                name: p.name, 
                gender: p.gender
              )).toList();

              Navigator.push(context, MaterialPageRoute(
                builder: (context) => ActionVeriteScreen(
                  category: cat['name'], 
                  isOnline: false,       
                  localPlayers: formattedPlayers, 
                ),
              ));
            },
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(cat['emoji'], style: const TextStyle(fontSize: 30)),
                const SizedBox(height: 10),
                Text(cat['name'], style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ],
            ),
          );
        },
      ),
    );
  }
}