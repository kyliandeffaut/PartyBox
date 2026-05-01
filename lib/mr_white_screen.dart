import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'main.dart';

class MrWhiteScreen extends StatefulWidget {
  final List<Player> players;
  final bool isOnline;
  final String? lobbyId;
  final String? currentPlayerName;
  final bool hasMrWhite;
  final bool hasUndercover;
  final int maxWords;

  const MrWhiteScreen({
    super.key,
    required this.players,
    this.isOnline = false,
    this.lobbyId,
    this.currentPlayerName,
    this.hasMrWhite = true,
    this.hasUndercover = false,
    this.maxWords = 3,
  });

  @override
  State<MrWhiteScreen> createState() => _MrWhiteScreenState();
}

class _MrWhiteScreenState extends State<MrWhiteScreen> {
  List<List<String>> _wordPairs = [];
  List<List<String>> _remainingWordPairs = [];

  String _phase = "distribution"; 
  bool _isLoading = true;
  bool _canPop = false;
  bool _isHost = false;

  // --- VARIABLES COMMUNES ---
  String _civilWord = ""; 
  String _eliminatedPlayer = "";
  String _eliminatedRole = "";
  String _gameResult = ""; 
  final TextEditingController _guessController = TextEditingController();
  final TextEditingController _wordEntryController = TextEditingController();
  bool _hasVotedThisTurn = false;

  // --- VARIABLES LOCALES (Pass & Play) ---
  Map<String, String> _localRoles = {}; 
  List<String> _localAlivePlayers = [];
  Map<String, List<String>> _localPlayerWords = {}; 
  int _localDistributionIndex = 0;
  int _localCurrentRound = 1;
  int _localTurnIndex = 0;
  bool _isRoleHidden = true; 
  Map<String, int> _localVotes = {};
  int _localVoteCount = 0;
  
  // --- VARIABLES MULTIJOUEUR ---
  int _onlineRound = 1;
  String _onlineTurnPlayer = "";
  String _onlineMyRole = "";
  List<String> _onlineAlivePlayers = [];
  Map<String, List<String>> _onlineWordsMap = {};
  bool _isSubmitting = false;
  
  int _onlineVoteCount = 0;
  int _onlineAliveCount = 0;

  @override
  void initState() {
    super.initState();
    _initGame();
  }

  Future<void> _loadWords() async {
    try {
      final String response = await rootBundle.loadString('assets/mr_white.json');
      final List<dynamic> data = json.decode(response);
      _wordPairs = data.map((pair) => List<String>.from(pair)).toList();
    } catch (e) {
      debugPrint("Erreur chargement mr_white.json: $e");
      _wordPairs = [
        ['Téléphone', 'Tablette'], ['Guitare', 'Banjo'], ['Pomme', 'Poire'], 
        ['Plage', 'Piscine'], ['Avion', 'Hélicoptère'], ['Cinéma', 'Théâtre'], 
        ['Livre', 'Magazine'], ['Chien', 'Loup'], ['Voiture', 'Moto'],
        ['Chocolat', 'Bonbon'], ['Cuisine', 'Salle de bain'], ['Facebook', 'Instagram']
      ];
    }
    _remainingWordPairs = List.from(_wordPairs)..shuffle();
  }

  Future<void> _initGame() async {
    await _loadWords(); 
    if (widget.isOnline && widget.lobbyId != null) {
      _listenLobby();
    } else {
      _startLocalGame();
    }
  }

  // ==========================================
  // LOGIQUE LOCALE (1 TÉLÉPHONE)
  // ==========================================
  void _startLocalGame() {
    setState(() {
      _phase = "distribution";
      _localRoles.clear();
      _localPlayerWords.clear();
      _localAlivePlayers = widget.players.map((p) => p.name).toList();
      for (var p in _localAlivePlayers) _localPlayerWords[p] = [];
      _localDistributionIndex = 0;
      _localCurrentRound = 1;
      _localTurnIndex = 0;
      _isRoleHidden = true;
      _gameResult = "";
      _eliminatedRole = "";
      _guessController.clear();
      _localVotes.clear();
      _localVoteCount = 0;
      _hasVotedThisTurn = false;
    });

    if (_remainingWordPairs.isEmpty) _remainingWordPairs = List.from(_wordPairs)..shuffle();

    List<String> pair = List.from(_remainingWordPairs.removeLast());
    pair.shuffle(); 
    _civilWord = pair[0];
    String undercoverWord = pair[1];

    List<String> shuffledNames = List.from(_localAlivePlayers)..shuffle();
    String? mrWhiteName;
    String? undercoverName;
    int roleIndex = 0;

    if (widget.hasMrWhite) {
      mrWhiteName = shuffledNames[roleIndex];
      roleIndex++;
    }
    if (widget.hasUndercover && roleIndex < shuffledNames.length) undercoverName = shuffledNames[roleIndex];

    for (String name in _localAlivePlayers) {
      if (name == mrWhiteName) _localRoles[name] = "Mr White";
      else if (name == undercoverName) _localRoles[name] = undercoverWord;
      else _localRoles[name] = _civilWord;
    }
    setState(() => _isLoading = false);
  }

