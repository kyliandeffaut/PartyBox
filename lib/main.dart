import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'action_verite_screen.dart';
import 'je_nai_jamais_screen.dart';

void main() {
  runApp(const ActionVeriteApp());
}

// 1. LA CLASSE PLAYER (Modèle de données)
class Player {
  String name;
  String gender; // 'H' pour Homme, 'F' pour Femme
  int score;
  Player({required this.name, required this.gender, this.score = 0});
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
            colors: [Color(0xFF0f0c29), Color(0xFF302b63), Color(0xFF24243e)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
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
                    fillColor: Colors.white.withValues(alpha: 0.05),
                    suffixIcon: IconButton(icon: const Icon(Icons.add_circle, color: Colors.greenAccent), onPressed: addPlayer),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(15)),
                  ),
                  onSubmitted: (_) => addPlayer(),
                ),
              ),
              
              Expanded(
                child: ListView.builder(
                  itemCount: players.length,
                  itemBuilder: (context, index) => Card(
                    color: Colors.white.withValues(alpha: 0.1),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                    margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 5), // Ajoute de l'espace entre les joueurs
                    child: ListTile(
                      leading: Icon(
                        players[index].gender == 'H' ? Icons.male : Icons.female,
                        color: players[index].gender == 'H' ? Colors.blue : Colors.pinkAccent,
                      ),
                      title: Text(players[index].name, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
                      trailing: IconButton(
                        icon: const Icon(Icons.remove_circle, color: Colors.redAccent),
                        onPressed: () => setState(() => players.removeAt(index)),
                      ),
                    ),
                  )
                  .animate() // L'animation !
                  .fade(duration: 400.ms)
                  .slideX(begin: 0.5, end: 0, curve: Curves.easeOutBack),
                ),
              ),

              if (players.length >= 2)
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: GestureDetector(
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => GameSelectionScreen(players: players))),
                    child: Container(
                      width: double.infinity,
                      height: 60,
                      decoration: BoxDecoration(
                        color: const Color(0xFF101012), 
                        image: DecorationImage(
                          image: const AssetImage('assets/images/background.jpg'), // 👈 Remplace par le bon nom !
                          fit: BoxFit.cover, // Prends tout l'écran
                          colorFilter: ColorFilter.mode(
                            Colors.black.withValues(alpha: 0.5), // Ajuste l'alpha (0.0 à 1.0) pour assombrir plus ou moins
                            BlendMode.darken,
                          ),
                        ),
                      ),
                      child: const Center(
                        child: Text(
                          "C'EST PARTI !",
                          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: 2),
                        ),
                      ),
                    )
                    .animate(onPlay: (controller) => controller.repeat(reverse: true))
                    .scaleXY(end: 1.03, duration: 1.seconds)
                    .shimmer(delay: 2.seconds, duration: 1.seconds),
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

// --- ÉCRAN : SÉLECTION DU JEU ---
class GameSelectionScreen extends StatelessWidget {
  final List<Player> players;
  const GameSelectionScreen({super.key, required this.players});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
          onPressed: () => Navigator.pop(context), // Retourne à l'ajout des joueurs
        ),
      ),
      body: Container(
        width: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF1A1A2E), Color(0xFF101012)],
            begin: Alignment.topCenter, end: Alignment.bottomCenter,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text("CHOISIS TON JEU", style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, letterSpacing: 2)),
            const SizedBox(height: 50),
            
            _menuCard(context, "Action ou Vérité", "🎭", const Color.fromARGB(255, 251, 64, 64), () {
              Navigator.push(context, MaterialPageRoute(builder: (context) => CategoryScreen(players: players)));
            }),
            
            const SizedBox(height: 20),
            
            _menuCard(context, "Je n'ai jamais", "🤫", Colors.deepPurpleAccent, () {
              Navigator.push(context, MaterialPageRoute(builder: (context) => JeNaiJamaisScreen(players: players)));
            }),
          ],
        ),
      ),
    );
  }

  Widget _menuCard(BuildContext context, String title, String emoji, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: MediaQuery.of(context).size.width * 0.8,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withValues(alpha: 0.5), width: 2),
        ),
        child: Row(
          children: [
            Text(emoji, style: const TextStyle(fontSize: 30)),
            const SizedBox(width: 20),
            Text(title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }
}