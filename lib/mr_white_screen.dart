import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter/services.dart';
import 'dart:convert';
import 'main.dart';

class MrWhiteScreen extends StatefulWidget {
  final List<Player> players;
  final bool isOnline;
  final String? lobbyId;
  final String? currentPlayerName;

  const MrWhiteScreen({
    super.key,
    required this.players,
    this.isOnline = false,
    this.lobbyId,
    this.currentPlayerName,
  });

  @override
  State<MrWhiteScreen> createState() => _MrWhiteScreenState();
}

class _MrWhiteScreenState extends State<MrWhiteScreen> {
  // --- LISTES VIDES QUI SERONT REMPLIES PAR LE JSON ---
  List<List<String>> _wordPairs = [];
  List<List<String>> _remainingWordPairs = [];

  // --- ÉTATS DU JEU ---
  String _phase = "distribution"; 
  bool _isLoading = true;
  // ignore: unused_field
  bool _isHost = false;
  bool _canPop = false;

  // --- VARIABLES LOCALES (Pass & Play) ---
  Map<String, String> _localRoles = {}; 
  List<String> _localAlivePlayers = [];
  int _localDistributionIndex = 0;
  bool _isRoleHidden = true; 
  Map<String, int> _localVotes = {};
  int _localVoteCount = 0;
  // ignore: unused_field
  bool _hasVotedThisTurn = false;
  
