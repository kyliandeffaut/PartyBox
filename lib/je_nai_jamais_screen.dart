import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // Pour charger le JSON
import 'dart:convert'; // Pour décoder le JSON
import 'dart:math'; // Pour le hasard (Random)

class JeNaiJamaisScreen extends StatefulWidget {
  const JeNaiJamaisScreen({super.key});

  @override
  State<JeNaiJamaisScreen> createState() => _JeNaiJamaisScreenState();
}

class _JeNaiJamaisScreenState extends State<JeNaiJamaisScreen> {
  Map<String, dynamic> allQuestions = {};
  String currentQuestion = "Appuie pour commencer !";
  String currentCategory = "Soft";

  @override
  void initState() {
    super.initState();
    loadQuestions();
  }

  Future<void> loadQuestions() async {
    final String response = await rootBundle.loadString('assets/je_nai_jamais.json');
    setState(() {
      allQuestions = json.decode(response);
    });
  }

  void nextQuestion() {
    final categories = allQuestions.keys.toList();
    final randomCat = categories[Random().nextInt(categories.length)];
    final questions = allQuestions[randomCat] as List;
    
    setState(() {
      currentCategory = randomCat;
      currentQuestion = questions[Random().nextInt(questions.length)];
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF0F2027), Color(0xFF203A43), Color(0xFF2C5364)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              const SizedBox(height: 50),
              const Text("JE N'AI JAMAIS...", 
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: 2)),
              const Spacer(),
              
              // LA CARTE DE JEU
              GestureDetector(
                onTap: nextQuestion,
                child: Container(
                  width: MediaQuery.of(context).size.width * 0.8,
                  height: 300,
                  padding: const EdgeInsets.all(25),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(30),
                    boxShadow: [BoxShadow(color: Colors.black45, blurRadius: 20, offset: Offset(0, 10))],
                  ),
                  child: Center(
                    child: Text(
                      currentQuestion,
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 22, color: Colors.black87, fontWeight: FontWeight.w500),
                    ),
                  ),
                ),
              ),
              
              const SizedBox(height: 20),
              Text("Catégorie : $currentCategory", style: TextStyle(color: Colors.white70)),
              
              const Spacer(),
              const Text("Appuie sur la carte pour changer", style: TextStyle(color: Colors.white54)),
              const SizedBox(height: 30),
            ],
          ),
        ),
      ),
    );
  }
}