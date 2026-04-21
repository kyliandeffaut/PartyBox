import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:convert';
import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'main.dart';

class JeNaiJamaisScreen extends StatefulWidget {
  final List<Player> players;
  final bool isOnline;
  final String? lobbyId;
  final String? currentPlayerName;

  const JeNaiJamaisScreen({
    super.key,
    required this.players,
    this.isOnline = false,
    this.lobbyId,
    this.currentPlayerName,
  });

  @override
  State<JeNaiJamaisScreen> createState() => _JeNaiJamaisScreenState();
}

class _JeNaiJamaisScreenState extends State<JeNaiJamaisScreen> {
  Map<String, dynamic> allQuestions = {};
  String currentQuestion = "Chargement...";
  String selectedCategory = "";
  bool isLoading = true;
  bool isHost = false;

  @override
  void initState() {
    super.initState();
    _initGame();
  }

  Future<void> _initGame() async {
    await loadQuestions();
    if (widget.isOnline && widget.lobbyId != null) {
      await _checkIfHost();
      _listenToLobby();
    } else {
      setState(() => isLoading = false);
    }
  }

  Future<void> _checkIfHost() async {
    var doc = await FirebaseFirestore.instance.collection('lobbies').doc(widget.lobbyId).get();
    if (doc.exists && doc.data()?['host'] == widget.currentPlayerName) {
      setState(() => isHost = true);
    }
  }

  void _listenToLobby() {
    FirebaseFirestore.instance.collection('lobbies').doc(widget.lobbyId).snapshots().listen((snapshot) {
      if (snapshot.exists && snapshot.data() != null) {
        var data = snapshot.data()!;
        if (mounted) {
          setState(() {
            currentQuestion = data['currentQuestion'] ?? "Le chef va choisir...";
            selectedCategory = data['selectedCategory'] ?? "";
            
            List<dynamic> fbPlayers = data['players'] ?? [];
            widget.players.clear();
            for (var p in fbPlayers) {
              widget.players.add(Player(
                name: p['name'], 
                gender: p['gender'], 
                score: p['score'] ?? 0
              ));
            }
            isLoading = false;
          });
        }
      }
    });
  }

  Future<void> loadQuestions() async {
    try {
      final String response = await rootBundle.loadString('assets/je_nai_jamais.json');
      allQuestions = json.decode(response);
    } catch (e) {
      debugPrint("Erreur chargement JSON: $e");
    }
  }

  void _selectCategory(String cat) {
    if (widget.isOnline) {
      if (!isHost) return;
      FirebaseFirestore.instance.collection('lobbies').doc(widget.lobbyId).update({
        'selectedCategory': cat,
      });
      nextQuestion(categoryOverride: cat);
    } else {
      setState(() {
        selectedCategory = cat;
        nextQuestion();
      });
    }
  }

  void nextQuestion({String? categoryOverride}) {
    String cat = categoryOverride ?? selectedCategory;
    final questions = allQuestions[cat] as List;
    String newQ = questions[Random().nextInt(questions.length)];

    if (widget.isOnline) {
      FirebaseFirestore.instance.collection('lobbies').doc(widget.lobbyId).update({
        'currentQuestion': newQ,
      });
    } else {
      setState(() => currentQuestion = newQ);
    }
  }

  void _updateScore(Player player, int delta) async {
    if (widget.isOnline) {
      if (player.name != widget.currentPlayerName) return;
      
      var docRef = FirebaseFirestore.instance.collection('lobbies').doc(widget.lobbyId);
      var doc = await docRef.get();
      List<dynamic> players = List.from(doc.data()?['players'] ?? []);
      
      for (var p in players) {
        if (p['name'] == widget.currentPlayerName) {
          p['score'] = (p['score'] ?? 0) + delta;
          if (p['score'] < 0) p['score'] = 0;
        }
      }
      await docRef.update({'players': players});
    } else {
      setState(() {
        player.score += delta;
        if (player.score < 0) player.score = 0;
      });
    }
  }

