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
  bool hasVotedThisTurn = false;
  
  bool _canPop = false; // 🛡️ Autorise la fermeture propre de l'écran

  bool _localSecretMode = false;
  bool _localGameEnded = false;

  List<Map<String, dynamic>> _awardDataFromOnlinePlayers(List<dynamic> fbPlayers) {
    return fbPlayers
        .whereType<Map>()
        .map((p) => {
              'name': (p['name'] ?? '').toString(),
              'score': (p['score'] ?? 0) as int,
            })
        .where((p) => (p['name'] as String).isNotEmpty)
        .toList();
  }

  List<Map<String, dynamic>> _awardDataFromLocalPlayers() {
    return widget.players
        .map((p) => {'name': p.name, 'score': p.score})
        .where((p) => (p['name'] as String).isNotEmpty)
        .toList();
  }

  String _joinWinners(List<Map<String, dynamic>> winners) {
    final names = winners.map((p) => p['name'] as String).toList();
    return names.join(', ');
  }

  Widget _awardTile({
    required String emoji,
    required String title,
    required String subtitle,
    required Color color,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 25, vertical: 6),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.06),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.35)),
        boxShadow: [BoxShadow(color: color.withOpacity(0.12), blurRadius: 12, offset: const Offset(0, 8))],
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: color.withOpacity(0.35)),
            ),
            child: Center(child: Text(emoji, style: const TextStyle(fontSize: 22))),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900)),
                const SizedBox(height: 2),
                Text(subtitle, style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.w600)),
              ],
            ),
          ),
        ],
      ),
    ).animate().fadeIn().slideY(begin: 0.15, end: 0);
  }

  Widget _buildAwards(List<Map<String, dynamic>> players) {
    if (players.isEmpty) return const SizedBox();

    final sortedDesc = [...players]..sort((a, b) => (b['score'] as int).compareTo(a['score'] as int));
    final sortedAsc = [...players]..sort((a, b) => (a['score'] as int).compareTo(b['score'] as int));

    final topScore = sortedDesc.first['score'] as int;
    final lowScore = sortedAsc.first['score'] as int;

    final topWinners = sortedDesc.where((p) => p['score'] == topScore).toList();
    final lowWinners = sortedAsc.where((p) => p['score'] == lowScore).toList();

    final int range = (topScore - lowScore).abs();

    return Column(
      children: [
        const SizedBox(height: 8),
        const Text("AWARDS", style: TextStyle(color: Colors.white70, fontWeight: FontWeight.w900, letterSpacing: 2)),
        const SizedBox(height: 8),
        _awardTile(
          emoji: "😈",
          title: "Le plus diabolique",
          subtitle: "${_joinWinners(topWinners)} • $topScore point(s)",
          color: Colors.redAccent,
        ),
        _awardTile(
          emoji: "😇",
          title: "L'ange de la soirée",
          subtitle: "${_joinWinners(lowWinners)} • $lowScore point(s)",
          color: Colors.greenAccent,
        ),
        _awardTile(
          emoji: "🎢",
          title: "Écart",
          subtitle: "Différence max • $range point(s)",
          color: Colors.purpleAccent,
        ),
        const SizedBox(height: 10),
      ],
    );
  }

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
      // Offline: la liste de joueurs peut être réutilisée entre parties,
      // donc on repart toujours avec des scores propres.
      for (final p in widget.players) {
        p.score = 0;
      }
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
            selectedCategory = data['category'] ?? data['selectedCategory'] ?? ""; 
            currentQuestion = data['currentQuestion'] ?? "Le chef choisit...";
            
            // ✅ ON LIT SEULEMENT LES JOUEURS ACTIFS EN JEU !
            List<dynamic> fbPlayers = data['activePlayers'] ?? [];
            widget.players.clear();
            bool amIVoted = false;
            
            for (var p in fbPlayers) {
              if (p['name'] == widget.currentPlayerName) amIVoted = p['hasVoted'] ?? false;
              widget.players.add(Player(
                name: p['name'], 
                gender: p['gender'], 
                score: p['score'] ?? 0,
              ));
            }
            hasVotedThisTurn = amIVoted;
            isLoading = false;
          });

          // ✅ PIOCHE AUTO SI NOUVELLE PARTIE
          if (isHost && selectedCategory.isNotEmpty && (data['currentQuestion'] == null || data['currentQuestion'] == "Le chef choisit...")) {
            nextQuestionOnline();
          }
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

  void _voteOnline(bool hasDoneIt) async {
    if (hasVotedThisTurn || widget.lobbyId == null) return;

    var docRef = FirebaseFirestore.instance.collection('lobbies').doc(widget.lobbyId);
    var doc = await docRef.get();
    
    // On met à jour activePlayers ET players pour tout garder en sécurité
    List<dynamic> activeP = List.from(doc.data()?['activePlayers'] ?? []);
    List<dynamic> allP = List.from(doc.data()?['players'] ?? []);
    
    for (var p in activeP) {
      if (p['name'] == widget.currentPlayerName) {
        p['hasVoted'] = true;
        p['lastVote'] = hasDoneIt ? 'deja_fait' : 'jamais';
        if (hasDoneIt) p['score'] = (p['score'] ?? 0) + 1;
      }
    }
    for (var p in allP) {
      if (p['name'] == widget.currentPlayerName) {
        p['hasVoted'] = true;
        p['lastVote'] = hasDoneIt ? 'deja_fait' : 'jamais';
        if (hasDoneIt) p['score'] = (p['score'] ?? 0) + 1;
      }
    }
    await docRef.update({'activePlayers': activeP, 'players': allP});
  }

  void nextQuestionOnline() async {
    if (selectedCategory.isEmpty || !allQuestions.containsKey(selectedCategory)) return;
    
    final questions = allQuestions[selectedCategory] as List;
    String newQ = questions[Random().nextInt(questions.length)];

    var docRef = FirebaseFirestore.instance.collection('lobbies').doc(widget.lobbyId);
    var doc = await docRef.get();
    
    List<dynamic> activeP = List.from(doc.data()?['activePlayers'] ?? []);
    List<dynamic> allP = List.from(doc.data()?['players'] ?? []);

    for (var p in activeP) {
      p['hasVoted'] = false;
      p['lastVote'] = null; 
    }
    for (var p in allP) {
      p['hasVoted'] = false;
      p['lastVote'] = null; 
    }

    await docRef.update({
      'currentQuestion': newQ,
      'activePlayers': activeP,
      'players': allP,
    });
  }

  void _selectCategory(String cat) {
    if (widget.isOnline) {
      if (!isHost) return;
      FirebaseFirestore.instance.collection('lobbies').doc(widget.lobbyId).update({
        'category': cat,
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

  void _updateScoreLocal(Player player, int delta) {
    setState(() {
      player.score += delta;
      if (player.score < 0) player.score = 0;
    });
  }

  // ✅ CORRECTION DU BOUTON RETOUR QUI ÉJECTAIT LE JOUEUR
  void _quit() async {
    if (widget.isOnline && widget.lobbyId != null) {
      var docRef = FirebaseFirestore.instance.collection('lobbies').doc(widget.lobbyId);
      var doc = await docRef.get();
      if (doc.exists) {
        // On le retire JUSTE de activePlayers pour qu'il retourne au lobby en mode prêt/attente
        List activeP = List.from(doc.data()?['activePlayers'] ?? []);
        activeP.removeWhere((p) => p['name'] == widget.currentPlayerName);
        await docRef.update({'activePlayers': activeP});
      }
    }
    if (mounted) {
      setState(() => _canPop = true); // Autorise la fermeture
      Navigator.pop(context); // Retourne en arrière
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _canPop, // Utilise la sécurité pour le bouton retour natif
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        _quit();
      },
      child: Scaffold(
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
            image: DecorationImage(image: AssetImage('assets/images/background.jpg'), fit: BoxFit.cover, opacity: 0.3),
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

        if (!widget.isOnline) ...[
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 40),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.05),
              borderRadius: BorderRadius.circular(15),
              border: Border.all(color: Colors.white10),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text("Mode Secret 🤫", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                Switch(
                  value: _localSecretMode,
                  activeColor: Colors.purpleAccent,
                  inactiveThumbColor: Colors.grey,
                  inactiveTrackColor: Colors.white12,
                  onChanged: (val) => setState(() => _localSecretMode = val),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
        ],

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
            gradient: LinearGradient(colors: [color.withOpacity(0.3), color.withOpacity(0.05)]),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: color.withOpacity(0.5)),
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
    return StreamBuilder<DocumentSnapshot>(
      stream: widget.isOnline ? FirebaseFirestore.instance.collection('lobbies').doc(widget.lobbyId).snapshots() : null,
      builder: (context, snapshot) {
        List<dynamic> currentPlayersFB = [];
        bool allVoted = false;
        String visibilityMode = 'visible';
        bool gameEnded = false;

        if (widget.isOnline && snapshot.hasData && snapshot.data!.exists) {
          var data = snapshot.data!.data() as Map<String, dynamic>;
          
          // ✅ ON UTILISE ACTIVE PLAYERS ICI !
          currentPlayersFB = data['activePlayers'] ?? [];
          
          allVoted = currentPlayersFB.isNotEmpty && currentPlayersFB.every((p) => p['hasVoted'] == true);
          visibilityMode = data['jnjVisibility'] ?? 'visible';
          gameEnded = data['jnjGameEnded'] ?? false;
        } else if (!widget.isOnline) {
          visibilityMode = _localSecretMode ? 'invisible' : 'visible';
          gameEnded = _localGameEnded;
        }

        return Column(
          children: [
            Text(gameEnded ? "🏆 CLASSEMENT FINAL 🏆" : "JE N'AI JAMAIS • ${selectedCategory.toUpperCase()}", style: TextStyle(color: gameEnded ? Colors.amber : Colors.white54, fontWeight: FontWeight.bold, fontSize: gameEnded ? 20 : 14)),
            const SizedBox(height: 20),
            
            if (!gameEnded) ...[
              _buildQuestionCard(),
              const SizedBox(height: 15),
            ] else ...[
              _buildAwards(
                widget.isOnline ? _awardDataFromOnlinePlayers(currentPlayersFB) : _awardDataFromLocalPlayers(),
              ),
            ],

            if (widget.isOnline && visibilityMode == 'invisible' && allVoted && !gameEnded)
              _buildInvisibleTotalReveal(currentPlayersFB),
            
            if (widget.isOnline && !hasVotedThisTurn && !gameEnded) 
              _buildOnlineVoteActions(),
            
            const SizedBox(height: 20),
            const Text("SCORES", style: TextStyle(color: Colors.white70, fontWeight: FontWeight.w900)),
            
            Expanded(child: _buildPlayerList(currentPlayersFB, visibilityMode, gameEnded)),

            if (widget.isOnline) ...[
              if (gameEnded)
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, minimumSize: const Size(double.infinity, 50), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))),
                    onPressed: _quit,
                    child: const Text("RETOURNER AU LOBBY", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  ),
                ).animate().fadeIn()
              else if (isHost && allVoted) 
                _buildNextAndEndButtonsOnline()
            ] else ...[
              _buildNextButtonLocal()
            ],
          ],
        );
      }
    );
  }

  Widget _buildInvisibleTotalReveal(List<dynamic> players) {
    int totalDejaFait = players.where((p) => p['lastVote'] == 'deja_fait').length;
    return Container(
      margin: const EdgeInsets.only(bottom: 15, left: 25, right: 25),
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.purpleAccent.withOpacity(0.2),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: Colors.purpleAccent.withOpacity(0.5))
      ),
      child: Text(
        "Révélation : $totalDejaFait personne(s) l'a déjà fait !",
        textAlign: TextAlign.center,
        style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)
      )
    ).animate().fadeIn().scale();
  }

  Widget _buildQuestionCard() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 25),
      child: Container(
        width: double.infinity, padding: const EdgeInsets.all(30),
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: [Colors.white.withOpacity(0.1), Colors.white.withOpacity(0.02)]),
          borderRadius: BorderRadius.circular(30),
          border: Border.all(color: Colors.white10),
        ),
        child: Text(currentQuestion, textAlign: TextAlign.center, 
          style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w800)),
      ),
    ).animate(key: ValueKey(currentQuestion)).fadeIn().scale();
  }

  Widget _buildOnlineVoteActions() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _voteBtn("JAMAIS", Colors.redAccent, () => _voteOnline(false)),
        const SizedBox(width: 20),
        _voteBtn("DÉJÀ FAIT", Colors.greenAccent, () => _voteOnline(true)),
      ],
    ).animate().fadeIn();
  }

  Widget _voteBtn(String text, Color color, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 25, vertical: 15),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: color.withOpacity(0.5)),
        ),
        child: Text(text, style: TextStyle(color: color, fontWeight: FontWeight.bold)),
      ),
    );
  }

  Widget _buildVoteText(String? vote) {
    if (vote == 'deja_fait') return const Text("Déjà fait", style: TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.bold));
    if (vote == 'jamais') return const Text("Jamais", style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold));
    return const SizedBox();
  }

  Widget _buildPlayerList(List<dynamic> fbPlayers, String visibilityMode, bool gameEnded) {
    return ListView.builder(
      padding: const EdgeInsets.all(20),
      itemCount: widget.isOnline ? fbPlayers.length : widget.players.length,
      itemBuilder: (context, index) {
        String name;
        int score;
        String gender;
        bool hasVoted = false;
        String? lastVote;

        if (widget.isOnline) {
          name = fbPlayers[index]['name'];
          score = fbPlayers[index]['score'] ?? 0;
          gender = fbPlayers[index]['gender'] ?? 'H';
          hasVoted = fbPlayers[index]['hasVoted'] ?? false;
          lastVote = fbPlayers[index]['lastVote'];
        } else {
          name = widget.players[index].name;
          score = widget.players[index].score;
          gender = widget.players[index].gender;
        }

        bool isMe = widget.isOnline && name == widget.currentPlayerName;
        Widget trailingWidget;

        if (widget.isOnline) {
          String displayScore = score.toString();
          Widget actionWidget = const SizedBox();

          if (gameEnded) {
            // ✅ CORRECTION DU CLASSEMENT FINAL : JUSTE LE SCORE
            displayScore = score.toString();
            actionWidget = const SizedBox(); 
          } else if (visibilityMode == 'visible') {
            displayScore = score.toString();
            actionWidget = hasVoted ? _buildVoteText(lastVote) : const Icon(Icons.hourglass_empty, color: Colors.white24, size: 20);
          } else {
            displayScore = isMe ? score.toString() : "?";
            actionWidget = hasVoted ? const Icon(Icons.check_circle, color: Colors.greenAccent) : const Icon(Icons.radio_button_unchecked, color: Colors.white24);
          }

          trailingWidget = Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(displayScore, style: const TextStyle(color: Colors.amber, fontSize: 22, fontWeight: FontWeight.bold)),
              const SizedBox(width: 15),
              actionWidget,
            ],
          );

        } else {
          bool showScore = visibilityMode == 'visible' || gameEnded;
          trailingWidget = Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (!gameEnded) IconButton(icon: const Icon(Icons.remove, color: Colors.redAccent), onPressed: () => _updateScoreLocal(widget.players[index], -1)),
              Text(showScore ? "$score" : "?", style: const TextStyle(color: Colors.amber, fontSize: 22, fontWeight: FontWeight.bold)),
              if (!gameEnded) IconButton(icon: const Icon(Icons.add, color: Colors.greenAccent), onPressed: () => _updateScoreLocal(widget.players[index], 1)),
            ],
          );
        }

        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          decoration: BoxDecoration(color: Colors.white.withOpacity(0.05), borderRadius: BorderRadius.circular(15)),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: gender == 'H' ? Colors.blueAccent : Colors.pinkAccent,
              child: Text(name[0], style: const TextStyle(color: Colors.white)),
            ),
            title: Text(name + (isMe ? " (Moi)" : ""), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            trailing: trailingWidget,
          ),
        );
      },
    );
  }

  Widget _buildNextAndEndButtonsOnline() {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.purpleAccent, padding: const EdgeInsets.symmetric(vertical: 15), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))),
              onPressed: nextQuestionOnline,
              child: const Text("SUIVANTE ➔", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            flex: 1,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, padding: const EdgeInsets.symmetric(vertical: 15), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))),
              onPressed: () {
                FirebaseFirestore.instance.collection('lobbies').doc(widget.lobbyId).update({'jnjGameEnded': true});
              },
              child: const Text("FIN", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    ).animate().fadeIn().shimmer();
  }

  Widget _buildNextButtonLocal() {
    if (_localSecretMode && !_localGameEnded) {
      return Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            Expanded(
              flex: 2,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.purpleAccent, padding: const EdgeInsets.symmetric(vertical: 15), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))),
                onPressed: nextQuestion,
                child: const Text("SUIVANTE ➔", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              flex: 1,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, padding: const EdgeInsets.symmetric(vertical: 15), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))),
                onPressed: () => setState(() => _localGameEnded = true),
                child: const Text("FIN", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ).animate().fadeIn().shimmer();
    } else {
      return Padding(
        padding: const EdgeInsets.all(20),
        child: ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: _localGameEnded ? Colors.redAccent : Colors.purpleAccent, minimumSize: const Size(double.infinity, 50), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))),
          onPressed: _localGameEnded ? _quit : nextQuestion, 
          child: Text(_localGameEnded ? "QUITTER LA PARTIE" : "QUESTION SUIVANTE ➔", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        ),
      ).animate().fadeIn().shimmer();
    }
  }
}