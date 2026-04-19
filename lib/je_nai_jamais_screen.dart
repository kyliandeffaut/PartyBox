import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:convert';
import 'dart:math';

class JeNaiJamaisScreen extends StatefulWidget {
  const JeNaiJamaisScreen({super.key});

  @override
  State<JeNaiJamaisScreen> createState() => _JeNaiJamaisScreenState();
}

class _JeNaiJamaisScreenState extends State<JeNaiJamaisScreen> {
  Map<String, dynamic> allQuestions = {};
  String currentQuestion = "Appuie sur la carte pour commencer !"; // Un petit message plus sympa
  String currentCategory = ""; 
  bool isLoading = true; // Pour éviter de cliquer avant que le JSON soit chargé

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
    if (allQuestions.isEmpty) return;

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
      // 1. On force la couleur de fond du Scaffold
      backgroundColor: const Color(0xFF0F2027),
      extendBodyBehindAppBar: true,
      
      // 2. On ajoute l'AppBar pour le bouton de retour
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),

      body: Container(
        width: double.infinity,
        height: double.infinity, // 3. On s'assure que le container prend TOUT l'écran
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF0F2027), Color(0xFF203A43), Color(0xFF2C5364)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: isLoading 
          ? const Center(child: CircularProgressIndicator(color: Colors.white))
          : SafeArea(
              child: Center( // 4. On centre le contenu pour éviter les bugs visuels
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text(
                      "JE N'AI JAMAIS...", 
                      style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: 2)
                    ),
                    const SizedBox(height: 50),
                    
                    // LA CARTE DE JEU
                    GestureDetector(
                      onTap: nextQuestion,
                      child: Container(
                        width: MediaQuery.of(context).size.width * 0.85,
                        height: 350,
                        padding: const EdgeInsets.all(30),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(30),
                          boxShadow: const [
                            BoxShadow(color: Colors.black45, blurRadius: 20, offset: Offset(0, 10))
                          ],
                        ),
                        child: Center(
                          child: Text(
                            currentQuestion,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 24, 
                              color: Colors.black87, 
                              fontWeight: FontWeight.bold,
                              fontStyle: FontStyle.italic
                            ),
                          ),
                        ),
                      ),
                    ),
                    
                    const SizedBox(height: 30),
                    if (currentCategory.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(15),
                        ),
                        child: Text(
                          "Catégorie : $currentCategory", 
                          style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.w500)
                        ),
                      ),
                    
                    const SizedBox(height: 50),
                    const Text(
                      "Appuie sur la carte pour changer", 
                      style: TextStyle(color: Colors.white54, fontSize: 14)
                    ),
                  ],
                ),
              ),
            ),
      ),
    );
  }
}