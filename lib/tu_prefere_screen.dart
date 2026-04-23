import 'dart:convert';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';

import 'main.dart';

class TuPrefereScreen extends StatefulWidget {
  final List<Player> players;
  final bool isOnline;
  final String? lobbyId;
  final String? currentPlayerName;

  const TuPrefereScreen({
    super.key,
    required this.players,
    this.isOnline = false,
    this.lobbyId,
    this.currentPlayerName,
  });

  @override
  State<TuPrefereScreen> createState() => _TuPrefereScreenState();
}

class _TuPrefereScreenState extends State<TuPrefereScreen> {
  List<Map<String, String>> _questions = [];
  String _optionA = "Chargement...";
  String _optionB = "Chargement...";
  bool _isLoading = true;
  bool _isHost = false;
  bool _hasVotedThisTurn = false;
  // ignore: unused_field
  String? _myChoice; // 'A'|'B'

  bool _canPop = false;

  static const String _fieldQuestion = 'currentQuestion';

  // --- VARIABLES POUR LE MODE LOCAL (Hors-ligne) ---
  final Map<String, int> _localChoices = {'A': 0, 'B': 0};
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
      final response = await rootBundle.loadString('assets/tu_prefere.json');
      final decoded = json.decode(response);
      if (decoded is List) {
        _questions = decoded
            .whereType<Map>()
            .map((m) => {
                  'a': (m['a'] ?? '').toString().trim(),
                  'b': (m['b'] ?? '').toString().trim(),
                })
            .where((m) => m['a']!.isNotEmpty && m['b']!.isNotEmpty)
            .toList();
      } else {
        _questions = [];
      }
    } catch (e) {
      debugPrint("Erreur chargement tu_prefere.json: $e");
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
      String? myChoice;
      final List<Player> rebuilt = [];

      for (final p in fbPlayers) {
        if (p is! Map) continue;
        final name = (p['name'] ?? '').toString();
        if (name.isEmpty) continue;
        if (name == widget.currentPlayerName) {
          amIVoted = (p['hasVoted'] ?? false) == true;
          myChoice = p['tpChoice']?.toString();
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
        final cq = data[_fieldQuestion];
        if (cq is Map) {
          _optionA = (cq['a'] ?? "Le chef choisit...").toString();
          _optionB = (cq['b'] ?? "Le chef choisit...").toString();
        } else {
          _optionA = "Le chef choisit...";
          _optionB = "Le chef choisit...";
        }
        widget.players
          ..clear()
          ..addAll(rebuilt);
        _hasVotedThisTurn = amIVoted;
        _myChoice = myChoice;
        _isLoading = false;
      });

      if (amIHost && (_optionA == "Le chef choisit..." || _optionB == "Le chef choisit...")) {
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

  Future<void> _voteOnline(String choice) async {
    if (_hasVotedThisTurn || widget.lobbyId == null) return;
    final docRef = FirebaseFirestore.instance.collection('lobbies').doc(widget.lobbyId);
    final doc = await docRef.get();
    if (!doc.exists) return;

    final List activeP = List.from(doc.data()?['activePlayers'] ?? []);
    final List allP = List.from(doc.data()?['players'] ?? []);

    for (final p in activeP) {
      if (p is Map && p['name'] == widget.currentPlayerName) {
        p['hasVoted'] = true;
        p['tpChoice'] = choice;
      }
    }
    for (final p in allP) {
      if (p is Map && p['name'] == widget.currentPlayerName) {
        p['hasVoted'] = true;
        p['tpChoice'] = choice;
      }
    }

    await docRef.update({'activePlayers': activeP, 'players': allP});
  }

  Map<String, int> _countChoices(List<dynamic> fbPlayers) {
    int a = 0;
    int b = 0;
    for (final p in fbPlayers) {
      if (p is! Map) continue;
      final c = p['tpChoice']?.toString();
      if (c == 'A') a++;
      if (c == 'B') b++;
    }
    return {'A': a, 'B': b};
  }

  Future<void> _nextQuestionOnline() async {
    if (widget.lobbyId == null) return;
    if (_questions.isEmpty) return;
    
    final q = _questions[Random().nextInt(_questions.length)];

    try {
      final docRef = FirebaseFirestore.instance.collection('lobbies').doc(widget.lobbyId);
      final doc = await docRef.get();
      if (!doc.exists) return;

      final List activeP = List.from(doc.data()?['activePlayers'] ?? []);
      final List allP = List.from(doc.data()?['players'] ?? []);

      for (final p in activeP) {
        if (p is Map) {
          p['hasVoted'] = false;
          p['tpChoice'] = null;
        }
      }
      for (final p in allP) {
        if (p is Map) {
          p['hasVoted'] = false;
          p['tpChoice'] = null;
        }
      }

      await docRef.update({
        _fieldQuestion: {'a': q['a'], 'b': q['b']},
        'activePlayers': activeP,
        'players': allP,
      });
    } catch (e) {
      debugPrint("Erreur update Firestore (Tu préfères): $e");
    }
  }

  // --- 🔄 FONCTIONS POUR LE MODE LOCAL ---
  void _pickNextLocal() {
    if (_questions.isEmpty) return;
    final q = _questions[Random().nextInt(_questions.length)];
    setState(() {
      _optionA = q['a'] ?? '';
      _optionB = q['b'] ?? '';
      _hasVotedThisTurn = false;
      _myChoice = null;
      _localChoices['A'] = 0;
      _localChoices['B'] = 0;
      _localVoteCount = 0;
    });
  }

  void _handleLocalChoice(String choice) {
    setState(() {
      _localChoices[choice] = (_localChoices[choice] ?? 0) + 1;
      _localVoteCount++;

      if (_localVoteCount >= widget.players.length) {
        _hasVotedThisTurn = true;
      }
    });
  }
  // ---------------------------------------

  Widget _choiceButton({
    required String label,
    required String choice,
    required Color color,
    required VoidCallback onTap,
  }) {
    final bool disabled = _hasVotedThisTurn;
    return Expanded(
      child: InkWell(
        onTap: disabled ? null : onTap,
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: [color.withOpacity(0.25), color.withOpacity(0.05)]),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: color.withOpacity(0.55)),
          ),
          child: Column(
            children: [
              Text(label, style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.w900, letterSpacing: 2, fontSize: 12)),
              const SizedBox(height: 8),
              Text(
                choice,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900),
              ),
            ],
          ),
        ),
      ).animate().fadeIn().slideY(begin: 0.12, end: 0),
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
                ? const Center(child: CircularProgressIndicator(color: Colors.pinkAccent))
                : StreamBuilder<DocumentSnapshot>(
                    stream: widget.isOnline ? FirebaseFirestore.instance.collection('lobbies').doc(widget.lobbyId).snapshots() : null,
                    builder: (context, snap) {
                      List<dynamic> fbPlayers = [];
                      if (widget.isOnline && snap.hasData && snap.data!.exists) {
                        final data = snap.data!.data() as Map<String, dynamic>;
                        fbPlayers = data['activePlayers'] ?? [];
                      }

                      final allVoted = widget.isOnline ? _allVotedOnline(fbPlayers) : _hasVotedThisTurn;
                      final counts = widget.isOnline ? _countChoices(fbPlayers) : _localChoices;
                      final total = widget.isOnline ? fbPlayers.length : _localVoteCount;
                      
                      final int a = counts['A'] ?? 0;
                      final int b = counts['B'] ?? 0;
                      final int pctA = total == 0 ? 0 : ((a / total) * 100).round();
                      final int pctB = total == 0 ? 0 : ((b / total) * 100).round();

                      final String majority =
                          a == b ? "ÉGALITÉ" : (a > b ? "MAJORITÉ : A" : "MAJORITÉ : B");
                      final String minority =
                          a == b ? "MINORITÉ : —" : (a < b ? "MINORITÉ : A" : "MINORITÉ : B");

                      return Column(
                        children: [
                          const SizedBox(height: 10),
                          const Text(
                            "TU PRÉFÈRES ? • CHOIX CORNÉLIEN",
                            style: TextStyle(color: Colors.white70, fontWeight: FontWeight.w900, letterSpacing: 2, fontSize: 13),
                          ),
                          const SizedBox(height: 16),

                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 20),
                            child: Row(
                              children: [
                                _choiceButton(
                                  label: "CHOIX A",
                                  choice: _optionA,
                                  color: Colors.blueAccent,
                                  onTap: () {
                                    if (widget.isOnline) {
                                      _voteOnline('A');
                                    } else {
                                      _handleLocalChoice('A'); 
                                    }
                                  },
                                ),
                                const SizedBox(width: 12),
                                _choiceButton(
                                  label: "CHOIX B",
                                  choice: _optionB,
                                  color: Colors.pinkAccent,
                                  onTap: () {
                                    if (widget.isOnline) {
                                      _voteOnline('B');
                                    } else {
                                      _handleLocalChoice('B'); 
                                    }
                                  },
                                ),
                              ],
                            ),
                          ),
                          
                          const SizedBox(height: 14),

                          if (!allVoted) ...[
                            Text(
                              _hasVotedThisTurn 
                                ? "Vote envoyé ✅" 
                                : (widget.isOnline 
                                    ? "VOTE EN SECRET" 
                                    : "Au tour de ${widget.players[_localVoteCount].name} de choisir !"),
                              style: TextStyle(
                                color: _hasVotedThisTurn ? Colors.greenAccent : Colors.purpleAccent, 
                                fontWeight: FontWeight.w900, 
                                fontSize: 20, 
                                letterSpacing: 1
                              ),
                            ),
                            const SizedBox(height: 16),
                          ],

                          if (!allVoted) ...[
                            Expanded(
                              child: ListView.builder(
                                padding: const EdgeInsets.symmetric(horizontal: 20),
                                itemCount: widget.players.length,
                                itemBuilder: (context, i) {
                                  final p = widget.players[i];
                                  final isMe = widget.isOnline && p.name == widget.currentPlayerName;
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
                                      title: Text(p.name + (isMe ? " (Moi)" : ""), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                                      trailing: const Icon(Icons.lock, color: Colors.white24),
                                    ),
                                  ).animate().fadeIn(delay: (i * 60).ms).slideX(begin: 0.12);
                                },
                              ),
                            ),
                          ] else ...[
                            const SizedBox(height: 6),
                            Container(
                              margin: const EdgeInsets.symmetric(horizontal: 20),
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(colors: [Colors.white.withOpacity(0.10), Colors.white.withOpacity(0.03)]),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: Colors.white10),
                              ),
                              child: Column(
                                children: [
                                  const Text("RÉSULTATS", style: TextStyle(color: Colors.white70, fontWeight: FontWeight.w900, letterSpacing: 2)),
                                  const SizedBox(height: 10),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text("A", style: TextStyle(color: Colors.blueAccent.shade100, fontWeight: FontWeight.w900)),
                                      Text("$pctA%", style: const TextStyle(color: Colors.amber, fontWeight: FontWeight.w900, fontSize: 18)),
                                      Text("B", style: TextStyle(color: Colors.pinkAccent.shade100, fontWeight: FontWeight.w900)),
                                      Text("$pctB%", style: const TextStyle(color: Colors.amber, fontWeight: FontWeight.w900, fontSize: 18)),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Text(majority, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900)),
                                  Text(minority, style: const TextStyle(color: Colors.white54, fontWeight: FontWeight.bold)),
                                ],
                              ),
                            ).animate().fadeIn().scale(),
                            const Spacer(),
                            Padding(
                              padding: const EdgeInsets.all(20),
                              child: ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.purpleAccent,
                                  minimumSize: const Size(double.infinity, 52),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                ),
                                onPressed: widget.isOnline
                                    ? (_isHost ? _nextQuestionOnline : null)
                                    : _pickNextLocal,
                                child: Text(
                                  widget.isOnline ? (_isHost ? "SUIVANTE ➔" : "ATTENDS LE CHEF…") : "QUESTION SUIVANTE ➔",
                                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                                ),
                              ),
                            ),
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