  String _eliminatedPlayer = "";
  String _gameResult = ""; 
  String _civilWord = ""; 
  final TextEditingController _guessController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _initGame();
  }

  // --- LECTURE DU FICHIER JSON ---
  Future<void> _loadWords() async {
    try {
      final String response = await rootBundle.loadString('assets/mr_white.json');
      final List<dynamic> data = json.decode(response);
      
      _wordPairs = data.map((pair) => List<String>.from(pair)).toList();
      _remainingWordPairs = List.from(_wordPairs)..shuffle(); // On prépare la pioche
    } catch (e) {
      debugPrint("Erreur chargement mr_white.json: $e");
    }
  }

  Future<void> _initGame() async {
    await _loadWords(); // 👈 ON ATTEND QUE LE JSON SOIT CHARGÉ AVANT DE CONTINUER
    
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
      _localAlivePlayers = widget.players.map((p) => p.name).toList();
      _localDistributionIndex = 0;
      _isRoleHidden = true;
      _gameResult = "";
      _guessController.clear();
    });

    // Sécurité : si on a vidé la pioche, on la remplit à nouveau !
    if (_remainingWordPairs.isEmpty) {
      _remainingWordPairs = List.from(_wordPairs)..shuffle();
    }

    // 1. Piocher une paire de mots (SANS REMISE pour ne pas avoir 2 fois la même partie)
    List<String> pair = List.from(_remainingWordPairs.removeLast());
    pair.shuffle(); 
    String civilWord = pair[0];
    String undercoverWord = pair[1];
    _civilWord = civilWord;

    // 2. Choisir les rôles
    List<String> shuffledNames = List.from(_localAlivePlayers)..shuffle();
    String mrWhiteName = shuffledNames[0];
    String? undercoverName;

    // S'il y a 4 joueurs ou plus, on met un Infiltré !
    if (_localAlivePlayers.length >= 4) {
      undercoverName = shuffledNames[1];
    }

    // 3. Distribuer les rôles
    for (String name in _localAlivePlayers) {
      if (name == mrWhiteName) {
        _localRoles[name] = "Mr White";
      } else if (name == undercoverName) {
        _localRoles[name] = undercoverWord;
      } else {
        _localRoles[name] = civilWord;
      }
    }

    setState(() => _isLoading = false);
  }

  void _nextLocalDistribution() {
    setState(() {
      _isRoleHidden = true;
      _localDistributionIndex++;
      if (_localDistributionIndex >= _localAlivePlayers.length) {
        _phase = "discussion"; 
      }
    });
  }

  void _handleLocalVote(String targetName) {
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
      if (value > maxVotes) {
        maxVotes = value;
        eliminated = key;
      }
    });

    setState(() {
      _eliminatedPlayer = eliminated;
      _localAlivePlayers.remove(eliminated);

      // --- NOUVELLES CONDITIONS DE VICTOIRE ---
      if (_localRoles[eliminated] == "Mr White") {
        // Mr White est démasqué ! Mais il a le droit de deviner
        _phase = "mr_white_guess";
      } else {
        _phase = "resultat";
        if (_localAlivePlayers.length <= 2) {
          // S'il ne reste que 2 personnes et que Mr White est là, il a gagné
          _gameResult = "VICTOIRE DE MR WHITE !";
        } else {
          // On a éliminé un Civil ou l'Infiltré, le jeu continue
          _gameResult = "CONTINUE"; 
        }
      }
    });
  }

  void _checkMrWhiteGuess() {
    String guess = _guessController.text.trim().toLowerCase();
    String actualWord = _civilWord.toLowerCase();

    setState(() {
      _phase = "resultat";
      if (guess == actualWord) {
        _gameResult = "MR WHITE A DEVINÉ LE MOT !\nIL VOLE LA VICTOIRE !";
      } else {
        _gameResult = "MAUVAISE RÉPONSE !\nVICTOIRE DES CIVILS !";
      }
    });
  }

  void _nextRoundLocal() {
    setState(() {
      _phase = "discussion";
      _localVotes.clear();
      _localVoteCount = 0;
      _hasVotedThisTurn = false;
      _eliminatedPlayer = "";
    });
  }

  // ==========================================
  // LOGIQUE MULTIJOUEUR EN LIGNE (En cours)
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
        _isLoading = false;
      });

      if (amIHost && data['mwPhase'] == null) {
        // Init logic online...
      }
    });
  }

  Future<void> _quit() async {
    setState(() => _canPop = true);
    Navigator.pop(context);
  }

  // ==========================================
  // INTERFACES (UI)
  // ==========================================
  Widget _glassCard({required Widget child, Color? borderColor}) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(25),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [Colors.white.withValues(alpha: 0.10), Colors.white.withValues(alpha: 0.03)]),
        borderRadius: BorderRadius.circular(25),
        border: Border.all(color: borderColor ?? Colors.white10, width: 1.5),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.2), blurRadius: 15, offset: const Offset(0, 5))],
      ),
      child: child,
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _canPop,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        _quit();
      },
      child: Scaffold(
        extendBodyBehindAppBar: true,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: Listener(
            onPointerDown: (_) => playPop(),
            child: IconButton(icon: const Icon(Icons.close, color: Colors.white, size: 30), onPressed: _quit),
          ),
          title: const Text("MR WHITE", style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, letterSpacing: 3)),
          centerTitle: true,
        ),
        body: Container(
          width: double.infinity, height: double.infinity,
          decoration: BoxDecoration(
            color: const Color(0xFF101012),
            image: DecorationImage(image: const AssetImage('assets/images/background.jpg'), fit: BoxFit.cover, colorFilter: ColorFilter.mode(Colors.black.withValues(alpha: 0.8), BlendMode.darken)),
          ),
          child: SafeArea(
            child: _isLoading 
              ? const Center(child: CircularProgressIndicator(color: Colors.white))
              : _buildCurrentPhase(),
          ),
        ),
      ),
    );
  }

  Widget _buildCurrentPhase() {
    if (_phase == "distribution") return _buildDistributionPhase();
    if (_phase == "discussion") return _buildDiscussionPhase();
    if (_phase == "vote") return _buildVotePhase();
    if (_phase == "mr_white_guess") return _buildMrWhiteGuessPhase();
    if (_phase == "resultat") return _buildResultPhase();
    return const SizedBox();
  }

  Widget _buildDistributionPhase() {
    if (widget.isOnline) return const Center(child: Text("Mode en ligne en cours de dev...", style: TextStyle(color: Colors.white)));

    String currentPlayer = _localAlivePlayers[_localDistributionIndex];
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
          _glassCard(
            child: const Text("Passez le téléphone à ce joueur.\nLui seul doit regarder l'écran !", textAlign: TextAlign.center, style: TextStyle(color: Colors.white70, fontSize: 16)),
          ),
          const SizedBox(height: 40),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: Listener(
              onPointerDown: (_) => playSwoosh(),
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.amber.shade600, minimumSize: const Size(double.infinity, 60), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20))),
                onPressed: () => setState(() => _isRoleHidden = false),
                child: const Text("VOIR MON MOT", style: TextStyle(color: Colors.black, fontWeight: FontWeight.w900, fontSize: 18)),
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
                child: const Text("CACHER ET PASSER", style: TextStyle(color: Colors.black, fontWeight: FontWeight.w900, fontSize: 18)),
              ),
            ),
          )
        ]
      ],
    ).animate().fadeIn();
  }

  Widget _buildDiscussionPhase() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Text("💬", style: TextStyle(fontSize: 60)),
        const SizedBox(height: 20),
        const Text("DÉBAT", style: TextStyle(color: Colors.white, fontSize: 30, fontWeight: FontWeight.w900, letterSpacing: 4)),
        const SizedBox(height: 20),
        _glassCard(
          child: const Text(
            "Chaque joueur décrit son mot avec UNE seule phrase.\n\nLe but des civils : Trouver Mr White.\nLe but de Mr White : Deviner le mot et se fondre dans la masse !", 
            textAlign: TextAlign.center, style: TextStyle(color: Colors.white70, fontSize: 16)
          ),
        ),
        const SizedBox(height: 40),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 40),
          child: Listener(
            onPointerDown: (_) => playHammer(),
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, minimumSize: const Size(double.infinity, 60), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20))),
              onPressed: () => setState(() => _phase = "vote"),
              child: const Text("PASSER AU VOTE", style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 18, letterSpacing: 1)),
            ),
          ),
        )
      ],
    ).animate().fadeIn();
  }

  Widget _buildVotePhase() {
    return Column(
      children: [
        const SizedBox(height: 20),
        const Text("QUI EST L'INTRUS ?", style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900, letterSpacing: 2)),
        const SizedBox(height: 10),
        Text("Au tour de ${_localAlivePlayers[_localVoteCount].toUpperCase()} de voter", style: const TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
        const SizedBox(height: 20),
        
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            itemCount: _localAlivePlayers.length,
            itemBuilder: (context, i) {
              String target = _localAlivePlayers[i];
              return Container(
                margin: const EdgeInsets.only(bottom: 10),
                decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.05), borderRadius: BorderRadius.circular(15), border: Border.all(color: Colors.white10)),
                child: Listener(
                  onPointerDown: (_) => playPop(),
                  child: ListTile(
                    title: Text(target, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
                    trailing: const Icon(Icons.how_to_vote, color: Colors.redAccent),
                    onTap: () => _handleLocalVote(target),
                  ),
                ),
              ).animate().fadeIn(delay: (i * 100).ms).slideX();
            },
          ),
        )
      ],
    ).animate().fadeIn();
  }

  // --- NOUVELLE PHASE : MR WHITE DEVINE LE MOT ---
  Widget _buildMrWhiteGuessPhase() {
    return SingleChildScrollView(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(height: 40),
          const Text("DÉMASQUÉ !", style: TextStyle(color: Colors.redAccent, fontSize: 35, fontWeight: FontWeight.w900, letterSpacing: 2)),
          const SizedBox(height: 10),
          Text("$_eliminatedPlayer était Mr White 🕶️", style: const TextStyle(color: Colors.white70, fontSize: 18)),
          const SizedBox(height: 30),
          
          _glassCard(
            borderColor: Colors.amber,
            child: Column(
              children: [
                const Text("DERNIÈRE CHANCE", style: TextStyle(color: Colors.amber, fontWeight: FontWeight.bold, letterSpacing: 2)),
                const SizedBox(height: 15),
                const Text("Si tu devines le mot des Civils,\ntu voles la victoire !", textAlign: TextAlign.center, style: TextStyle(color: Colors.white, fontSize: 16)),
                const SizedBox(height: 20),
                TextField(
                  controller: _guessController,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                  decoration: InputDecoration(
                    hintText: "Tape le mot ici...",
                    hintStyle: const TextStyle(color: Colors.white38),
                    filled: true,
                    fillColor: Colors.black45,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none),
                  ),
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
                onPressed: _checkMrWhiteGuess,
                child: const Text("TENTER MA CHANCE", style: TextStyle(color: Colors.black, fontWeight: FontWeight.w900, fontSize: 18)),
              ),
            ),
          )
        ],
      ).animate().fadeIn(),
    );
  }

  Widget _buildResultPhase() {
    bool isMrWhite = _localRoles[_eliminatedPlayer] == "Mr White";
    bool isUndercover = _localRoles[_eliminatedPlayer] != "Mr White" && _localRoles[_eliminatedPlayer] != _civilWord;
    
    String roleText = "CIVIL 🧍";
    Color roleColor = Colors.blueAccent;

    if (isMrWhite) {
      roleText = "MR WHITE 🕶️";
      roleColor = Colors.redAccent;
    } else if (isUndercover) {
      roleText = "INFILTRÉ 🕵️‍♂️\n(Son mot était : ${_localRoles[_eliminatedPlayer]})";
      roleColor = Colors.purpleAccent;
    }

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
                Text(
                  roleText, 
                  textAlign: TextAlign.center,
                  style: TextStyle(color: roleColor, fontSize: 24, fontWeight: FontWeight.w900)
                ),
              ],
            ),
          ).animate().scale(curve: Curves.easeOutBack),
          
          const SizedBox(height: 40),
          
          if (_gameResult == "CONTINUE") ...[
            const Text("LE JEU N'EST PAS FINI...", style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
            const SizedBox(height: 20),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40),
              child: Listener(
                onPointerDown: (_) => playPop(),
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.white, minimumSize: const Size(double.infinity, 60), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20))),
                  onPressed: _nextRoundLocal,
                  child: const Text("TOUR SUIVANT", style: TextStyle(color: Colors.black, fontWeight: FontWeight.w900)),
                ),
              ),
            )
          ] else ...[
            Text(_gameResult, textAlign: TextAlign.center, style: const TextStyle(color: Colors.amber, fontSize: 22, fontWeight: FontWeight.w900, letterSpacing: 2)),
            const SizedBox(height: 10),
            Text("Le mot secret était : $_civilWord", style: const TextStyle(color: Colors.white70, fontSize: 16, fontStyle: FontStyle.italic)),
            const SizedBox(height: 40),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40),
              child: Listener(
                onPointerDown: (_) => playPop(),
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.amber.shade600, minimumSize: const Size(double.infinity, 60), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20))),
                  onPressed: _startLocalGame,
                  child: const Text("REJOUER", style: TextStyle(color: Colors.black, fontWeight: FontWeight.w900)),
                ),
              ),
            ),
            const SizedBox(height: 15),
            TextButton(
              onPressed: _quit, 
              child: const Text("Retour au menu", style: TextStyle(color: Colors.white54))
            ),
            const SizedBox(height: 40),
          ]
        ],
      ).animate().fadeIn(),
    );
  }
}