  void _quit() async {
    if (widget.isOnline && widget.lobbyId != null) {
      var docRef = FirebaseFirestore.instance.collection('lobbies').doc(widget.lobbyId);
      var doc = await docRef.get();
      if (doc.exists) {
        List<dynamic> players = List.from(doc.data()?['players'] ?? []);
        players.removeWhere((p) => p['name'] == widget.currentPlayerName);
        await docRef.update({'players': players});
      }
    }
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.white, size: 30),
          onPressed: _quit,
        ),
      ),
      body: Container(
        width: double.infinity, height: double.infinity,
        decoration: const BoxDecoration(
          color: Color(0xFF101012),
          image: DecorationImage(image: AssetImage('assets/images/background.jpg'), fit: BoxFit.cover),
        ),
        child: isLoading 
          ? const Center(child: CircularProgressIndicator(color: Colors.purpleAccent))
          : SafeArea(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 400),
                child: selectedCategory.isEmpty 
                  ? _buildCategorySelection() 
                  : _buildGameBoard(),
              ),
            ),
      ),
    );
  }

  Widget _buildCategorySelection() {
    bool canSelect = !widget.isOnline || isHost;
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(canSelect ? "CHOISIS L'AMBIANCE" : "LE CHEF CHOISIT...", 
          style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900, letterSpacing: 2)),
        const SizedBox(height: 40),
        if (canSelect) ...[
          _catButton("Soft", "😇", Colors.greenAccent),
          _catButton("Interdit", "🚫", Colors.orangeAccent),
          _catButton("+18", "🌶️", Colors.redAccent),
        ] else 
          const CircularProgressIndicator(color: Colors.white24),
      ],
    );
  }

  Widget _catButton(String name, String emoji, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 10),
      child: InkWell(
        onTap: () => _selectCategory(name),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: [color.withValues(alpha: 0.3), color.withValues(alpha: 0.05)]),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: color.withValues(alpha: 0.5)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(emoji, style: const TextStyle(fontSize: 24)),
              const SizedBox(width: 15),
              Text(name.toUpperCase(), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
            ],
          ),
        ),
      ).animate().fadeIn().slideX(),
    );
  }

  Widget _buildGameBoard() {
    bool canChange = !widget.isOnline || isHost;
    return Column(
      children: [
        Text("JE N'AI JAMAIS • $selectedCategory", style: const TextStyle(color: Colors.white54, fontWeight: FontWeight.bold)),
        const SizedBox(height: 20),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 25),
          child: InkWell(
            onTap: canChange ? nextQuestion : null,
            child: Container(
              width: double.infinity, padding: const EdgeInsets.all(30),
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [Colors.white.withValues(alpha: 0.1), Colors.white.withValues(alpha: 0.02)]),
                borderRadius: BorderRadius.circular(30),
                border: Border.all(color: Colors.white10),
              ),
              child: Column(
                children: [
                  Text(currentQuestion, textAlign: TextAlign.center, 
                    style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w800)),
                  if (canChange) const Padding(padding: EdgeInsets.only(top: 20), child: Text("Tapote pour changer 🔄", style: TextStyle(color: Colors.white38, fontSize: 12))),
                ],
              ),
            ),
          ).animate(key: ValueKey(currentQuestion)).fadeIn().scale(),
        ),
        const SizedBox(height: 30),
        const Text("SCORES", style: TextStyle(color: Colors.white70, fontWeight: FontWeight.w900)),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(20),
            itemCount: widget.players.length,
            itemBuilder: (context, index) {
              final player = widget.players[index];
              bool isMe = widget.isOnline && player.name == widget.currentPlayerName;
              return Container(
                margin: const EdgeInsets.only(bottom: 10),
                decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.05), borderRadius: BorderRadius.circular(15)),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: player.gender == 'H' ? Colors.blueAccent : Colors.pinkAccent,
                    child: Text(player.name[0], style: const TextStyle(color: Colors.white)),
                  ),
                  title: Text(player.name + (isMe ? " (Moi)" : ""), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (!widget.isOnline || isMe) 
                        IconButton(icon: const Icon(Icons.remove_circle_outline, color: Colors.redAccent), onPressed: () => _updateScore(player, -1)),
                      Text("${player.score}", style: const TextStyle(color: Colors.amber, fontSize: 22, fontWeight: FontWeight.bold)),
                      if (!widget.isOnline || isMe) 
                        IconButton(icon: const Icon(Icons.add_circle_outline, color: Colors.greenAccent), onPressed: () => _updateScore(player, 1)),
                    ],
                  ),
                ),
              ).animate().fadeIn(delay: Duration(milliseconds: index * 50));
            },
          ),
        ),
      ],
    );
  }
}