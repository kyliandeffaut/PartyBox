import 'package:flutter/material.dart';
import 'action_verite_screen.dart';
import 'je_nai_jamais_screen.dart';

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
            colors: [Color(0xFF240b36), Color(0xFFc31432)],
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
                    onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => GameSelectionScreen(players: players))),
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

// --- ÉCRAN : SÉLECTION DU JEU ---
class GameSelectionScreen extends StatelessWidget {
  final List<Player> players;
  const GameSelectionScreen({super.key, required this.players});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
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
              Navigator.push(context, MaterialPageRoute(builder: (context) => const JeNaiJamaisScreen()));
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