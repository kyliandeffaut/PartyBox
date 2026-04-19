import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:flutter/services.dart';
import 'dart:math';

void main() {
  runApp(const ActionVeriteApp());
}

// 1. LA CLASSE PLAYER (Modèle de données)
class Player {
  String name;
  String gender; // 'H' pour Homme, 'F' pour Femme
  Player({required this.name, required this.gender});
}

class ActionVeriteApp extends StatelessWidget {
  const ActionVeriteApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF101012),
      ),
      home: const PlayerScreen(),
    );
  }
}

// --- ÉCRAN 1 : SAISIE DES JOUEURS ---
class PlayerScreen extends StatefulWidget {
  const PlayerScreen({super.key});

  @override
  State<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends State<PlayerScreen> {
  final List<Player> players = []; // Liste d'objets Player maintenant
  final TextEditingController _controller = TextEditingController();
  String selectedGender = 'H'; // Genre sélectionné par défaut

  void addPlayer() {
    if (_controller.text.trim().isNotEmpty) {
      setState(() {
        players.add(Player(
          name: _controller.text.trim(),
          gender: selectedGender,
        ));
        _controller.clear();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF1A1A2E), Color(0xFF101012)],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              const SizedBox(height: 40),
              const Text("QUI JOUE ?", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, letterSpacing: 2)),
              
              const SizedBox(height: 20),
              // SÉLECTEUR DE GENRE
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _genderButton("HOMME", 'H'),
                  const SizedBox(width: 15),
                  _genderButton("FEMME", 'F'),
                ],
              ),

              Padding(
                padding: const EdgeInsets.all(20.0),
                child: TextField(
                  controller: _controller,
                  decoration: InputDecoration(
                    hintText: "Entrez un prénom...",
                    filled: true,
                    fillColor: Colors.white.withOpacity(0.05),
                    suffixIcon: IconButton(icon: const Icon(Icons.add_circle, color: Colors.greenAccent), onPressed: addPlayer),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(15)),
                  ),
                  onSubmitted: (_) => addPlayer(),
                ),
              ),
              
              Expanded(
                child: ListView.builder(
                  itemCount: players.length,
                  itemBuilder: (context, index) => ListTile(
                    leading: Icon(
                      players[index].gender == 'H' ? Icons.male : Icons.female,
                      color: players[index].gender == 'H' ? Colors.blue : Colors.pinkAccent,
                    ),
                    title: Text(players[index].name),
                    trailing: IconButton(
                      icon: const Icon(Icons.remove_circle, color: Colors.redAccent),
                      onPressed: () => setState(() => players.removeAt(index)),
                    ),
                  ),
                ),
              ),

              if (players.length >= 2)
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blueAccent,
                      minimumSize: const Size(double.infinity, 55),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                    ),
                    onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => CategoryScreen(players: players))),
                    child: const Text("C'EST PARTI !", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _genderButton(String label, String gender) {
    bool isSelected = selectedGender == gender;
    return GestureDetector(
      onTap: () => setState(() => selectedGender = gender),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? (gender == 'H' ? Colors.blue : Colors.pinkAccent) : Colors.white10,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: isSelected ? Colors.white : Colors.white24),
        ),
        child: Text(label, style: TextStyle(fontWeight: FontWeight.bold, color: isSelected ? Colors.white : Colors.white38)),
      ),
    );
  }
}

// --- ÉCRAN 2 : SÉLECTION DES CATÉGORIES ---
class CategoryScreen extends StatelessWidget {
  final List<Player> players; // Liste de Player
  CategoryScreen({super.key, required this.players});

