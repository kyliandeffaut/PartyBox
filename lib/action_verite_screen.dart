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
  
  // 🔥 LES NOUVEAUTÉS POUR LE MODE LOCAL/ONLINE
  final bool isOnline; 
  final String? lobbyId; // Optionnel maintenant
  final List<GamePlayer>? localPlayers; // Optionnel (utilisé que si isOnline = false)
  
  const ActionVeriteScreen({
    super.key, 
    required this.category,
    required this.isOnline,
    this.lobbyId,
    this.localPlayers,
  });

  @override
  State<ActionVeriteScreen> createState() => _ActionVeriteScreenState();
}

class _ActionVeriteScreenState extends State<ActionVeriteScreen> {
  List<dynamic> allQuestions = [];
  String currentQuestion = "Appuie sur un bouton !";
  List<GamePlayer> players = [];
  
  int currentPlayerIndex = 0;
  bool showNextButton = false;

  @override
  void initState() {
    super.initState();
    loadQuestions();
    
    // 🔥 LE SWITCH MAGIQUE EST ICI
    if (widget.isOnline && widget.lobbyId != null) {
      // MODE ONLINE : On va chercher sur Internet
      fetchPlayersFromFirebase(); 
    } else {
      // MODE LOCAL : On utilise directement la liste qu'on lui a donnée
      setState(() {
        players = widget.localPlayers ?? [];
      });
    }
  }

  // 1. Charger les questions depuis le JSON
  Future<void> loadQuestions() async {
    final String response = await rootBundle.loadString('assets/action_verite.json');
    final data = await json.decode(response);
    setState(() { allQuestions = data; });
  }

  // 2. Charger les joueurs depuis Firebase (juste pour le mode Online)
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

  // 3. La logique de tirage de question (Ta bonne vieille fonction !)
  void pickQuestion(String type) {
    if (allQuestions.isEmpty || players.isEmpty) return;

    var filtered = allQuestions.where((q) => q['type'] == type && q['category'] == widget.category).toList();
    
    // Si la catégorie est vide, on prend tout pour éviter de planter
    if (filtered.isEmpty) {
      filtered = allQuestions.where((q) => q['type'] == type).toList();
    }
    
    if (filtered.isEmpty) return;

    final random = Random();
    var questionData = filtered[random.nextInt(filtered.length)];
    String text = questionData['text'];

    GamePlayer currentPlayer = players[currentPlayerIndex];

    // On prépare les cibles
    List<GamePlayer> potentialTargets = players.where((p) => p.name != currentPlayer.name).toList();

    // Filtre Mixte
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

    // Sécurité
    if (potentialTargets.isEmpty) {
      potentialTargets = List.from(players)..removeWhere((p) => p.name == currentPlayer.name);
    }
    
    // Remplacement du texte
    if (potentialTargets.isNotEmpty) {
      potentialTargets.shuffle();
      GamePlayer target = potentialTargets[0];
      text = text.replaceAll("{target}", target.name);
    } else {
      text = text.replaceAll("{target}", "quelqu'un"); // S'il joue tout seul lol
    }
    
    text = text.replaceAll("{player}", currentPlayer.name); 

    setState(() {
      currentQuestion = text;
      showNextButton = true;
    });
  }

  // 4. Passer au tour suivant
  void nextTurn() {
    setState(() {
      currentPlayerIndex = (currentPlayerIndex + 1) % players.length;
      currentQuestion = "Appuie sur un bouton !";
      showNextButton = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    // Écran de chargement si les joueurs ne sont pas encore arrivés de Firebase
    if (players.isEmpty) {
      return const Scaffold(
        backgroundColor: Color(0xFF101012),
        body: Center(child: CircularProgressIndicator(color: Colors.pinkAccent)),
      );
    }

    GamePlayer currentPlayer = players[currentPlayerIndex];

    // Design en fonction de la catégorie
    final Color themeColor = widget.category == 'Hot' || widget.category == 'Extrême'
      ? Colors.red.shade900
      : Colors.indigo.shade900;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
          onPressed: () {
            // Ici, plus tard, on pourra remettre le status du lobby sur 'waiting'
            Navigator.pop(context); 
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
              
              // Affichage du Mode et Catégorie en haut
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
                      key: ValueKey(currentQuestion),
                      padding: const EdgeInsets.all(30),
                      child: Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.9), // J'ai rendu la case blanche pour qu'on lise mieux
                          borderRadius: BorderRadius.circular(30),
                          boxShadow: [
                            BoxShadow(color: themeColor.withValues(alpha: 0.5), blurRadius: 20, spreadRadius: 5)
                          ]
                        ),
                        child: Text(
                          currentQuestion,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 24, 
                            fontWeight: FontWeight.w600,
                            color: Colors.black87,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              
              Padding(
                padding: const EdgeInsets.all(40),
                child: showNextButton
                    ? SizedBox(
                        width: double.infinity, 
                        child: _gameButton("TOUR SUIVANT ➔", Colors.blueAccent, nextTurn),
                      )
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          _gameButton("VÉRITÉ", const Color(0xFF22C55E), () => pickQuestion('verite')),
                          _gameButton("ACTION", const Color(0xFFEC4899), () => pickQuestion('action')),
                        ],
                      ),
              ),
            ],
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
    final List<dynamic> players; // Accepte ta liste de joueurs locaux

    CategoryScreen({super.key, required this.players});

    final List<Map<String, dynamic>> categories = [
      {'name': 'Classique', 'color': const Color(0xFF4ADE80), 'emoji': '🍭'},
      {'name': 'Soft', 'color': const Color(0xFF2DD4BF), 'emoji': '🏠'},
      {'name': 'Hot', 'color': const Color(0xFFE11D48), 'emoji': '🔥'},
      {'name': 'Extrême', 'color': const Color(0xFF8B5CF6), 'emoji': '😈'},
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
                // 1. On convertit tes anciens joueurs au nouveau format "GamePlayer"
                List<GamePlayer> formattedPlayers = players.map((p) => GamePlayer(
                  name: p.name, 
                  gender: p.gender
                )).toList();

                // 2. 🔥 ON LANCE LE JEU EN MODE LOCAL !
                Navigator.push(context, MaterialPageRoute(
                  builder: (context) => ActionVeriteScreen(
                    category: cat['name'], // La catégorie cliquée
                    isOnline: false,       // LE FAMEUX SWITCH MODE LOCAL
                    localPlayers: formattedPlayers, // On lui donne la liste des joueurs
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