  void _nextLocalDistribution() {
    setState(() {
      _isRoleHidden = true;
      _localDistributionIndex++;
      if (_localDistributionIndex >= _localAlivePlayers.length) _phase = "word_entry";
    });
  }

  void _submitLocalWord() {
    String word = _wordEntryController.text.trim();
    if (word.isEmpty) return;
    setState(() {
      _localPlayerWords[_localAlivePlayers[_localTurnIndex]]!.add(word); 
      _wordEntryController.clear();
      _localTurnIndex++;
      if (_localTurnIndex >= _localAlivePlayers.length) {
        _localTurnIndex = 0;
        _localCurrentRound++;
      }
      if (_localCurrentRound > widget.maxWords) _phase = "vote";
    });
  }

  void _handleLocalVote(String targetName) {
    if (_localVoteCount >= _localAlivePlayers.length) return; 
    setState(() {
      _localVotes[targetName] = (_localVotes[targetName] ?? 0) + 1;
      _localVoteCount++;
      if (_localVoteCount >= _localAlivePlayers.length) {
        _hasVotedThisTurn = true;
        _calculateLocalResult();
      }
    });
  }

  void _calculateLocalResult() {
    String eliminated = "";
    int maxVotes = -1;
    _localVotes.forEach((key, value) {
      if (value > maxVotes) { maxVotes = value; eliminated = key; }
    });

    setState(() {
      _eliminatedPlayer = eliminated;
      _eliminatedRole = _localRoles[eliminated] ?? "";
      _localAlivePlayers.remove(eliminated);

      if (_eliminatedRole == "Mr White") _phase = "mr_white_guess";
      else _checkLocalWinConditions();
    });
  }

  void _checkLocalWinConditions() {
    bool mwAlive = _localAlivePlayers.any((p) => _localRoles[p] == "Mr White");
    bool ucAlive = _localAlivePlayers.any((p) => _localRoles[p] != _civilWord && _localRoles[p] != "Mr White");

    setState(() {
      _phase = "resultat";
      if (!mwAlive && !ucAlive) _gameResult = "VICTOIRE DES CIVILS !";
      else if (_localAlivePlayers.length <= 2) _gameResult = "VICTOIRE DES IMPOSTEURS !"; 
      else _gameResult = "CONTINUE"; 
    });
  }

  void _checkLocalMrWhiteGuess() {
    String guess = _guessController.text.trim().toLowerCase();
    if (guess == _civilWord.toLowerCase()) {
      setState(() { _phase = "resultat"; _gameResult = "MR WHITE A DEVINÉ LE MOT !\nIL VOLE LA VICTOIRE !"; });
    } else {
      _checkLocalWinConditions(); 
    }
  }

  void _nextRoundLocal() {
    setState(() {
      _phase = "word_entry"; 
      _localCurrentRound = 1;
      _localTurnIndex = 0;
      _localVotes.clear();
      _localVoteCount = 0;
      _hasVotedThisTurn = false;
      _eliminatedPlayer = "";
      for (var p in _localAlivePlayers) _localPlayerWords[p] = []; 
    });
  }

  // ==========================================
  // LOGIQUE MULTIJOUEUR EN LIGNE
  // ==========================================
  void _listenLobby() {
    FirebaseFirestore.instance.collection('lobbies').doc(widget.lobbyId).snapshots().listen((snap) {
      if (!snap.exists || snap.data() == null) return;
      final data = snap.data()!;
      final bool amIHost = (data['host'] ?? '').toString() == (widget.currentPlayerName ?? '');
      String fbPhase = data['mwPhase'] ?? 'distribution';

      if (!mounted) return;
      setState(() {
        _isHost = amIHost;
        _phase = fbPhase;
        _onlineRound = data['mwRound'] ?? 1;
        _civilWord = data['mwCivilWord'] ?? "";
        _eliminatedPlayer = data['mwEliminated'] ?? "";
        _eliminatedRole = data['mwEliminatedRole'] ?? "";
        _gameResult = data['mwGameResult'] ?? "";
        
        if (_phase != 'vote') _hasVotedThisTurn = false; 

        int turnIdx = data['mwTurnIndex'] ?? 0;
        List activeP = data['activePlayers'] ?? [];
        List<String> aliveNames = [];
        
        int vCount = 0;
        int aCount = 0;
        
        _onlineWordsMap.clear();

        for (var p in activeP) {
           if (p['isAlive'] == true) {
               aliveNames.add(p['name']);
               aCount++;
               if (p['hasVoted'] == true) vCount++;
           }
           _onlineWordsMap[p['name']] = List<String>.from(p['mwWords'] ?? []);
           if (p['name'] == widget.currentPlayerName) {
              _onlineMyRole = p['mwRole'] ?? "Erreur";
              if (_phase == 'vote') _hasVotedThisTurn = p['hasVoted'] ?? false;
           }
        }
        
        _onlineAlivePlayers = aliveNames;
        _onlineVoteCount = vCount;
        _onlineAliveCount = aCount;
        
        if (aliveNames.isNotEmpty && turnIdx < aliveNames.length) {
            _onlineTurnPlayer = aliveNames[turnIdx];
        } else {
            _onlineTurnPlayer = "";
        }
        
        _isLoading = false;
      });

      // --- INITIALISATION DU JEU (Seul le chef le fait) ---
      if (amIHost && data['mwPhase'] == null) {
        _startOnlineGame(data);
      }
      
      // FINI : ON NE FAIT PLUS DE CALCUL DE VOTE ICI ! LA TRANSACTION S'EN OCCUPE EN BAS.
    });
  }

