import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'dart:math';
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
  // --- BASE DE MOTS SECRETS (Tu pourras l'agrandir plus tard !) ---
  final List<String> _words = [
    'Téléphone', 'Guitare', 'Chocolat', 'Plage', 'Avion', 
    'Dinosaure', 'Pizza', 'Cinéma', 'Livre', 'Vampire',
    'Voiture', 'Piscine', 'Chien', 'Chat', 'Internet'
  ];

  // --- ÉTATS DU JEU ---
  // phases possibles : 'distribution', 'discussion', 'vote', 'resultat'
  String _phase = "distribution"; 
  bool _isLoading = true;
  // ignore: unused_field
  bool _isHost = false;
  bool _canPop = false;

  // --- VARIABLES LOCALES (Pass & Play) ---
  Map<String, String> _localRoles = {}; // Nom -> Mot (ou 'Mr White')
  List<String> _localAlivePlayers = [];
  int _localDistributionIndex = 0;
  bool _isRoleHidden = true; // Pour cacher l'écran entre deux joueurs
  Map<String, int> _localVotes = {};
  int _localVoteCount = 0;
  // ignore: unused_field
  bool _hasVotedThisTurn = false;
  String _eliminatedPlayer = "";
  String _gameResult = ""; // Qui a gagné ?

  @override
  void initState() {
    super.initState();
    _initGame();
  }

  Future<void> _initGame() async {
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
    });

    // 1. Piocher un mot au hasard
    String secretWord = _words[Random().nextInt(_words.length)];
    
    // 2. Choisir Mr White au hasard
    List<String> shuffledNames = List.from(_localAlivePlayers)..shuffle();
    String mrWhiteName = shuffledNames.first;

    // 3. Distribuer les rôles
    for (String name in _localAlivePlayers) {
      _localRoles[name] = (name == mrWhiteName) ? "Mr White" : secretWord;
    }

    setState(() => _isLoading = false);
  }

  void _nextLocalDistribution() {
    setState(() {
      _isRoleHidden = true;
      _localDistributionIndex++;
      if (_localDistributionIndex >= _localAlivePlayers.length) {
        _phase = "discussion"; // Tout le monde a vu son rôle !
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
    // Trouver qui a le plus de votes
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
      _phase = "resultat";

      // Vérifier les conditions de victoire
      if (_localRoles[eliminated] == "Mr White") {
        _gameResult = "VICTOIRE DES CIVILS !";
      } else if (_localAlivePlayers.length <= 2) {
        _gameResult = "VICTOIRE DE MR WHITE !"; // Mr White a survécu jusqu'au bout
      } else {
        _gameResult = "CONTINUE"; // Le jeu continue
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
  // LOGIQUE MULTIJOUEUR EN LIGNE
  // ==========================================
  void _listenLobby() {
    FirebaseFirestore.instance.collection('lobbies').doc(widget.lobbyId).snapshots().listen((snap) {
      if (!snap.exists || snap.data() == null) return;
      final data = snap.data()!;
      final bool amIHost = (data['host'] ?? '').toString() == (widget.currentPlayerName ?? '');

      // On lit la phase actuelle depuis Firebase
      String fbPhase = data['mwPhase'] ?? 'distribution';

      if (!mounted) return;
      setState(() {
        _isHost = amIHost;
        _phase = fbPhase;
        _isLoading = false;
        // On pourrait récupérer les rôles ici pour le mode en ligne
        // (Pour l'instant la logique UI va se baser sur Firebase pour l'online)
      });

      // Si le chef vient de lancer et qu'il n'y a pas encore de phase, on initialise
      if (amIHost && data['mwPhase'] == null) {
        _startOnlineGame(data);
      }
    });
  }

  Future<void> _startOnlineGame(Map<String, dynamic> currentData) async {
    // Même logique de distribution mais envoyée sur Firebase
    String secretWord = _words[Random().nextInt(_words.length)];
    List activeP = List.from(currentData['activePlayers'] ?? []);
    
    if (activeP.isEmpty) return;

    List<String> names = activeP.map((p) => p['name'].toString()).toList();
    names.shuffle();
    String mrWhiteName = names.first;

    for (var p in activeP) {
      if (p is Map) {
        p['mwRole'] = (p['name'] == mrWhiteName) ? "Mr White" : secretWord;
        p['isAlive'] = true;
        p['hasVoted'] = false;
        p['voteTarget'] = null;
      }
    }

    await FirebaseFirestore.instance.collection('lobbies').doc(widget.lobbyId).update({
      'mwPhase': 'distribution',
      'activePlayers': activeP,
    });
  }

  Future<void> _quit() async {
    // Logique standard de déconnexion
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
    if (_phase == "resultat") return _buildResultPhase();
    return const SizedBox();
  }

  // --- 1. PHASE DE DISTRIBUTION ---
  Widget _buildDistributionPhase() {
    if (widget.isOnline) {
      // En mode en ligne, chacun voit son rôle directement (A coder plus tard pour le multi complet)
      return const Center(child: Text("Mode en ligne en cours de dev...", style: TextStyle(color: Colors.white)));
    }

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

  // --- 2. PHASE DE DISCUSSION ---
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

  // --- 3. PHASE DE VOTE ---
  Widget _buildVotePhase() {
    return Column(
      children: [
        const SizedBox(height: 20),
        const Text("QUI EST MR WHITE ?", style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900, letterSpacing: 2)),
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

  // --- 4. PHASE DE RÉSULTAT ---
  Widget _buildResultPhase() {
    bool isMrWhite = _localRoles[_eliminatedPlayer] == "Mr White";
    
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(_eliminatedPlayer.toUpperCase(), style: const TextStyle(color: Colors.white, fontSize: 35, fontWeight: FontWeight.w900)),
        const Text("A ÉTÉ ÉLIMINÉ !", style: TextStyle(color: Colors.white54, fontSize: 18, letterSpacing: 2)),
        const SizedBox(height: 40),
        _glassCard(
          borderColor: isMrWhite ? Colors.greenAccent : Colors.redAccent,
          child: Column(
            children: [
              Text("SON RÔLE ÉTAIT :", style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontWeight: FontWeight.bold)),
              const SizedBox(height: 10),
              Text(
                isMrWhite ? "MR WHITE 🕵️‍♂️" : "CIVIL 🧍‍♂️", 
                style: TextStyle(color: isMrWhite ? Colors.greenAccent : Colors.redAccent, fontSize: 28, fontWeight: FontWeight.w900)
              ),
            ],
          ),
        ).animate().scale(curve: Curves.easeOutBack),
        
        const SizedBox(height: 40),
        
        if (_gameResult == "CONTINUE") ...[
          const Text("MR WHITE EST TOUJOURS EN VIE...", style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
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
          Text(_gameResult, style: const TextStyle(color: Colors.amber, fontSize: 22, fontWeight: FontWeight.w900, letterSpacing: 2)),
          const SizedBox(height: 40),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: Listener(
              onPointerDown: (_) => playPop(),
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.amber.shade600, minimumSize: const Size(double.infinity, 60), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20))),
                onPressed: _startLocalGame, // On relance une partie
                child: const Text("REJOUER", style: TextStyle(color: Colors.black, fontWeight: FontWeight.w900)),
              ),
            ),
          ),
          const SizedBox(height: 15),
          TextButton(
            onPressed: _quit, 
            child: const Text("Retour au menu", style: TextStyle(color: Colors.white54))
          )
        ]
      ],
    ).animate().fadeIn();
  }
}