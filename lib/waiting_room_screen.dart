import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'action_verite_screen.dart';
import 'je_nai_jamais_screen.dart';
import 'tribunal_screen.dart';
import 'tu_prefere_screen.dart';
import 'main.dart';

class WaitingRoomScreen extends StatefulWidget {
  final String lobbyId;
  final String lobbyName;
  final String currentPlayerName; 
  final String currentPlayerGender;
  final bool isHost;
  final String password;

  const WaitingRoomScreen({
    super.key, 
    required this.lobbyId, 
    required this.lobbyName, 
    required this.currentPlayerName, 
    required this.currentPlayerGender, 
    required this.isHost, 
    required this.password
  });

  @override
  State<WaitingRoomScreen> createState() => _WaitingRoomScreenState();
}

class _WaitingRoomScreenState extends State<WaitingRoomScreen> {
  bool _isLeavingManually = false; 
  bool _isNavigatingToGame = false;

  Future<void> _leaveLobby() async {
    if (_isLeavingManually) return; 
    setState(() {
      _isLeavingManually = true;
    });

    try {
      final docRef = FirebaseFirestore.instance.collection('lobbies').doc(widget.lobbyId);
      final doc = await docRef.get();
      if (!doc.exists) return;

      var data = doc.data() as Map<String, dynamic>;
      List players = List.from(data['players'] ?? []);
      String currentHost = data['host'] ?? '';

      players.removeWhere((p) => p['name'] == widget.currentPlayerName);

      if (players.isEmpty) {
        await docRef.delete();
      } else {
        Map<String, dynamic> updates = {'players': players};
        if (widget.currentPlayerName == currentHost) {
          updates['host'] = players[0]['name']; 
        }
        await docRef.update(updates);
      }
    } catch (e) {
      debugPrint("Erreur sortie lobby : $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false, 
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return; 

        final bool shouldLeave = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            backgroundColor: const Color(0xFF1A1A1D),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: const Text('Quitter le lobby ?', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            content: const Text('Es-tu sûr de vouloir retourner à l\'accueil ?', style: TextStyle(color: Colors.white70)),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('ANNULER', style: TextStyle(color: Colors.white54)),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.pinkAccent,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: () => Navigator.pop(context, true),
                child: const Text('QUITTER', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ) ?? false;

        if (shouldLeave) {
          await _leaveLobby();
          if (context.mounted) {
            Navigator.of(context).pop(); 
          }
        }
      },
      child: Scaffold(
        extendBodyBehindAppBar: true,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
            onPressed: () => Navigator.maybePop(context), 
          ),
        ),
        body: Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: const Color(0xFF101012),
            image: DecorationImage(
              image: const AssetImage('assets/images/background.jpg'),
              fit: BoxFit.cover,
              colorFilter: ColorFilter.mode(Colors.black.withValues(alpha: 0.8), BlendMode.darken),
            ),
          ),
          child: SafeArea(
            child: Column(
              children: [
                const SizedBox(height: 20),
                Text(
                  widget.lobbyName,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 28, fontWeight: FontWeight.bold, color: Colors.white,
                    letterSpacing: 4, shadows: [Shadow(color: Colors.blueAccent, blurRadius: 20)],
                  ),
                ),
                StreamBuilder<DocumentSnapshot>(
                  stream: FirebaseFirestore.instance.collection('lobbies').doc(widget.lobbyId).snapshots(),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData || !snapshot.data!.exists) return const SizedBox();
                    
                    var data = snapshot.data!.data() as Map<String, dynamic>;
                    List activePlayers = data['activePlayers'] ?? [];
                    String status = data['status'] ?? 'waiting';

                    if (status == 'playing' && activePlayers.isEmpty) {
                      FirebaseFirestore.instance.collection('lobbies').doc(widget.lobbyId).update({'status': 'waiting'});
                    }

                    return Padding(
                      padding: const EdgeInsets.only(top: 15),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 8),
                        decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.lock_outline, color: Colors.white70, size: 16),
                            const SizedBox(width: 8),
                            Text("MDP : ${widget.password}", style: const TextStyle(color: Colors.white, fontSize: 14, letterSpacing: 1)),
                          ],
                        ),
                      ),
                    );
                  },
                ),

                const SizedBox(height: 40),
                const Text("Joueurs connectés :", style: TextStyle(color: Colors.white70)),
                const SizedBox(height: 20),

                Expanded(
                  child: StreamBuilder<DocumentSnapshot>(
                    stream: FirebaseFirestore.instance.collection('lobbies').doc(widget.lobbyId).snapshots(),
                    builder: (context, snapshot) {
                      if (snapshot.hasError) return const Center(child: Text("Erreur", style: TextStyle(color: Colors.white)));
                      if (!snapshot.hasData) return const Center(child: CircularProgressIndicator(color: Colors.pinkAccent));

                      var data = snapshot.data!.data() as Map<String, dynamic>?;
                      if (data == null) return const Center(child: Text("Introuvable", style: TextStyle(color: Colors.white)));

                      List players = data['players'] ?? [];
                      String hostName = data['host'] ?? '';

                      bool isMeStillHere = players.any((p) => p['name'] == widget.currentPlayerName);

                      if (!isMeStillHere && !_isLeavingManually && !_isNavigatingToGame) {
                        WidgetsBinding.instance.addPostFrameCallback((_) {
                          if (context.mounted) {
                            Navigator.of(context).pop(); 
                            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Le chef t'a expulsé ❌"), backgroundColor: Colors.redAccent));
                          }
                        });
                        return const Center(child: Text("Expulsion...", style: TextStyle(color: Colors.redAccent, fontSize: 18)));
                      }

                      bool amIActive = (data['activePlayers'] as List? ?? []).any((p) => p['name'] == widget.currentPlayerName);

                      if (data['status'] == 'playing' && amIActive) {
                        if (!_isNavigatingToGame) {
                          WidgetsBinding.instance.addPostFrameCallback((_) {
                            if (context.mounted) {
                              setState(() { _isNavigatingToGame = true; });

                              Widget targetScreen;
                              String gameMode = data['gameMode'] ?? 'Action ou Vérité';

                              if (gameMode == "Je n'ai jamais") {
                                targetScreen = JeNaiJamaisScreen(
                                  players: (data['players'] as List).map((p) => Player(name: p['name'], gender: p['gender'], score: p['score'] ?? 0)).toList(),
                                  isOnline: true,
                                  lobbyId: widget.lobbyId,
                                  currentPlayerName: widget.currentPlayerName,
                                );
                              } else if (gameMode == "Le Tribunal") {
                                targetScreen = TribunalScreen(
                                  players: (data['players'] as List).map((p) => Player(name: p['name'], gender: p['gender'], score: p['score'] ?? 0)).toList(),
                                  isOnline: true,
                                  lobbyId: widget.lobbyId,
                                  currentPlayerName: widget.currentPlayerName,
                                );
                              } else if (gameMode == "Tu préfères ?") {
                                targetScreen = TuPrefereScreen(
                                  players: (data['players'] as List).map((p) => Player(name: p['name'], gender: p['gender'], score: p['score'] ?? 0)).toList(),
                                  isOnline: true,
                                  lobbyId: widget.lobbyId,
                                  currentPlayerName: widget.currentPlayerName,
                                );
                              } else {
                                targetScreen = ActionVeriteScreen(
                                  lobbyId: widget.lobbyId,
                                  category: data['category'] ?? 'Soft',
                                  isOnline: true,
                                  currentPlayerName: widget.currentPlayerName,
                                  currentPlayerGender: widget.currentPlayerGender,
                                );
                              }

                              Navigator.push(context, MaterialPageRoute(builder: (context) => targetScreen)).then((_) {
                                if (context.mounted) setState(() { _isNavigatingToGame = false; });
                              });
                            }
                          });
                        }
                        return const Center(child: Text("Partie en cours...", style: TextStyle(color: Colors.pinkAccent)));
                      }

                      if (players.isEmpty) return const Center(child: Text("Attente...", style: TextStyle(color: Colors.white38, fontStyle: FontStyle.italic)));

                      return ListView.builder(
                        itemCount: players.length,
                        itemBuilder: (context, index) {
                          var player = players[index] as Map<String, dynamic>;
                          String name = player['name'] ?? "Anonyme";
                          String gender = player['gender'] ?? "H";

                          bool isMe = name == widget.currentPlayerName; 
                          bool isHost = name == hostName; 
                          bool amIHost = widget.currentPlayerName == hostName; 
                          
                          // ✅ LOGIQUE "EN JEU" OU "PRÊT"
                          bool gameIsActive = data['status'] == 'playing' || (data['activePlayers'] as List? ?? []).isNotEmpty;
                          bool isInGame = (data['activePlayers'] as List? ?? []).any((p) => p['name'] == name);

                          return Container(
                            margin: const EdgeInsets.symmetric(horizontal: 30, vertical: 8),
                            decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.05), borderRadius: BorderRadius.circular(15)),
                            child: ListTile(
                              leading: Icon(Icons.person, color: gender == 'H' ? Colors.blueAccent : Colors.pinkAccent),
                              title: Row(
                                children: [
                                  Text(name, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w500)),
                                  if (isHost) ...[const SizedBox(width: 8), const Icon(Icons.star, color: Colors.amber, size: 20)]
                                ],
                              ),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min, 
                                children: [
                                  if (gameIsActive && isInGame)
                                    const Text("En jeu 🎮", style: TextStyle(color: Colors.orangeAccent, fontSize: 12, fontWeight: FontWeight.bold))
                                  else
                                    const Icon(Icons.check_circle, color: Colors.greenAccent, size: 20),
                                    
                                  if (amIHost && !isMe) ...[
                                    const SizedBox(width: 5), 
                                    IconButton(
                                      icon: const Icon(Icons.close, color: Colors.redAccent),
                                      onPressed: () async {
                                        var doc = await FirebaseFirestore.instance.collection('lobbies').doc(widget.lobbyId).get();
                                        if (doc.exists) {
                                          List pList = List.from(doc.data()?['players'] ?? []);
                                          pList.removeWhere((p) => p['name'] == name);
                                          List aList = List.from(doc.data()?['activePlayers'] ?? []);
                                          aList.removeWhere((p) => p['name'] == name);
                                          await doc.reference.update({'players': pList, 'activePlayers': aList});
                                        }
                                      },
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ).animate().fadeIn(delay: (index * 100).ms).slideX(begin: 0.2);
                        },
                      );
                    },
                  ),
                ),

                StreamBuilder<DocumentSnapshot>(
                  stream: FirebaseFirestore.instance.collection('lobbies').doc(widget.lobbyId).snapshots(),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData || !snapshot.data!.exists) return const SizedBox();
                    var data = snapshot.data!.data() as Map<String, dynamic>;
                    bool amITheHost = widget.currentPlayerName == (data['host'] ?? '');

                    if (amITheHost) {
                      final List activePlayers = (data['activePlayers'] as List?) ?? [];
                      final bool someoneStillInGame = activePlayers.isNotEmpty;
                      return Padding(
                        padding: const EdgeInsets.all(30.0),
                        child: Column(
                          children: [
                            ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: someoneStillInGame ? Colors.grey : Colors.greenAccent,
                                minimumSize: const Size(double.infinity, 60),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                              ),
                              onPressed: someoneStillInGame
                                  ? () {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(
                                          content: Text("Attends que tout le monde revienne au lobby avant de relancer ✅"),
                                          backgroundColor: Colors.orangeAccent,
                                        ),
                                      );
                                    }
                                  : () async {
                                final docRef = FirebaseFirestore.instance.collection('lobbies').doc(widget.lobbyId);
                                final doc = await docRef.get();
                                var currentData = doc.data() as Map<String, dynamic>;
                                List allPlayers = currentData['players'] ?? [];
                                
                                // ✅ RESET PARFAIT DE LA PARTIE (Pour ne plus retomber sur l'ancienne)
                                List updatedPlayers = allPlayers.map((p) {
                                  var newP = Map<String, dynamic>.from(p);
                                  newP['hasVoted'] = false;
                                  newP['lastVote'] = null;
                                  newP['score'] = 0;
                                  newP['voteTarget'] = null;
                                  newP['tpChoice'] = null;
                                  return newP;
                                }).toList();

                                await docRef.update({
                                  'status': 'playing',
                                  'activePlayers': updatedPlayers,
                                  'players': updatedPlayers,
                                  'jnjGameEnded': false,
                                  'currentQuestion': null, // Force une nouvelle pioche
                                  'lastChoice': null,
                                  'showNextButton': false,
                                  'currentPlayerIndex': 0,
                                });
                              },
                              child: Text(
                                someoneStillInGame ? "JOUEURS ENCORE EN JEU..." : "LANCER LA PARTIE",
                                style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 18),
                              ),
                            ),
                            const SizedBox(height: 15),
                            OutlinedButton(
                              style: OutlinedButton.styleFrom(side: const BorderSide(color: Colors.white24), minimumSize: const Size(double.infinity, 50), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))),
                              onPressed: () {
                                showModalBottomSheet(
                                  context: context,
                                  backgroundColor: const Color(0xFF1A1A1D),
                                  shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(25))),
                                  builder: (BuildContext context) {
                                    List<String> gameModes = [
                                      'Action ou Vérité',
                                      'Je n\'ai jamais',
                                      'Le Tribunal',
                                      'Tu préfères ?',
                                    ];
                                    return Padding(
                                      padding: const EdgeInsets.symmetric(vertical: 20),
                                      child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          const Text("CHOISIS UN JEU", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold, letterSpacing: 2)),
                                          const SizedBox(height: 15),
                                          ...gameModes.map((mode) {
                                            bool isSelected = data['gameMode'] == mode;
                                            return ListTile(
                                              contentPadding: const EdgeInsets.symmetric(horizontal: 30),
                                              title: Text(mode, style: TextStyle(color: isSelected ? Colors.pinkAccent : Colors.white70, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal, fontSize: 16)),
                                              trailing: isSelected ? const Icon(Icons.check_circle, color: Colors.pinkAccent) : null,
                                              onTap: () {
                                                FirebaseFirestore.instance.collection('lobbies').doc(widget.lobbyId).update({'gameMode': mode});
                                                Navigator.pop(context);
                                              },
                                            );
                                          }),
                                        ],
                                      ),
                                    );
                                  },
                                );
                              },
                              child: Text("JEUX : ${data['gameMode'] ?? 'Action ou Vérité'}", style: const TextStyle(color: Colors.white70, fontSize: 14)),
                            ),
                            const SizedBox(height: 15),
                            OutlinedButton(
                              style: OutlinedButton.styleFrom(side: const BorderSide(color: Colors.white24), minimumSize: const Size(double.infinity, 50), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))),
                              onPressed: () {
                                showModalBottomSheet(
                                  context: context,
                                  backgroundColor: const Color(0xFF1A1A1D),
                                  shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(25))),
                                  builder: (context) => _buildParamsSheet(data),
                                );
                              },
                              child: const Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.settings, color: Colors.white70, size: 18),
                                  SizedBox(width: 8),
                                  Text("PARAMÈTRES DU JEU", style: TextStyle(color: Colors.white70, fontSize: 14)),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    } 
                    else {
                      return Padding(
                        padding: const EdgeInsets.all(30.0),
                        child: Column(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(15),
                              decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.05), borderRadius: BorderRadius.circular(15)),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(Icons.gamepad, color: Colors.pinkAccent, size: 20),
                                  const SizedBox(width: 10),
                                  Text("JEUX PRÉVU : ${data['gameMode'] ?? 'Action ou Vérité'}", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w500)),
                                ],
                              ),
                            ),
                            const SizedBox(height: 15),
                            const Center(child: Text("En attente du chef...", style: TextStyle(color: Colors.white38, fontSize: 12, fontStyle: FontStyle.italic))),
                          ],
                        ),
                      );
                    }
                  },
                ),
              ],
            ),
          ),
        ),
      )
    );
  }

  Widget _buildParamsSheet(Map<String, dynamic> data) {
    String mode = data['gameMode'] ?? 'Action ou Vérité';
    String currentCategory = data['category'] ?? 'Soft'; // ✅ On récupère la catégorie en cours
    
    bool isSecret = (data['jnjVisibility'] ?? 'visible') == 'invisible'; 

    final List<Map<String, dynamic>> actionCats = [
      {'n': 'Soft', 'e': '🍭'},{'n': 'Bar', 'e': '🍻'}, {'n': 'Sans Filtre', 'e': '🙊'}, {'n': 'Séduction', 'e': '🫦'},
      {'n': 'Couple', 'e': '💞'}, {'n': 'Hot', 'e': '🔥'},
    ];
    final List<Map<String, dynamic>> jnjCats = [
      {'n': 'Soft', 'e': '😇'}, {'n': 'Interdit', 'e': '🚫'}, {'n': '+18', 'e': '🌶️'}, 
    ];
    final bool hasCategories = mode == 'Action ou Vérité' || mode == "Je n'ai jamais";
    final cats = mode == 'Action ou Vérité' ? actionCats : jnjCats;

    return StatefulBuilder(
      builder: (BuildContext context, StateSetter setModalState) {
        return Container(
          padding: const EdgeInsets.all(25),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text("PARAMÈTRES : ${mode.toUpperCase()}", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
                const SizedBox(height: 20),

                if (mode == "Je n'ai jamais") ...[
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(15),
                      border: Border.all(color: Colors.white10),
                    ),
                    child: SwitchListTile(
                      title: const Text("Mode Secret 🤫", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                      subtitle: const Text("Cache les scores et les réponses jusqu'à la fin", style: TextStyle(color: Colors.white54, fontSize: 12)),
                      value: isSecret,
                      activeColor: Colors.purpleAccent,
                      inactiveThumbColor: Colors.grey,
                      inactiveTrackColor: Colors.white12,
                      onChanged: (val) {
                        setModalState(() => isSecret = val);
                        FirebaseFirestore.instance.collection('lobbies').doc(widget.lobbyId).update({
                          'jnjVisibility': val ? 'invisible' : 'visible'
                        });
                      },
                    ),
                  ),
                  const SizedBox(height: 20),
                ],

                if (hasCategories) ...[
                  const Text("CHOISIR L'INTENSITÉ :", style: TextStyle(color: Colors.white70, fontSize: 14)),
                  const SizedBox(height: 10),
                  ...cats.map((c) {
                    bool isSelected = c['n'] == currentCategory;
                    return ListTile(
                      leading: Text(c['e'], style: const TextStyle(fontSize: 24)),
                      title: Text(c['n'], style: TextStyle(color: isSelected ? Colors.pinkAccent : Colors.white, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)),
                      trailing: isSelected ? const Icon(Icons.check_circle, color: Colors.pinkAccent) : null, // AFFICHE LA COCHE ROSE
                      onTap: () {
                        FirebaseFirestore.instance.collection('lobbies').doc(widget.lobbyId).update({'category': c['n']});
                        Navigator.pop(context);
                      },
                    );
                  }),
                ] else ...[
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(15),
                      border: Border.all(color: Colors.white10),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.info_outline, color: Colors.white54),
                        SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            "Aucun paramètre pour ce mode.",
                            style: TextStyle(color: Colors.white70, fontWeight: FontWeight.w600),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      }
    );
  }
}