  final List<Map<String, dynamic>> categories = [
    {'name': 'Soft', 'color': Colors.greenAccent.shade400},
    {'name': 'Famille', 'color': Colors.greenAccent.shade400},
    {'name': 'Dehors', 'color': Colors.blueAccent.shade400},
    {'name': 'Sport', 'color': Colors.blueAccent.shade400},
    {'name': 'Bar', 'color': Colors.blueAccent.shade400},
    {'name': 'Sans Filtre', 'color': Colors.orangeAccent.shade400},
    {'name': 'Séduction', 'color': Colors.redAccent.shade400},
    {'name': 'Couple', 'color': Colors.redAccent.shade400},
    {'name': 'Hot', 'color': Colors.redAccent.shade400},
    {'name': 'Hard', 'color': Colors.redAccent.shade400},
    {'name': 'Nudité', 'color': Colors.redAccent.shade400},
    {'name': 'BDSM', 'color': Colors.redAccent.shade400},
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
          onPressed: () {
            Navigator.pop(context);
          },
        ),
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(colors: [Color(0xFF1A1A2E), Color(0xFF101012)]),
        ),
        child: SafeArea(
          child: Column(
            children: [
              const SizedBox(height: 20),
              const Text("ACTION OU VÉRITÉ", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, letterSpacing: 3)),
              const SizedBox(height: 20),
              Expanded(
                child: GridView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2, childAspectRatio: 2.2, crossAxisSpacing: 15, mainAxisSpacing: 15
                  ),
                  itemCount: categories.length,
                  itemBuilder: (context, index) {
                    final cat = categories[index];
                    return ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: cat['color'].withOpacity(0.15),
                        foregroundColor: cat['color'],
                        side: BorderSide(color: cat['color'], width: 1.5),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                      ),
                      onPressed: () {
                        Navigator.push(context, MaterialPageRoute(
                          builder: (context) => GameScreen(category: cat['name'], players: players),
                        ));
                      },
                      child: Text(cat['name'], textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.bold)),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// --- ÉCRAN 3 : LE JEU ---
class GameScreen extends StatefulWidget {
  final String category;
  final List<Player> players;
  const GameScreen({super.key, required this.category, required this.players});

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  List<dynamic> allQuestions = [];
  String currentQuestion = "Appuie sur un bouton !";
  Player? currentPlayer;

  int currentPlayerIndex = 0;

  @override
  void initState() {
    super.initState();
    loadQuestions();
    currentPlayer = widget.players[0]; 
    currentPlayerIndex = 0;
  }

  Future<void> loadQuestions() async {
    final String response = await rootBundle.loadString('assets/questions.json');
    final data = await json.decode(response);
    setState(() { allQuestions = data; });
  }

  void pickQuestion(String type) {
    if (allQuestions.isEmpty) return;

    var filtered = allQuestions.where((q) => q['type'] == type && q['category'] == widget.category).toList();
    if (filtered.isEmpty) return;

    final random = Random();
    var questionData = filtered[random.nextInt(filtered.length)];
    String text = questionData['text'];

    // 1. On prépare la liste des cibles possibles (tout le monde sauf le joueur actuel)
    List<Player> potentialTargets = List.from(widget.players)..remove(currentPlayer);

    // 2. LE FILTRE MAGIQUE HOMME/FEMME
    bool hasMen = widget.players.any((p) => p.gender == 'H');
    bool hasWomen = widget.players.any((p) => p.gender == 'F');
    bool isMixedGroup = hasMen && hasWomen; // Vrai s'il y a au moins 1 homme et 1 femme

    // Si le groupe est mixte, on applique les règles strictes
    if (isMixedGroup) {
      if (questionData['target'] == 'opposite') {
        // On veut le sexe opposé (Homme -> Femme / Femme -> Homme)
        potentialTargets = potentialTargets.where((p) => p.gender != currentPlayer!.gender).toList();
      } else if (questionData['target'] == 'same') {
        // On veut le même sexe
        potentialTargets = potentialTargets.where((p) => p.gender == currentPlayer!.gender).toList();
      } else if (questionData['target'] == 'homme') {
        potentialTargets = potentialTargets.where((p) => p.gender == 'H').toList();
      } else if (questionData['target'] == 'femme') {
        potentialTargets = potentialTargets.where((p) => p.gender == 'F').toList();
      }
    }
    // SI LE GROUPE N'EST PAS MIXTE (que des H ou que des F), 
    // le code ignore les "if" ci-dessus et prend n'importe qui !

    // Sécurité au cas où il n'y a plus de cible valide
    if (potentialTargets.isEmpty) {
      potentialTargets = List.from(widget.players)..remove(currentPlayer);
    }
    
    potentialTargets.shuffle();
    Player target = potentialTargets[0];

    // 3. On remplace les mots par les vrais prénoms
    text = text.replaceAll("{player}", currentPlayer!.name); 
    text = text.replaceAll("{target}", target.name);

    setState(() {
      currentQuestion = text;
      currentPlayerIndex = (currentPlayerIndex + 1) % widget.players.length;
      currentPlayer = widget.players[currentPlayerIndex];
    });
  }

  @override
  Widget build(BuildContext context) {
    final topColor = widget.category == 'Hot' || widget.category == 'Hard' || widget.category == 'BDSM'
        ? const Color(0xFF450000)
        : Colors.blueGrey.shade900;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(title: Text(widget.category), centerTitle: true, backgroundColor: Colors.transparent, elevation: 0),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [topColor, const Color(0xFF101012)],
            stops: const [0.0, 0.7],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              const SizedBox(height: 20),
              const Text("C'EST AU TOUR DE :", style: TextStyle(color: Colors.white54, letterSpacing: 2)),
              Text(currentPlayer?.name.toUpperCase() ?? "", style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w900, color: Colors.white)),              
              Expanded(
                child: Center(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 400),
                    child: Padding(
                      key: ValueKey(currentQuestion),
                      padding: const EdgeInsets.all(25),
                      child: Text(currentQuestion, textAlign: TextAlign.center, style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
                    ),
                  ),
                ),
              ),
              
              Padding(
                padding: const EdgeInsets.all(40),
                child: Row(
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
      child: Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
    );
  }
}