  Future<void> _startOnlineGame(Map<String, dynamic> currentData) async {
    if (_remainingWordPairs.isEmpty) {
        if (_wordPairs.isEmpty) _wordPairs = [['Erreur', 'Bug']];
        _remainingWordPairs = List.from(_wordPairs)..shuffle();
    }
    
    List<String> pair = List.from(_remainingWordPairs.removeLast());
    pair.shuffle(); 
    String civilWord = pair[0];
    String undercoverWord = pair[1];

    List activeP = (currentData['activePlayers'] as List? ?? []).map((p) => Map<String, dynamic>.from(p as Map)).toList();
    if (activeP.isEmpty) return;

    List<String> names = activeP.map((p) => p['name'].toString()).toList();
    names.shuffle();
    
    String? mrWhiteName;
    String? undercoverName;
    int roleIndex = 0;

    if (widget.hasMrWhite) { mrWhiteName = names[roleIndex]; roleIndex++; }
    if (widget.hasUndercover && roleIndex < names.length) undercoverName = names[roleIndex];

    for (var p in activeP) {
      if (p['name'] == mrWhiteName) p['mwRole'] = "Mr White";
      else if (p['name'] == undercoverName) p['mwRole'] = undercoverWord;
      else p['mwRole'] = civilWord;
      
      p['isAlive'] = true;
      p['hasVoted'] = false;
      p['voteTarget'] = null;
      p['mwWords'] = []; 
    }

    await FirebaseFirestore.instance.collection('lobbies').doc(widget.lobbyId).update({
      'mwPhase': 'distribution', 'mwRound': 1, 'mwTurnIndex': 0, 'activePlayers': activeP, 'mwCivilWord': civilWord, 
    });
  }

