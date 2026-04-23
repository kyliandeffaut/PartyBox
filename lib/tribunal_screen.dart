import 'dart:convert';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';

import 'main.dart';

class TribunalScreen extends StatefulWidget {
  final List<Player> players;
  final bool isOnline;
  final String? lobbyId;
  final String? currentPlayerName;

  const TribunalScreen({
    super.key,
    required this.players,
    this.isOnline = false,
    this.lobbyId,
    this.currentPlayerName,
  });

  @override
  State<TribunalScreen> createState() => _TribunalScreenState();
}

class _TribunalScreenState extends State<TribunalScreen> {
  List<String> _questions = [];
  String _currentQuestion = "Chargement...";
  bool _isLoading = true;
  bool _isHost = false;
  bool _hasVotedThisTurn = false;
  String? _myVoteTarget;

  bool _canPop = false;

  static const String _fieldQuestion = 'currentQuestion';

  // --- 🔄 VARIABLES POUR LE MODE LOCAL (Hors-ligne) ---
  final Map<String, int> _localVotes = {};
  int _localVoteCount = 0;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    await _loadQuestions();
    if (widget.isOnline && widget.lobbyId != null) {
      _listenLobby();
    } else {
      setState(() => _isLoading = false);
      _pickNextLocal();
    }
  }

  Future<void> _loadQuestions() async {
    try {
      final response = await rootBundle.loadString('assets/tribunal.json');
      final decoded = json.decode(response);
      if (decoded is List) {
        _questions = decoded.map((e) => e.toString()).where((s) => s.trim().isNotEmpty).toList();
      } else {
        _questions = [];
      }
    } catch (e) {
      debugPrint("Erreur chargement tribunal.json: $e");
      _questions = [];
    }
  }

  void _listenLobby() {
    FirebaseFirestore.instance.collection('lobbies').doc(widget.lobbyId).snapshots().listen((snap) {
      if (!snap.exists || snap.data() == null) return;
      final data = snap.data()!;
      final bool amIHost = (data['host'] ?? '').toString() == (widget.currentPlayerName ?? '');

      final List<dynamic> fbPlayers = data['activePlayers'] ?? [];
      bool amIVoted = false;
      String? myTarget;
      final List<Player> rebuilt = [];

      for (final p in fbPlayers) {
        if (p is! Map) continue;
        final name = (p['name'] ?? '').toString();
        if (name.isEmpty) continue;
        if (name == widget.currentPlayerName) {
          amIVoted = (p['hasVoted'] ?? false) == true;
          myTarget = p['voteTarget']?.toString();
        }
        rebuilt.add(
          Player(
            name: name,
            gender: (p['gender'] ?? 'H').toString(),
            score: (p['score'] ?? 0) as int,
          ),
        );
      }

      if (!mounted) return;
      setState(() {
        _isHost = amIHost;
        _currentQuestion = (data[_fieldQuestion] ?? "Le chef choisit...").toString();
        widget.players
          ..clear()
          ..addAll(rebuilt);
        _hasVotedThisTurn = amIVoted;
        _myVoteTarget = myTarget;
        _isLoading = false;
      });

      if (amIHost && (_currentQuestion == "Le chef choisit..." || data[_fieldQuestion] == null)) {
        _nextQuestionOnline();
      }
    });
  }

  Future<void> _quit() async {
    if (widget.isOnline && widget.lobbyId != null) {
      final docRef = FirebaseFirestore.instance.collection('lobbies').doc(widget.lobbyId);
      final doc = await docRef.get();
      if (doc.exists) {
        final data = doc.data() as Map<String, dynamic>;
        final List activeP = List.from(data['activePlayers'] ?? []);
        activeP.removeWhere((p) => p is Map && p['name'] == widget.currentPlayerName);
        await docRef.update({'activePlayers': activeP});
      }
    }
    if (!mounted) return;
    setState(() => _canPop = true);
    Navigator.pop(context);
  }

  bool _allVotedOnline(List<dynamic> fbPlayers) {
    if (fbPlayers.isEmpty) return false;
    return fbPlayers.whereType<Map>().every((p) => (p['hasVoted'] ?? false) == true);
  }

  Map<String, int> _countVotes(List<dynamic> fbPlayers) {
    final counts = <String, int>{};
    for (final p in fbPlayers) {
      if (p is! Map) continue;
      final target = p['voteTarget']?.toString();
      if (target == null || target.isEmpty) continue;
      counts[target] = (counts[target] ?? 0) + 1;
    }
    return counts;
  }

  Future<void> _voteOnline(String targetName) async {
    if (_hasVotedThisTurn || widget.lobbyId == null) return;
    final docRef = FirebaseFirestore.instance.collection('lobbies').doc(widget.lobbyId);
    final doc = await docRef.get();
    if (!doc.exists) return;

    final List activeP = List.from(doc.data()?['activePlayers'] ?? []);
    final List allP = List.from(doc.data()?['players'] ?? []);

    for (final p in activeP) {
      if (p is Map && p['name'] == widget.currentPlayerName) {
        p['hasVoted'] = true;
        p['voteTarget'] = targetName;
      }
    }
    for (final p in allP) {
      if (p is Map && p['name'] == widget.currentPlayerName) {
        p['hasVoted'] = true;
        p['voteTarget'] = targetName;
      }
    }

    await docRef.update({'activePlayers': activeP, 'players': allP});
  }

  Future<void> _nextQuestionOnline() async {
    if (widget.lobbyId == null) return;
    if (_questions.isEmpty) {
      await _loadQuestions();
      if (_questions.isEmpty) return;
    }

    final String newQ = _questions[Random().nextInt(_questions.length)];

    try {
      final docRef = FirebaseFirestore.instance.collection('lobbies').doc(widget.lobbyId);
      final doc = await docRef.get();
      if (!doc.exists) return;

      final List activeP = List.from(doc.data()?['activePlayers'] ?? []);
      final List allP = List.from(doc.data()?['players'] ?? []);

      for (final p in activeP) {
        if (p is Map) {
          p['hasVoted'] = false;
          p['voteTarget'] = null;
        }
      }
      for (final p in allP) {
        if (p is Map) {
          p['hasVoted'] = false;
          p['voteTarget'] = null;
        }
      }

      await docRef.update({
        _fieldQuestion: newQ,
        'activePlayers': activeP,
        'players': allP,
      });
    } catch (e) {
      debugPrint("Erreur update Firestore (Tribunal): $e");
    }
  }

  // --- 🔄 FONCTIONS POUR LE MODE LOCAL ---
  void _pickNextLocal() {
    if (_questions.isEmpty) return;
    setState(() {
      _currentQuestion = _questions[Random().nextInt(_questions.length)];
      _hasVotedThisTurn = false;
      _myVoteTarget = null;
      _localVotes.clear(); // On réinitialise les votes locaux
      _localVoteCount = 0; // On remet le compteur à zéro
    });
  }

  void _handleLocalVote(String targetName) {
    setState(() {
      _localVotes[targetName] = (_localVotes[targetName] ?? 0) + 1;
      _localVoteCount++;

      // Si tout le monde a voté, on affiche les résultats
      if (_localVoteCount >= widget.players.length) {
        _hasVotedThisTurn = true; 
      } else {
        // Affiche un petit message pour dire de passer le téléphone
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Vote enregistré ! Passe le téléphone à ${widget.players[_localVoteCount].name}"),
            duration: const Duration(seconds: 1, milliseconds: 500),
            backgroundColor: Colors.purpleAccent,
          ),
        );
      }
    });
  }
  // ---------------------------------------

  Widget _glassCard({required Widget child}) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [Colors.white.withOpacity(0.10), Colors.white.withOpacity(0.03)]),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.white10),
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
          leading: IconButton(
            icon: const Icon(Icons.close, color: Colors.white, size: 30),
            onPressed: _quit,
          ),
        ),
        body: Container(
          width: double.infinity,
          height: double.infinity,
          decoration: const BoxDecoration(
            color: Color(0xFF101012),
            image: DecorationImage(
              image: AssetImage('assets/images/background.jpg'),
              fit: BoxFit.cover,
              opacity: 0.30,
            ),
          ),
          child: SafeArea(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: Colors.purpleAccent))
                : StreamBuilder<DocumentSnapshot>(
                    stream: widget.isOnline ? FirebaseFirestore.instance.collection('lobbies').doc(widget.lobbyId).snapshots() : null,
                    builder: (context, snap) {
                      List<dynamic> fbPlayers = [];
                      if (widget.isOnline && snap.hasData && snap.data!.exists) {
                        final data = snap.data!.data() as Map<String, dynamic>;
                        fbPlayers = data['activePlayers'] ?? [];
                      }
                      
                      // 🔄 CHOIX DYNAMIQUE (LIGNE OU LOCAL) POUR LES STATS
                      final allVoted = widget.isOnline ? _allVotedOnline(fbPlayers) : _hasVotedThisTurn;
                      final counts = widget.isOnline ? _countVotes(fbPlayers) : _localVotes;
                      final totalVotes = widget.isOnline ? fbPlayers.length : _localVoteCount;

                      return Column(
                        children: [
                          const SizedBox(height: 10),
                          const Text(
                            "LE TRIBUNAL • QUI DE NOUS DEUX ?",
                            style: TextStyle(color: Colors.white70, fontWeight: FontWeight.w900, letterSpacing: 2, fontSize: 13),
                          ),
                          const SizedBox(height: 16),
                          _glassCard(
                            child: Column(
                              children: [
                                const Text("⚖️", style: TextStyle(fontSize: 30)),
                                const SizedBox(height: 10),
                                Text(
                                  _currentQuestion,
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w900),
                                ),
                              ],
                            ),
                          ).animate().fadeIn().scale(),
                          const SizedBox(height: 16),

                          if (!allVoted) ...[
                            const Text("VOTE EN SECRET", style: TextStyle(color: Colors.white54, fontWeight: FontWeight.bold, letterSpacing: 2)),
                            const SizedBox(height: 10),
                            Expanded(
                              child: ListView.builder(
                                padding: const EdgeInsets.symmetric(horizontal: 20),
                                itemCount: widget.players.length,
                                itemBuilder: (context, i) {
                                  final p = widget.players[i];
                                  final isMe = widget.isOnline && p.name == widget.currentPlayerName;
                                  
                                  // En local, on ne s'affiche pas soi-même dans la liste pour ne pas voter pour soi
                                  if (!widget.isOnline && p.name == widget.players[_localVoteCount].name) {
                                    return const SizedBox(); 
                                  }

                                  return Container(
                                    margin: const EdgeInsets.only(bottom: 10),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withOpacity(0.05),
                                      borderRadius: BorderRadius.circular(16),
                                      border: Border.all(color: Colors.white10),
                                    ),
                                    child: ListTile(
                                      leading: CircleAvatar(
                                        backgroundColor: p.gender == 'H' ? Colors.blueAccent : Colors.pinkAccent,
                                        child: Text(p.name.isEmpty ? "?" : p.name[0], style: const TextStyle(color: Colors.white)),
                                      ),
                                      title: Text(
                                        p.name + (isMe ? " (Moi)" : ""),
                                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                                      ),
                                      trailing: _hasVotedThisTurn
                                          ? const Icon(Icons.lock, color: Colors.white24)
                                          : const Icon(Icons.how_to_vote, color: Colors.purpleAccent),
                                      onTap: _hasVotedThisTurn
                                          ? null
                                          : () {
                                              if (widget.isOnline) {
                                                _voteOnline(p.name);
                                              } else {
                                                _handleLocalVote(p.name); // 👈 Appel local
                                              }
                                            },
                                    ),
                                  ).animate().fadeIn(delay: (i * 60).ms).slideX(begin: 0.15);
                                },
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              _hasVotedThisTurn 
                                ? "Vote envoyé ✅" 
                                : (widget.isOnline 
                                    ? "Choisis un joueur…" 
                                    : "Au tour de ${widget.players[_localVoteCount].name} de voter !"),
                              style: TextStyle(color: _hasVotedThisTurn ? Colors.greenAccent : Colors.purpleAccent, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 10),
                          ] else ...[
                            const Text("RÉSULTATS", style: TextStyle(color: Colors.white70, fontWeight: FontWeight.w900, letterSpacing: 2)),
                            const SizedBox(height: 10),
                            Expanded(
                              child: ListView(
                                padding: const EdgeInsets.symmetric(horizontal: 20),
                                children: [
                                  ...((counts.entries.toList()..sort((a, b) => b.value.compareTo(a.value))).map((e) {
                                    final pct = totalVotes == 0 ? 0 : ((e.value / totalVotes) * 100).round();
                                    return Container(
                                      margin: const EdgeInsets.only(bottom: 10),
                                      padding: const EdgeInsets.all(14),
                                      decoration: BoxDecoration(
                                        color: Colors.white.withOpacity(0.05),
                                        borderRadius: BorderRadius.circular(16),
                                        border: Border.all(color: Colors.white10),
                                      ),
                                      child: Row(
                                        children: [
                                          Expanded(
                                            child: Text(
                                              e.key,
                                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                                            ),
                                          ),
                                          Text(
                                            "$pct%",
                                            style: const TextStyle(color: Colors.amber, fontWeight: FontWeight.w900, fontSize: 18),
                                          ),
                                        ],
                                      ),
                                    ).animate().fadeIn().slideY(begin: 0.1);
                                  }).toList()),
                                  if (widget.isOnline && _myVoteTarget != null)
                                    _glassCard(
                                      child: Text(
                                        "Ton vote : $_myVoteTarget",
                                        textAlign: TextAlign.center,
                                        style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.bold),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            if (!widget.isOnline)
                              Padding(
                                padding: const EdgeInsets.all(20),
                                child: ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.purpleAccent,
                                    minimumSize: const Size(double.infinity, 52),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                  ),
                                  onPressed: _pickNextLocal,
                                  child: const Text("QUESTION SUIVANTE ➔", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                                ),
                              )
                            else if (_isHost)
                              Padding(
                                padding: const EdgeInsets.all(20),
                                child: ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.purpleAccent,
                                    minimumSize: const Size(double.infinity, 52),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                  ),
                                  onPressed: _nextQuestionOnline,
                                  child: const Text("SUIVANTE ➔", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                                ),
                              )
                            else
                              const SizedBox(height: 20),
                          ],
                        ],
                      );
                    },
                  ),
          ),
        ),
      ),
    );
  }
}