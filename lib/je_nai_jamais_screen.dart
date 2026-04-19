import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:convert';
import 'dart:math';
import 'main.dart'; // 👈 Important pour accéder à la classe Player

class JeNaiJamaisScreen extends StatefulWidget {
  final List<Player> players; // 👈 On récupère la liste des joueurs
  const JeNaiJamaisScreen({super.key, required this.players});

  @override
  State<JeNaiJamaisScreen> createState() => _JeNaiJamaisScreenState();
}

class _JeNaiJamaisScreenState extends State<JeNaiJamaisScreen> {
  Map<String, dynamic> allQuestions = {};
  String currentQuestion = "Appuie sur la carte !";
  String selectedCategory = "";
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    loadQuestions();
  }

  Future<void> loadQuestions() async {
    try {
      final String response = await rootBundle.loadString('assets/je_nai_jamais.json');
      setState(() {
        allQuestions = json.decode(response);
        isLoading = false;
      });
    } catch (e) {
      print("Erreur : $e");
    }
  }

  void nextQuestion() {
    final questions = allQuestions[selectedCategory] as List;
    setState(() {
      currentQuestion = questions[Random().nextInt(questions.length)];
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F2027),
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
          onPressed: () {
            if (selectedCategory.isNotEmpty) {
              setState(() => selectedCategory = "");
            } else {
              Navigator.pop(context);
            }
          },
        ),
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF0F2027), Color(0xFF203A43), Color(0xFF2C5364)],
            begin: Alignment.topLeft, end: Alignment.bottomRight,
          ),
        ),
        child: isLoading 
          ? const Center(child: CircularProgressIndicator(color: Colors.white))
          : SafeArea(
              child: selectedCategory.isEmpty 
                  ? _buildCategorySelection() 
                  : _buildGameBoard(),
            ),
      ),
    );
  }

  Widget _buildCategorySelection() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text("CHOISIS TON AMBIANCE", 
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: 2)),
          const SizedBox(height: 40),
          _catButton("Soft", "😇", Colors.greenAccent),
          _catButton("Interdit", "🚫", Colors.orangeAccent),
          _catButton("+18", "🌶️", Colors.redAccent),
        ],
      ),
    );
  }

  Widget _catButton(String name, String emoji, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 10),
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: color.withValues(alpha: 0.2),
          foregroundColor: Colors.white,
          side: BorderSide(color: color, width: 2),
          minimumSize: const Size(double.infinity, 60),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        ),
        onPressed: () => setState(() { selectedCategory = name; nextQuestion(); }),
        child: Text("$emoji $name", style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
      ),
    );
  }

  Widget _buildGameBoard() {
    return Column(
      children: [
        const SizedBox(height: 20),
        Text("JE N'AI JAMAIS ($selectedCategory)", style: const TextStyle(color: Colors.white70)),
        const SizedBox(height: 30),
        
        // LA CARTE
        GestureDetector(
          onTap: nextQuestion,
          child: Container(
            width: MediaQuery.of(context).size.width * 0.85,
            height: 250,
            padding: const EdgeInsets.all(25),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(25),
              boxShadow: const [BoxShadow(color: Colors.black45, blurRadius: 15)],
            ),
            child: Center(
              child: Text(currentQuestion, textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 22, color: Colors.black87, fontWeight: FontWeight.bold)),
            ),
          ),
        ),

        const SizedBox(height: 30),
        const Text("QUI L'A DÉJÀ FAIT ?", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        const SizedBox(height: 10),

        // LISTE DES COMPTEURS
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            itemCount: widget.players.length,
            itemBuilder: (context, index) {
              final player = widget.players[index];
              return Card(
                color: Colors.white.withValues(alpha: 0.1),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: player.gender == 'H' ? Colors.blue : Colors.pinkAccent,
                    child: Text(player.name[0].toUpperCase(), style: const TextStyle(color: Colors.white)),
                  ),
                  title: Text(player.name, style: const TextStyle(color: Colors.white)),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text("${player.score}", style: const TextStyle(color: Colors.amber, fontSize: 22, fontWeight: FontWeight.bold)),
                      const SizedBox(width: 10),
                      IconButton(
                        icon: const Icon(Icons.add_circle, color: Colors.greenAccent),
                        onPressed: () => setState(() => player.score++),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}