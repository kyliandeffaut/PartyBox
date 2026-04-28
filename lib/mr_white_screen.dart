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
  
  // 👇 LES DEUX NOUVEAUX PARAMÈTRES
  final bool hasMrWhite;
  final bool hasUndercover;

  const MrWhiteScreen({
    super.key,
    required this.players,
    this.isOnline = false,
    this.lobbyId,
    this.currentPlayerName,
    this.hasMrWhite = true,
    this.hasUndercover = false,
  });

  @override
  State<MrWhiteScreen> createState() => _MrWhiteScreenState();
}

class _MrWhiteScreenState extends State<MrWhiteScreen> {
  List<List<String>> _wordPairs = [];
  List<List<String>> _remainingWordPairs = [];

  String _phase = "distribution"; 
  bool _isLoading = true;
  // ignore: unused_field
  bool _isHost = false;
  bool _canPop = false;

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

  Future<void> _loadWords() async {
    try {
      final String response = await rootBundle.loadString('assets/mr_white.json');
      final List<dynamic> data = json.decode(response);
      
      _wordPairs = data.map((pair) => List<String>.from(pair)).toList();
      _remainingWordPairs = List.from(_wordPairs)..shuffle();
    } catch (e) {
      debugPrint("Erreur chargement mr_white.json: $e");
    }
  }

  Future<void> _initGame() async {
    await _loadWords(); 
    
    if (widget.isOnline && widget.lobbyId != null) {
      _listenLobby();
    } else {
      _startLocalGame();
    }
  }

  void _startLocalGame() {
    setState(() {
      _phase = "distribution";
      _localRoles.clear();
      _localAlivePlayers = widget.players.map((p) => p.name).toList();
      _localDistributionIndex = 0;
      _isRoleHidden = true;
      _gameResult = "";
      _guessController.clear();
      
      _localVotes.clear();
      _localVoteCount = 0;
      _hasVotedThisTurn = false;
    });

    if (_remainingWordPairs.isEmpty) {
      _remainingWordPairs = List.from(_wordPairs)..shuffle();
    }

    List<String> pair = List.from(_remainingWordPairs.removeLast());
    pair.shuffle(); 
    String civilWord = pair[0];
    String undercoverWord = pair[1];
    _civilWord = civilWord;

    // --- DISTRIBUTION DES RÔLES SELON LES PARAMÈTRES ---
    List<String> shuffledNames = List.from(_localAlivePlayers)..shuffle();
    String? mrWhiteName;
    String? undercoverName;
    int roleIndex = 0;

    if (widget.hasMrWhite) {
      mrWhiteName = shuffledNames[roleIndex];
      roleIndex++;
    }
    if (widget.hasUndercover && roleIndex < shuffledNames.length) {
      undercoverName = shuffledNames[roleIndex];
    }

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
      if (value > maxVotes) {
        maxVotes = value;
        eliminated = key;
      }
    });

    setState(() {
      _eliminatedPlayer = eliminated;
      _localAlivePlayers.remove(eliminated);

      if (_localRoles[eliminated] == "Mr White") {
        _phase = "mr_white_guess";
      } else {
        _checkWinConditions();
      }
    });
  }

  void _checkWinConditions() {
    bool mwAlive = _localAlivePlayers.any((p) => _localRoles[p] == "Mr White");
    bool ucAlive = _localAlivePlayers.any((p) => _localRoles[p] != _civilWord && _localRoles[p] != "Mr White");

    setState(() {
      _phase = "resultat";
      if (!mwAlive && !ucAlive) {
        _gameResult = "VICTOIRE DES CIVILS !";
      } else if (_localAlivePlayers.length <= 2) {
        _gameResult = "VICTOIRE DES IMPOSTEURS !"; 
      } else {
        _gameResult = "CONTINUE"; 
      }
    });
  }

  void _checkMrWhiteGuess() {
    String guess = _guessController.text.trim().toLowerCase();
    String actualWord = _civilWord.toLowerCase();

    if (guess == actualWord) {
      setState(() {
        _phase = "resultat";
        _gameResult = "MR WHITE A DEVINÉ LE MOT !\nIL VOLE LA VICTOIRE !";
      });
    } else {
      _checkWinConditions(); // Si Mr White se trompe, on vérifie si l'Infiltré est encore en vie
    }
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
          title: const Text("LE MOT SECRET", style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, letterSpacing: 3)),
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
            "Chaque joueur décrit son mot avec UNE seule phrase.\n\nLe but : Trouver qui n'a pas le bon mot !", 
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
        const Text("QUI EST L'IMPOSTEUR ?", style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900, letterSpacing: 2)),
        const SizedBox(height: 10),
        Builder(
          builder: (context) {
            int safeVoteIndex = _localVoteCount < _localAlivePlayers.length ? _localVoteCount : 0;
            return Text("Au tour de ${_localAlivePlayers[safeVoteIndex].toUpperCase()} de voter", style: const TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold));
          }
        ),
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
      roleText = "INFILTRÉ 🕵️‍♂️\n(Son mot : ${_localRoles[_eliminatedPlayer]})";
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
            const Text("ATTENTION : UN IMPOSTEUR EST TOUJOURS LÀ...", textAlign: TextAlign.center, style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
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
            Text("Le mot des civils était : $_civilWord", style: const TextStyle(color: Colors.white70, fontSize: 16, fontStyle: FontStyle.italic)),
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