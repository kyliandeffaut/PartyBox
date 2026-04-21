import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:convert';
import 'dart:math';
import 'package:flutter_animate/flutter_animate.dart';
import 'main.dart';

class JeNaiJamaisScreen extends StatefulWidget {
  final List<Player> players;
  const JeNaiJamaisScreen({super.key, required this.players});

  @override
  State<JeNaiJamaisScreen> createState() => _JeNaiJamaisScreenState();
}

class _JeNaiJamaisScreenState extends State<JeNaiJamaisScreen> {
  Map<String, dynamic> allQuestions = {};
  String currentQuestion = "Choisis une ambiance !";
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
      debugPrint("Erreur : $e");
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
        width: double.infinity,
        height: double.infinity,
        // 🌟 LE FOND NÉON IDENTIQUE AUX AUTRES
        decoration: const BoxDecoration(
          color: Color(0xFF101012),
          image: DecorationImage(
            image: AssetImage('assets/images/background.jpg'),
            fit: BoxFit.cover,
          ),
        ),
        child: isLoading 
          ? const Center(child: CircularProgressIndicator(color: Colors.purpleAccent))
          : SafeArea(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 500),
                child: selectedCategory.isEmpty 
                    ? _buildCategorySelection() 
                    : _buildGameBoard(),
              ),
            ),
      ),
    );
  }

  // --- 😇 SÉLECTION DES AMBIANCES ---
  Widget _buildCategorySelection() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text("QUELLE AMBIANCE ?", 
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: 4)),
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
      padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 12),
      child: InkWell(
        onTap: () => setState(() { selectedCategory = name; nextQuestion(); }),
        borderRadius: BorderRadius.circular(20),
        child: Container(
          height: 70,
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: [color.withValues(alpha: 0.3), color.withValues(alpha: 0.05)]),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: color.withValues(alpha: 0.5), width: 1.5),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(emoji, style: const TextStyle(fontSize: 26)),
              const SizedBox(width: 15),
              Text(name.toUpperCase(), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: 2)),
            ],
          ),
        ),
      ).animate().fadeIn(delay: 100.ms).slideX(begin: 0.2),
    );
  }

  // --- 🎮 PLATEAU DE JEU ---
  Widget _buildGameBoard() {
    return Column(
      children: [
        const SizedBox(height: 10),
        Text("JE N'AI JAMAIS • $selectedCategory", 
          style: const TextStyle(color: Colors.white54, fontWeight: FontWeight.bold, letterSpacing: 2)),
        const SizedBox(height: 20),
        
        // LA CARTE DE QUESTION GLASSMORPHISM
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 25),
          child: InkWell(
            onTap: nextQuestion,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(25),
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [Colors.white.withValues(alpha: 0.15), Colors.white.withValues(alpha: 0.05)]),
                borderRadius: BorderRadius.circular(30),
                border: Border.all(color: Colors.white24),
                boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.3), blurRadius: 20)],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(currentQuestion, textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 24, color: Colors.white, fontWeight: FontWeight.w800, height: 1.3)),
                  const SizedBox(height: 20),
                  const Text("Tapote pour changer 🔄", style: TextStyle(color: Colors.white38, fontSize: 12)),
                ],
              ),
            ),
          ).animate(key: ValueKey(currentQuestion)).fadeIn().scale(curve: Curves.easeOutBack),
        ),

        const SizedBox(height: 30),
        const Text("QUI L'A DÉJÀ FAIT ?", style: TextStyle(color: Colors.white70, fontWeight: FontWeight.w900, letterSpacing: 1)),
        const SizedBox(height: 15),

        // LISTE DES SCORES STYLISÉE
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            itemCount: widget.players.length,
            itemBuilder: (context, index) {
              final player = widget.players[index];
              return Container(
                margin: const EdgeInsets.only(bottom: 10),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(15),
                  border: Border.all(color: Colors.white10),
                ),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: player.gender == 'H' ? Colors.blueAccent : Colors.pinkAccent,
                    child: Text(player.name[0].toUpperCase(), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  ),
                  title: Text(player.name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _scoreBtn(Icons.remove_circle_outline, Colors.redAccent, () => setState(() { if (player.score > 0) player.score--; })),
                      Text("${player.score}", style: const TextStyle(color: Colors.amber, fontSize: 20, fontWeight: FontWeight.w900)),
                      _scoreBtn(Icons.add_circle_outline, Colors.greenAccent, () => setState(() => player.score++)),
                    ],
                  ),
                ),
              ).animate().fadeIn(delay: Duration(milliseconds: index * 100)).slideX(begin: 0.1);
            },
          ),
        ),
      ],
    );
  }

  Widget _scoreBtn(IconData icon, Color color, VoidCallback fn) {
    return IconButton(icon: Icon(icon, color: color, size: 26), onPressed: fn);
  }
}