  Future<void> _submitOnlineWord() async {
    String word = _wordEntryController.text.trim();
    if (word.isEmpty || _isSubmitting) return;
    setState(() => _isSubmitting = true);

    try {
      var docRef = FirebaseFirestore.instance.collection('lobbies').doc(widget.lobbyId);
      var doc = await docRef.get();
      var data = doc.data()!;
      
      List activeP = (data['activePlayers'] as List? ?? []).map((p) => Map<String, dynamic>.from(p as Map)).toList();
      List aliveNames = activeP.where((p) => p['isAlive'] == true).map((p) => p['name']).toList();

      for (var p in activeP) {
        if (p['name'] == widget.currentPlayerName) p['mwWords'] = List.from(p['mwWords'] ?? [])..add(word);
      }

      int turn = data['mwTurnIndex'] ?? 0;
      int round = data['mwRound'] ?? 1;

      turn++;
      if (turn >= aliveNames.length) { turn = 0; round++; }

      Map<String, dynamic> updates = {'activePlayers': activeP, 'mwTurnIndex': turn, 'mwRound': round};
      if (round > widget.maxWords) updates['mwPhase'] = 'vote';

      await docRef.update(updates);
      _wordEntryController.clear();
    } catch (e) {
      debugPrint("Erreur soumission mot: $e");
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  // 🛠️ TRANSACTION PROPRE ET UNIQUE POUR LE VOTE
  Future<void> _handleOnlineVote(String targetName) async {
    if (_hasVotedThisTurn) return;

    var docRef = FirebaseFirestore.instance.collection('lobbies').doc(widget.lobbyId);
    
    try {
      await FirebaseFirestore.instance.runTransaction((transaction) async {
        var snapshot = await transaction.get(docRef);
        if (!snapshot.exists) return;
        var data = snapshot.data()!;
        
        List activeP = (data['activePlayers'] as List? ?? []).map((p) => Map<String, dynamic>.from(p as Map)).toList();
        
        // 1. On enregistre le vote
        for (var p in activeP) {
          if (p['name'] == widget.currentPlayerName) {
            p['hasVoted'] = true;
            p['voteTarget'] = targetName;
          }
        }
        
        // 2. Vérification immédiate du nombre de votants
        var aliveP = activeP.where((p) => p['isAlive'] == true).toList();
        bool everyoneVoted = aliveP.isNotEmpty && aliveP.every((p) => p['hasVoted'] == true);

        if (everyoneVoted) {
          // Si tout le monde a voté, on fait les comptes et on passe à la suite direct !
          Map<String, int> votes = {};
          for (var p in aliveP) {
            String t = p['voteTarget'] ?? '';
            if (t.isNotEmpty) votes[t] = (votes[t] ?? 0) + 1;
          }

          String eliminated = "";
          int maxV = -1;
          votes.forEach((k, v) { if (v > maxV) { maxV = v; eliminated = k; } });

          var elimPlayer = activeP.firstWhere((p) => p['name'] == eliminated, orElse: () => {});
          String elimRole = elimPlayer['mwRole'] ?? '';

          for (var p in activeP) if (p['name'] == eliminated) p['isAlive'] = false;

          int aliveCount = activeP.where((p) => p['isAlive'] == true).length;
          bool mwAlive = activeP.any((p) => p['isAlive'] == true && p['mwRole'] == 'Mr White');
          bool ucAlive = activeP.any((p) => p['isAlive'] == true && p['mwRole'] != 'Mr White' && p['mwRole'] != data['mwCivilWord']);

          String nextPhase = 'resultat';
          String gameRes = "CONTINUE";

          if (elimRole == 'Mr White') nextPhase = 'mr_white_guess';
          else {
            if (!mwAlive && !ucAlive) gameRes = "VICTOIRE DES CIVILS !";
            else if (aliveCount <= 2) gameRes = "VICTOIRE DES IMPOSTEURS !";
          }

          transaction.update(docRef, {
            'activePlayers': activeP,
            'mwPhase': nextPhase,
            'mwEliminated': eliminated,
            'mwEliminatedRole': elimRole,
            'mwGameResult': gameRes,
          });
        } else {
          // Sinon, on met juste à jour la liste avec le nouveau vote
          transaction.update(docRef, {'activePlayers': activeP});
        }
      });
      
      if (mounted) setState(() => _hasVotedThisTurn = true);
    } catch (e) {
      debugPrint("Erreur lors du vote en ligne : $e");
    }
  }

  // Bouton de secours au cas où un joueur quitte la partie brusquement
  Future<void> _forceEndVoteOnline() async {
    var docRef = FirebaseFirestore.instance.collection('lobbies').doc(widget.lobbyId);
    var doc = await docRef.get();
    if (!doc.exists) return;
    var data = doc.data()!;

    List activeP = (data['activePlayers'] as List? ?? []).map((p) => Map<String, dynamic>.from(p as Map)).toList();
    var aliveP = activeP.where((p) => p['isAlive'] == true).toList();

    Map<String, int> votes = {};
    for (var p in aliveP) {
      String t = p['voteTarget'] ?? '';
      if (t.isNotEmpty) votes[t] = (votes[t] ?? 0) + 1;
    }

    if (votes.isEmpty) return;

    String eliminated = "";
    int maxV = -1;
    votes.forEach((k, v) { if (v > maxV) { maxV = v; eliminated = k; } });

    var elimPlayer = activeP.firstWhere((p) => p['name'] == eliminated, orElse: () => {});
    String elimRole = elimPlayer['mwRole'] ?? '';

    for (var p in activeP) if (p['name'] == eliminated) p['isAlive'] = false;

    int aliveCount = activeP.where((p) => p['isAlive'] == true).length;
    bool mwAlive = activeP.any((p) => p['isAlive'] == true && p['mwRole'] == 'Mr White');
    bool ucAlive = activeP.any((p) => p['isAlive'] == true && p['mwRole'] != 'Mr White' && p['mwRole'] != data['mwCivilWord']);

    String nextPhase = 'resultat';
    String gameRes = "CONTINUE";

    if (elimRole == 'Mr White') nextPhase = 'mr_white_guess';
    else {
      if (!mwAlive && !ucAlive) gameRes = "VICTOIRE DES CIVILS !";
      else if (aliveCount <= 2) gameRes = "VICTOIRE DES IMPOSTEURS !";
    }

    await docRef.update({
      'mwPhase': nextPhase, 'mwEliminated': eliminated, 'mwEliminatedRole': elimRole, 'mwGameResult': gameRes, 'activePlayers': activeP,
    });
  }

  Future<void> _checkOnlineMrWhiteGuess() async {
    String guess = _guessController.text.trim().toLowerCase();
    var docRef = FirebaseFirestore.instance.collection('lobbies').doc(widget.lobbyId);
    var doc = await docRef.get();
    var data = doc.data()!;
    String actualWord = (data['mwCivilWord'] ?? '').toLowerCase();

    String res = "";
    if (guess == actualWord) {
      res = "MR WHITE A DEVINÉ LE MOT !\nIL VOLE LA VICTOIRE !";
    } else {
      List activeP = data['activePlayers'] ?? [];
      int aliveCount = activeP.where((p) => p['isAlive'] == true).length;
      bool ucAlive = activeP.any((p) => p['isAlive'] == true && p['mwRole'] != 'Mr White' && p['mwRole'] != data['mwCivilWord']);
      if (!ucAlive) res = "MAUVAISE RÉPONSE !\nVICTOIRE DES CIVILS !";
      else if (aliveCount <= 2) res = "VICTOIRE DES IMPOSTEURS !";
      else res = "CONTINUE";
    }
    await docRef.update({'mwPhase': 'resultat', 'mwGameResult': res});
  }

  Future<void> _nextRoundOnline() async {
    var docRef = FirebaseFirestore.instance.collection('lobbies').doc(widget.lobbyId);
    var doc = await docRef.get();
    
    List activeP = (doc.data()?['activePlayers'] as List? ?? []).map((p) => Map<String, dynamic>.from(p as Map)).toList();
    for (var p in activeP) {
       p['hasVoted'] = false;
       p['voteTarget'] = null;
       p['mwWords'] = [];
    }
    await docRef.update({
       'mwPhase': 'word_entry', 'mwRound': 1, 'mwTurnIndex': 0, 'activePlayers': activeP,
       'mwEliminated': FieldValue.delete(), 'mwEliminatedRole': FieldValue.delete(), 'mwGameResult': FieldValue.delete(),
    });
  }

  Future<void> _replayOnline() async {
    await FirebaseFirestore.instance.collection('lobbies').doc(widget.lobbyId).update({
       'mwPhase': FieldValue.delete(), 'mwEliminated': FieldValue.delete(), 'mwEliminatedRole': FieldValue.delete(), 'mwGameResult': FieldValue.delete(),
    });
  }

  Future<void> _quit() async {
    if (widget.isOnline && widget.lobbyId != null) {
      try {
        var docRef = FirebaseFirestore.instance.collection('lobbies').doc(widget.lobbyId);
        var doc = await docRef.get();
        if (doc.exists) {
          List activeP = (doc.data()?['activePlayers'] as List? ?? []).map((p) => Map<String, dynamic>.from(p as Map)).toList();
          activeP.removeWhere((p) => p['name'] == widget.currentPlayerName);
          await docRef.update({'activePlayers': activeP});
        }
      } catch (e) {
        debugPrint("Erreur déconnexion: $e");
      }
    }
    if (mounted) {
      setState(() => _canPop = true);
      Navigator.pop(context);
    }
  }

  // ==========================================
  // INTERFACES (UI)
  // ==========================================
  Widget _glassCard({required Widget child, Color? borderColor}) {
    return Container(
      width: double.infinity, margin: const EdgeInsets.symmetric(horizontal: 20), padding: const EdgeInsets.all(25),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [Colors.white.withValues(alpha: 0.10), Colors.white.withValues(alpha: 0.03)]),
        borderRadius: BorderRadius.circular(25), border: Border.all(color: borderColor ?? Colors.white10, width: 1.5),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.2), blurRadius: 15, offset: const Offset(0, 5))],
      ),
      child: child,
    );
  }

  Widget _buildWordsList(List<String> alivePlayers, Map<String, List<String>> wordsMap) {
    return ListView.builder(
      shrinkWrap: true, physics: const NeverScrollableScrollPhysics(), itemCount: alivePlayers.length,
      itemBuilder: (context, i) {
        String pName = alivePlayers[i];
        List<String> words = wordsMap[pName] ?? [];
        return Container(
          margin: const EdgeInsets.only(bottom: 10), padding: const EdgeInsets.all(15),
          decoration: BoxDecoration(color: Colors.white.withOpacity(0.05), borderRadius: BorderRadius.circular(15), border: Border.all(color: Colors.white10)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(pName.toUpperCase(), style: const TextStyle(color: Colors.amber, fontWeight: FontWeight.bold, fontSize: 14, letterSpacing: 1)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8, runSpacing: 8,
                children: words.isEmpty 
                  ? [const Text("...", style: TextStyle(color: Colors.white38, fontStyle: FontStyle.italic))]
                  : words.map((w) => Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8), decoration: BoxDecoration(color: Colors.white.withOpacity(0.15), borderRadius: BorderRadius.circular(20)),
                      child: Text(w, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                    )).toList(),
              )
            ],
          ),
        ).animate().fadeIn(delay: (i * 100).ms);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _canPop,
      onPopInvokedWithResult: (didPop, result) async { if (didPop) return; _quit(); },
      child: Scaffold(
        extendBodyBehindAppBar: true,
        appBar: AppBar(
          backgroundColor: Colors.transparent, elevation: 0, centerTitle: true,
          leading: Listener(onPointerDown: (_) => playPop(), child: IconButton(icon: const Icon(Icons.close, color: Colors.white, size: 30), onPressed: _quit)),
          title: const Text("LE MOT SECRET", style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, letterSpacing: 3)),
        ),
        body: Container(
          width: double.infinity, height: double.infinity,
          decoration: BoxDecoration(
            color: const Color(0xFF101012),
            image: DecorationImage(image: const AssetImage('assets/images/background.jpg'), fit: BoxFit.cover, colorFilter: ColorFilter.mode(Colors.black.withValues(alpha: 0.8), BlendMode.darken)),
          ),
          child: SafeArea(
            child: _isLoading ? const Center(child: CircularProgressIndicator(color: Colors.white)) : _buildCurrentPhase(),
          ),
        ),
      ),
    );
  }

  Widget _buildCurrentPhase() {
    if (_phase == "distribution") return _buildDistributionPhase();
    if (_phase == "word_entry") return _buildWordEntryPhase();
    if (_phase == "vote") return _buildVotePhase();
    if (_phase == "mr_white_guess") return _buildMrWhiteGuessPhase();
    if (_phase == "resultat") return _buildResultPhase();
    return const SizedBox();
  }

  // --- 1. PHASE DE DISTRIBUTION ---
  Widget _buildDistributionPhase() {
    if (widget.isOnline) {
      return Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text("MÉMORISE TON RÔLE", style: TextStyle(color: Colors.white54, fontWeight: FontWeight.bold, letterSpacing: 2)),
          const SizedBox(height: 20),
          _glassCard(
            borderColor: _onlineMyRole == "Mr White" ? Colors.redAccent : Colors.blueAccent,
            child: Column(
              children: [
                Text(_onlineMyRole == "Mr White" ? "TU ES" : "TON MOT EST", style: const TextStyle(color: Colors.white54, fontWeight: FontWeight.bold)),
                const SizedBox(height: 10),
                Text(_onlineMyRole, textAlign: TextAlign.center, style: TextStyle(color: _onlineMyRole == "Mr White" ? Colors.redAccent : Colors.blueAccent, fontSize: 32, fontWeight: FontWeight.w900)),
              ],
            ),
          ).animate().scale(curve: Curves.easeOutBack),
          const SizedBox(height: 40),
          if (_isHost)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40),
              child: Listener(
                onPointerDown: (_) => playPop(),
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.white, minimumSize: const Size(double.infinity, 60), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20))),
                  onPressed: () => FirebaseFirestore.instance.collection('lobbies').doc(widget.lobbyId).update({'mwPhase': 'word_entry'}),
                  child: const Text("TOUT LE MONDE EST PRÊT", style: TextStyle(color: Colors.black, fontWeight: FontWeight.w900)),
                ),
              ),
            )
          else
            const Text("En attente du chef pour commencer...", style: TextStyle(color: Colors.white54, fontStyle: FontStyle.italic))
        ],
      );
    }

    int safeDistIndex = _localDistributionIndex < _localAlivePlayers.length ? _localDistributionIndex : 0;
    String currentPlayer = _localAlivePlayers[safeDistIndex];
    String role = _localRoles[currentPlayer] ?? "Erreur";

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(Icons.visibility_off, color: Colors.white54, size: 40),
        const SizedBox(height: 20),
        Text("AU TOUR DE", style: TextStyle(color: Colors.amber.shade200, fontWeight: FontWeight.w900, letterSpacing: 2)),
        Text(currentPlayer.toUpperCase(), style: const TextStyle(color: Colors.white, fontSize: 35, fontWeight: FontWeight.w900)),
        const SizedBox(height: 40),

        if (_isRoleHidden) ...[
          _glassCard(child: const Text("Passez le téléphone à ce joueur.\nLui seul doit regarder l'écran !", textAlign: TextAlign.center, style: TextStyle(color: Colors.white70, fontSize: 16))),
          const SizedBox(height: 40),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: Listener(
              onPointerDown: (_) => playSwoosh(),
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.amber.shade600, minimumSize: const Size(double.infinity, 60), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20))),
                onPressed: () => setState(() => _isRoleHidden = false),
                child: const Text("VOIR MON RÔLE", style: TextStyle(color: Colors.black, fontWeight: FontWeight.w900, fontSize: 18)),
              ),
            ),
          )
        ] else ...[
          _glassCard(
            borderColor: role == "Mr White" ? Colors.redAccent : Colors.blueAccent,
            child: Column(
              children: [
                Text(role == "Mr White" ? "TU ES" : "TON MOT EST", style: const TextStyle(color: Colors.white54, fontWeight: FontWeight.bold, letterSpacing: 2)),
                const SizedBox(height: 10),
                Text(role, textAlign: TextAlign.center, style: TextStyle(color: role == "Mr White" ? Colors.redAccent : Colors.blueAccent, fontSize: 32, fontWeight: FontWeight.w900)),
              ],
            ),
          ).animate().scale(curve: Curves.easeOutBack),
          const SizedBox(height: 40),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: Listener(
              onPointerDown: (_) => playPop(),
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.white, minimumSize: const Size(double.infinity, 60), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20))),
                onPressed: _nextLocalDistribution,
                child: const Text("J'AI MÉMORISÉ ! CACHER", style: TextStyle(color: Colors.black, fontWeight: FontWeight.w900, fontSize: 18)),
              ),
            ),
          )
        ]
      ],
    ).animate().fadeIn();
  }

  // --- 2. PHASE DE SAISIE ---
  Widget _buildWordEntryPhase() {
    bool isOnlineMyTurn = widget.isOnline && _onlineTurnPlayer == widget.currentPlayerName;
    int safeTurnIndex = _localTurnIndex < _localAlivePlayers.length ? _localTurnIndex : 0;
    String currentPlayer = widget.isOnline ? _onlineTurnPlayer : _localAlivePlayers[safeTurnIndex];
    int round = widget.isOnline ? _onlineRound : _localCurrentRound;

    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                Text("TOUR $round / ${widget.maxWords}", style: const TextStyle(color: Colors.white54, fontWeight: FontWeight.w900, letterSpacing: 2)),
                const SizedBox(height: 20),

                if (!widget.isOnline || isOnlineMyTurn) ...[
                  _glassCard(
                    borderColor: Colors.amber,
                    child: Column(
                      children: [
                        const Text("À TON TOUR", style: TextStyle(color: Colors.amber, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 5),
                        Text(currentPlayer.toUpperCase(), style: const TextStyle(color: Colors.white, fontSize: 30, fontWeight: FontWeight.w900)),
                        const SizedBox(height: 20),
                        TextField(
                          controller: _wordEntryController, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
                          decoration: InputDecoration(hintText: "Tape un mot...", hintStyle: const TextStyle(color: Colors.white38), filled: true, fillColor: Colors.black45, border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none)),
                        ),
                        const SizedBox(height: 15),
                        Listener(
                          onPointerDown: (_) => playSwoosh(),
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(backgroundColor: Colors.amber.shade600, minimumSize: const Size(double.infinity, 50), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))),
                            onPressed: widget.isOnline ? (_isSubmitting ? null : _submitOnlineWord) : _submitLocalWord,
                            child: const Text("VALIDER ET PASSER", style: TextStyle(color: Colors.black, fontWeight: FontWeight.w900)),
                          ),
                        )
                      ],
                    ),
                  ).animate().scale(curve: Curves.easeOutBack),
                ] else ...[
                  _glassCard(child: Text("Au tour de ${_onlineTurnPlayer.toUpperCase()}...", textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontSize: 18, fontStyle: FontStyle.italic))),
                ],

                const SizedBox(height: 30),
                _buildWordsList(widget.isOnline ? _onlineAlivePlayers : _localAlivePlayers, widget.isOnline ? _onlineWordsMap : _localPlayerWords),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // --- 3. PHASE DE VOTE ---
  Widget _buildVotePhase() {
    List<String> aliveP = widget.isOnline ? _onlineAlivePlayers : _localAlivePlayers;
    bool hasVoted = widget.isOnline ? _hasVotedThisTurn : false;

    return Column(
      children: [
        const SizedBox(height: 10),
        const Text("VOTE", style: TextStyle(color: Colors.redAccent, fontSize: 25, fontWeight: FontWeight.w900, letterSpacing: 4)),
        
        if (widget.isOnline)
          Text("Votes reçus : $_onlineVoteCount / $_onlineAliveCount", style: const TextStyle(color: Colors.amber, fontWeight: FontWeight.bold, fontSize: 16)),
          
        const SizedBox(height: 5),
        const Text("Observez les mots. Qui est l'imposteur ?", style: TextStyle(color: Colors.white70)),
        const SizedBox(height: 10),

        if (!widget.isOnline)
          Builder(
            builder: (context) {
              int safeVoteIndex = _localVoteCount < _localAlivePlayers.length ? _localVoteCount : 0;
              return Text("Au tour de ${_localAlivePlayers[safeVoteIndex].toUpperCase()} de voter", style: const TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold));
            }
          )
        else if (hasVoted)
          const Text("Tu as voté. En attente des autres...", style: TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.bold, fontStyle: FontStyle.italic)),

        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            child: Column(
              children: [
                _buildWordsList(aliveP, widget.isOnline ? _onlineWordsMap : _localPlayerWords),
                const SizedBox(height: 20),
                const Divider(color: Colors.white24),
                const SizedBox(height: 10),
                
                ...aliveP.map((target) => Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.05), borderRadius: BorderRadius.circular(15), border: Border.all(color: Colors.white10)),
                  child: Listener(
                    onPointerDown: (_) => playHammer(),
                    child: ListTile(
                      title: Text(target, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
                      trailing: const Icon(Icons.how_to_vote, color: Colors.redAccent),
                      onTap: () => widget.isOnline ? _handleOnlineVote(target) : _handleLocalVote(target),
                    ),
                  ),
                )).toList(),

                // LE BOUTON MAGIQUE POUR TOUT LE MONDE
                if (widget.isOnline) ...[
                  const SizedBox(height: 30),
                  TextButton.icon(
                    onPressed: _forceEndVoteOnline,
                    icon: const Icon(Icons.warning_amber_rounded, color: Colors.orangeAccent),
                    label: const Text("Forcer les résultats (si qqn a buggé)", style: TextStyle(color: Colors.orangeAccent, fontWeight: FontWeight.bold)),
                  )
                ]
              ],
            ),
          ),
        )
      ],
    ).animate().fadeIn();
  }

  // --- 4. DERNIÈRE CHANCE ---
  Widget _buildMrWhiteGuessPhase() {
    bool amIEliminatedWhite = widget.isOnline && widget.currentPlayerName == _eliminatedPlayer;

    return SingleChildScrollView(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(height: 40),
          const Text("DÉMASQUÉ !", style: TextStyle(color: Colors.redAccent, fontSize: 35, fontWeight: FontWeight.w900, letterSpacing: 2)),
          const SizedBox(height: 10),
          Text("$_eliminatedPlayer était Mr White 🕶️", style: const TextStyle(color: Colors.white70, fontSize: 18)),
          const SizedBox(height: 30),
          
          if (!widget.isOnline || amIEliminatedWhite) ...[
            _glassCard(
              borderColor: Colors.amber,
              child: Column(
                children: [
                  const Text("DERNIÈRE CHANCE", style: TextStyle(color: Colors.amber, fontWeight: FontWeight.bold, letterSpacing: 2)),
                  const SizedBox(height: 15),
                  const Text("Si tu devines le mot des Civils,\ntu voles la victoire !", textAlign: TextAlign.center, style: TextStyle(color: Colors.white, fontSize: 16)),
                  const SizedBox(height: 20),
                  TextField(
                    controller: _guessController, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                    decoration: InputDecoration(hintText: "Tape le mot ici...", hintStyle: const TextStyle(color: Colors.white38), filled: true, fillColor: Colors.black45, border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none)),
                  ),
                ],
              ),
            ).animate().scale(curve: Curves.easeOutBack),
            const SizedBox(height: 40),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40),
              child: Listener(
                onPointerDown: (_) => playHammer(),
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.amber.shade600, minimumSize: const Size(double.infinity, 60), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20))),
                  onPressed: widget.isOnline ? _checkOnlineMrWhiteGuess : _checkLocalMrWhiteGuess,
                  child: const Text("TENTER MA CHANCE", style: TextStyle(color: Colors.black, fontWeight: FontWeight.w900, fontSize: 18)),
                ),
              ),
            )
          ] else ...[
             _glassCard(child: Text("Mr White ( $_eliminatedPlayer ) réfléchit et tente de deviner votre mot...", textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontSize: 18, fontStyle: FontStyle.italic))),
          ]
        ],
      ), 
    ).animate().fadeIn(); 
  }

  // --- 5. RÉSULTATS ---
  Widget _buildResultPhase() {
    bool isMrWhite = _eliminatedRole == "Mr White";
    bool isUndercover = _eliminatedRole != "Mr White" && _eliminatedRole != _civilWord;
    
    String roleText = "CIVIL 🧍";
    Color roleColor = Colors.blueAccent;
    if (isMrWhite) { roleText = "MR WHITE 🕶️"; roleColor = Colors.redAccent; } 
    else if (isUndercover) { roleText = "INFILTRÉ 🕵️‍♂️\n(Son mot : $_eliminatedRole)"; roleColor = Colors.purpleAccent; }

    return SingleChildScrollView(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(height: 40),
          Text(_eliminatedPlayer.toUpperCase(), style: const TextStyle(color: Colors.white, fontSize: 35, fontWeight: FontWeight.w900)),
          const Text("A ÉTÉ ÉLIMINÉ !", style: TextStyle(color: Colors.white54, fontSize: 18, letterSpacing: 2)),
          const SizedBox(height: 30),
          
          _glassCard(
            borderColor: roleColor,
            child: Column(
              children: [
                Text("SON RÔLE ÉTAIT :", style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontWeight: FontWeight.bold)),
                const SizedBox(height: 10),
                Text(roleText, textAlign: TextAlign.center, style: TextStyle(color: roleColor, fontSize: 24, fontWeight: FontWeight.w900)),
              ],
            ),
          ).animate().scale(curve: Curves.easeOutBack),
          const SizedBox(height: 40),
          
          if (_gameResult == "CONTINUE") ...[
            const Text("ATTENTION : UN IMPOSTEUR EST TOUJOURS LÀ...", textAlign: TextAlign.center, style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
            const SizedBox(height: 20),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40),
              child: Listener(
                onPointerDown: (_) => playPop(),
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.white, minimumSize: const Size(double.infinity, 60), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20))),
                  onPressed: widget.isOnline ? (_isHost ? _nextRoundOnline : null) : _nextRoundLocal,
                  child: Text(widget.isOnline && !_isHost ? "ATTENTE DU CHEF..." : "TOUR SUIVANT", style: const TextStyle(color: Colors.black, fontWeight: FontWeight.w900)),
                ),
              ),
            )
          ] else ...[
            Text(_gameResult, textAlign: TextAlign.center, style: const TextStyle(color: Colors.amber, fontSize: 22, fontWeight: FontWeight.w900, letterSpacing: 2)),
            const SizedBox(height: 10),
            Text("Le mot des civils était : $_civilWord", style: const TextStyle(color: Colors.white70, fontSize: 16, fontStyle: FontStyle.italic)),
            const SizedBox(height: 40),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40),
              child: Listener(
                onPointerDown: (_) => playPop(),
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.amber.shade600, minimumSize: const Size(double.infinity, 60), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20))),
                  onPressed: widget.isOnline ? (_isHost ? _replayOnline : null) : _startLocalGame,
                  child: Text(widget.isOnline && !_isHost ? "ATTENTE DU CHEF..." : "REJOUER", style: const TextStyle(color: Colors.black, fontWeight: FontWeight.w900)),
                ),
              ),
            ),
            const SizedBox(height: 15),
            TextButton(onPressed: _quit, child: const Text("Retour au menu", style: TextStyle(color: Colors.white54))),
            const SizedBox(height: 40),
          ]
        ],
      ), 
    ).animate().fadeIn(); 
  }
}