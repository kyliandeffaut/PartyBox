import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:convert';
import 'package:flutter_animate/flutter_animate.dart';
import 'live_chat_fab.dart';
import 'main.dart';

class GamePlayer {
  final String name;
  final String gender;
  GamePlayer({required this.name, required this.gender});
}

// --- L'ÉCRAN DE JEU HYBRIDE (Local & Online) ---
class ActionVeriteScreen extends StatefulWidget {
  final String category;
  final bool isOnline; 
  final String? lobbyId;
  final List<GamePlayer>? localPlayers;
  final String? currentPlayerName;
  final String? currentPlayerGender;
  
  const ActionVeriteScreen({
    super.key, 
    required this.category,
    required this.isOnline,
    this.lobbyId,
    this.localPlayers,
    this.currentPlayerName,
    this.currentPlayerGender,
  });

  @override
  State<ActionVeriteScreen> createState() => _ActionVeriteScreenState();
}

class _ActionVeriteScreenState extends State<ActionVeriteScreen> {
  List<dynamic> allQuestions = [];
  List<GamePlayer> players = [];
  
  // NOUVEAU : LES DEUX SACS DE PIOCHE SANS DOUBLON
  List<dynamic> _remainingActions = [];
  List<dynamic> _remainingVerites = [];
  
  // Variables locales (utilisées UNIQUEMENT si on joue hors-ligne sur 1 seul téléphone)
  int localCurrentPlayerIndex = 0;
  String localCurrentQuestion = "Appuie sur un bouton !";
  bool localShowNextButton = false;
  String _lastChoice = '';

  @override
  void initState() {
    super.initState();
    loadQuestions();
    
    if (widget.isOnline && widget.lobbyId != null) {
      fetchPlayersFromFirebase(); 
    } else {
      setState(() {
        players = widget.localPlayers ?? [];
      });
    }
  }

  Future<void> loadQuestions() async {
    final String response = await rootBundle.loadString('assets/action_verite.json');
    final data = await json.decode(response);
    setState(() { 
      allQuestions = data; 
      _refillBag('action'); // On remplit le sac d'actions
      _refillBag('verite'); // On remplit le sac de vérités
    });
  }

  // NOUVEAU : FONCTION POUR REMPLIR ET MÉLANGER UN SAC
  void _refillBag(String type) {
    var filtered = allQuestions.where((q) => q['type'] == type && q['category'] == widget.category).toList();
    if (filtered.isEmpty) { // Sécurité si la catégorie est vide
      filtered = allQuestions.where((q) => q['type'] == type).toList();
    }
    if (type == 'action') {
      _remainingActions = List.from(filtered)..shuffle();
    } else {
      _remainingVerites = List.from(filtered)..shuffle();
    }
  }

  Future<void> fetchPlayersFromFirebase() async {
    DocumentSnapshot doc = await FirebaseFirestore.instance.collection('lobbies').doc(widget.lobbyId).get();
    
    if (doc.exists) {
      var data = doc.data() as Map<String, dynamic>;
      List rawPlayers = data['players'] ?? [];
      
      setState(() {
        players = rawPlayers.map((p) => GamePlayer(
          name: p['name'], 
          gender: p['gender']
        )).toList();
      });
    }
  }

  void _updateGameState(String question, bool showNext, String choice) {
    if (widget.isOnline && widget.lobbyId != null) {
      FirebaseFirestore.instance.collection('lobbies').doc(widget.lobbyId).update({
        'currentQuestion': question,
        'showNextButton': showNext,
        'lastChoice': choice, 
      });
    } else {
      setState(() {
        localCurrentQuestion = question;
        localShowNextButton = showNext;
        _lastChoice = choice;
      });
    }
  }

  void _updateTurn(int currentIndex) {
    int nextIndex = (currentIndex + 1) % players.length;
    
    if (widget.isOnline && widget.lobbyId != null) {
      FirebaseFirestore.instance.collection('lobbies').doc(widget.lobbyId).update({
        'currentPlayerIndex': nextIndex,
        'currentQuestion': "Appuie sur un bouton !",
        'showNextButton': false,
        'lastChoice': '', 
      });
    } else {
      setState(() {
        localCurrentPlayerIndex = nextIndex;
        localCurrentQuestion = "Appuie sur un bouton !";
        localShowNextButton = false;
        _lastChoice = '';
      });
    }
  }

  void pickQuestion(String type, int cIndex) {
    setState(() {
      _lastChoice = type;
    });

    if (allQuestions.isEmpty || players.isEmpty) return;

    // NOUVEAU SYSTÈME ALÉATOIRE : On utilise le bon sac
    List<dynamic> currentBag = type == 'action' ? _remainingActions : _remainingVerites;
    
    // Si le sac est vide, on le remplit et on le remélange
    if (currentBag.isEmpty) {
      _refillBag(type);
      currentBag = type == 'action' ? _remainingActions : _remainingVerites;
    }
    
    if (currentBag.isEmpty) return; // Sécurité extrême

    var questionData = currentBag.removeLast(); // ON PIOCHE SANS REMISE !
    String text = questionData['text'];

    GamePlayer currentPlayer = players[cIndex];
    List<GamePlayer> potentialTargets = players.where((p) => p.name != currentPlayer.name).toList();

    bool hasMen = players.any((p) => p.gender == 'H');
    bool hasWomen = players.any((p) => p.gender == 'F');
    bool isMixedGroup = hasMen && hasWomen;

    if (isMixedGroup) {
      if (questionData['target'] == 'opposite') {
        potentialTargets = potentialTargets.where((p) => p.gender != currentPlayer.gender).toList();
      } else if (questionData['target'] == 'same') {
        potentialTargets = potentialTargets.where((p) => p.gender == currentPlayer.gender).toList();
      } else if (questionData['target'] == 'homme') {
        potentialTargets = potentialTargets.where((p) => p.gender == 'H').toList();
      } else if (questionData['target'] == 'femme') {
        potentialTargets = potentialTargets.where((p) => p.gender == 'F').toList();
      }
    }

    if (potentialTargets.isEmpty) {
      potentialTargets = List.from(players)..removeWhere((p) => p.name == currentPlayer.name);
    }
    
    if (potentialTargets.isNotEmpty) {
      potentialTargets.shuffle();
      GamePlayer target = potentialTargets[0];
      text = text.replaceAll("{target}", target.name);
    } else {
      text = text.replaceAll("{target}", "quelqu'un"); 
    }
    text = text.replaceAll("{player}", currentPlayer.name); 

    _updateGameState(text, true, type); 
  }

  Widget _buildExpandedContent(String typeTitle, int cIndex, String actualQuestion, bool isMyTurn, GamePlayer currentPlayer) {
    return Padding(
        padding: const EdgeInsets.only(top: 220.0, left: 30.0, right: 30.0, bottom: 30.0),      child: Column(
        children: [
          const SizedBox(height: 130),
          Text(typeTitle, style: const TextStyle(fontSize: 20, color: Colors.white54, fontWeight: FontWeight.bold, letterSpacing: 4)),
          const SizedBox(height: 30),
          Text(
            actualQuestion, 
            style: const TextStyle(fontSize: 28, color: Colors.white, fontWeight: FontWeight.w800, height: 1.3),
            textAlign: TextAlign.center,
          ),
          const Spacer(),
          isMyTurn 
            ? Listener(
                onPointerDown: (_) {
                  playPop(); // Le son se joue instantanément
                },
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: Colors.black,
                    minimumSize: const Size(double.infinity, 70),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                    elevation: 10,
                  ),
                  onPressed: () {
                    setState(() => _lastChoice = '');
                    _updateTurn(cIndex);
                  },
                  child: const Text("TOUR SUIVANT ➔", style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
                ),
              )
            : Text( 
                "Attends que ${currentPlayer.name} passe au tour suivant...",
                style: const TextStyle(color: Colors.white70, fontSize: 16, fontStyle: FontStyle.italic),
                textAlign: TextAlign.center,
              ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (players.isEmpty) {
      return const Scaffold(
        backgroundColor: Color(0xFF101012),
        body: Center(child: CircularProgressIndicator(color: Colors.pinkAccent)),
      );
    }

    if (widget.isOnline && widget.lobbyId != null) {
      return StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance.collection('lobbies').doc(widget.lobbyId).snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData || !snapshot.data!.exists) return const SizedBox();
          
          var data = snapshot.data!.data() as Map<String, dynamic>;
          
          List rawAllPlayers = data['players'] ?? [];
          bool stillInLobby = rawAllPlayers.any((p) => p['name'] == widget.currentPlayerName);
          
          if (!stillInLobby) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (context.mounted) Navigator.pop(context);
            });
            return const Scaffold(backgroundColor: Color(0xFF101012));
          }

          List rawActive = data['activePlayers'] ?? [];
          players = rawActive.map((p) => GamePlayer(name: p['name'], gender: p['gender'])).toList();

          if (players.isEmpty) {
            return const Scaffold(backgroundColor: Color(0xFF101012));
          }

          int cIndex = data['currentPlayerIndex'] ?? 0;
          String cQuestion = data['currentQuestion'] ?? "Appuie sur un bouton !";
          bool showNext = data['showNextButton'] ?? false;
          String cChoice = data['lastChoice'] ?? ''; 
          
          if (cIndex >= players.length) {
            cIndex = 0; 
          }

          return _buildGameUI(cIndex, cQuestion, showNext, cChoice);
        }
      );
    } 
    else {
      return _buildGameUI(localCurrentPlayerIndex, localCurrentQuestion, localShowNextButton, _lastChoice);
    }
  }

  Widget _buildGameUI(int cIndex, String cQuestion, bool showNext, String currentChoice) {
    GamePlayer currentPlayer = players[cIndex];

    bool isMyTurn = widget.isOnline 
        ? (widget.currentPlayerName == currentPlayer.name) 
        : true;

    final Color themeColor = widget.category == 'Hot' || widget.category == 'Extrême' || widget.category == 'Séduction'
      ? Colors.red.shade900
      : Colors.indigo.shade900;

    return PopScope(
      canPop: false, 
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;

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

        if (mounted) {
          Navigator.of(context).pop();
        }
      },
      child: Scaffold(
        extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: Listener(
          onPointerDown: (_) => playPop(),
          child: IconButton(
            icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
            onPressed: () async {
              if (widget.isOnline && widget.lobbyId != null) {
                final docRef = FirebaseFirestore.instance.collection('lobbies').doc(widget.lobbyId);
                final doc = await docRef.get();
                if (doc.exists) {
                  final data = doc.data() as Map<String, dynamic>;
                  final List activeP = List.from(data['activePlayers'] ?? []);
                  activeP.removeWhere((p) => p is Map && p['name'] == widget.currentPlayerName);
                  await docRef.update({
                    'activePlayers': activeP,
                    'lastAction': '${widget.currentPlayerName} est retourné au salon.'
                  });
                }
              }
              
              if (mounted) {
                Navigator.pop(context);
              }
            },
          ),
        )
      ),
      body: Stack(
        children: [
          (!isMyTurn && !showNext) 
              ? Container(
                  width: double.infinity,
                  height: double.infinity,
                  decoration: BoxDecoration(
                    gradient: RadialGradient(
                      center: const Alignment(-0.5, -0.6),
                      radius: 1.5,
                      colors: [themeColor.withValues(alpha: 0.8), const Color(0xFF101012)],
                    ),
                  ),
                  child: Center(
                    child: Text(
                      "Attends que ${currentPlayer.name} joue...",
                      style: const TextStyle(color: Colors.white54, fontSize: 18, fontStyle: FontStyle.italic),
                    ),
                  ),
                )
              : Row(
                  children: [
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 600),
                      curve: Curves.easeOutExpo,
                      width: showNext
                          ? (currentChoice == 'verite' ? MediaQuery.of(context).size.width : 0)
                          : MediaQuery.of(context).size.width / 2,
                      child: ClipRRect(
                        child: Material(
                          color: const Color.fromARGB(255, 28, 126, 36).withValues(alpha: 0.95),
                          child: InkWell(
                            onTapDown: (_) {
                              playPop(); 
                            },
                            onTap: showNext ? null : () => pickQuestion('verite', cIndex),
                            child: SizedBox(
                              height: double.infinity,
                              child: AnimatedSwitcher(
                                duration: const Duration(milliseconds: 400),
                                child: showNext && currentChoice == 'verite'
                                    ? _buildExpandedContent("VÉRITÉ", cIndex, cQuestion, isMyTurn, currentPlayer)
                                    : const Center(
                                        child: RotatedBox(
                                          quarterTurns: 3,
                                          child: Text("VÉRITÉ", style: TextStyle(fontSize: 45, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: 5)),
                                        ),
                                      ),
                              ),
                            ),
                          ),
                        ),
                      )
                      .animate(onPlay: (controller) => controller.repeat())
                      .shimmer(duration: 4.seconds, color: Colors.white.withValues(alpha: 0.30), angle: 30, delay: 1.seconds),
                    ),

                    AnimatedContainer(
                      duration: const Duration(milliseconds: 600),
                      curve: Curves.easeOutExpo,
                      width: showNext
                          ? (currentChoice == 'action' ? MediaQuery.of(context).size.width : 0)
                          : MediaQuery.of(context).size.width / 2,
                      child: ClipRRect(
                        child: Material(
                          color: const Color(0xFF6B1124).withValues(alpha: 0.95),
                          child: InkWell(
                            onTapDown: (_) {
                              playPop(); 
                            },
                            onTap: showNext ? null : () => pickQuestion('action', cIndex),
                            child: SizedBox(
                              height: double.infinity,
                              child: AnimatedSwitcher(
                                duration: const Duration(milliseconds: 400),
                                child: showNext && currentChoice == 'action'
                                    ? _buildExpandedContent("ACTION", cIndex, cQuestion, isMyTurn, currentPlayer)
                                    : const Center(
                                        child: RotatedBox(
                                          quarterTurns: 1,
                                          child: Text("ACTION", style: TextStyle(fontSize: 45, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: 5)),
                                        ),
                                      ),
                              ),
                            ),
                          ),
                        ),
                      )
                      .animate(onPlay: (controller) => controller.repeat())
                      .shimmer(duration: 4.seconds, color: Colors.white.withValues(alpha: 0.30), angle: 30, delay: 1.seconds),
                    ),
                  ],
                ),

          SafeArea(
            child: IgnorePointer(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: 20),
                    Center(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 5),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.3),
                          borderRadius: BorderRadius.circular(20)
                        ),
                        child: Text(
                          "Action ou Vérité • ${widget.category}",
                          style: const TextStyle(color: Colors.white70, fontSize: 12)
                        ),
                      ),
                    ),
                    const SizedBox(height: 30),
                    const Center(
                      child: Text("C'EST AU TOUR DE :", style: TextStyle(color: Colors.white54, letterSpacing: 2, fontWeight: FontWeight.bold))
                    ),
                    Center(
                      child: Text(
                        currentPlayer.name.toUpperCase(),
                        style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w900, color: Colors.white)
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (widget.isOnline && widget.lobbyId != null)
            LiveChatFAB(
              lobbyId: widget.lobbyId!,
              currentPlayerName: widget.currentPlayerName!,
            ),
        ],
      ),
    ),
    );
  }
}

// --- ÉCRAN 2 : SÉLECTION DES CATÉGORIES ---
class CategoryScreen extends StatelessWidget {
  final List<dynamic> players; 

  CategoryScreen({super.key, required this.players});

  final List<Map<String, dynamic>> categories = [
  {'name': 'Soft', 'color': const Color(0xFF4ADE80), 'emoji': '🍭'},
  {'name': 'Bar', 'color': const Color(0xFF8B5CF6), 'emoji': '🍻'},
  {'name': 'Sans Filtre', 'color': const Color(0xFFF59E0B), 'emoji': '🙊'},
  {'name': 'Séduction', 'color': const Color(0xFFF43F5E), 'emoji': '🫦'},
  {'name': 'Couple', 'color': const Color(0xFFEC4899), 'emoji': '💞'},
  {'name': 'Hot', 'color': const Color(0xFFE11D48), 'emoji': '🔥'},
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true, 
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        title: const Text(
          "CHOISIS UNE CATÉGORIE", 
          style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900, letterSpacing: 2)
        ),
        leading: Listener(
          onPointerDown: (_) => playPop(),
          child: IconButton(
            icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
            onPressed: () => Navigator.pop(context),
          ),
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
          ),
        ),
        child: SafeArea(
          child: GridView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 30),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2, 
              childAspectRatio: 1.2, 
              crossAxisSpacing: 20, 
              mainAxisSpacing: 20
            ),
            itemCount: categories.length,
            itemBuilder: (context, index) {
              final cat = categories[index];
              return InkWell(
                borderRadius: BorderRadius.circular(25),
                onTapDown: (_) {
                  playPop(); 
                },
                onTap: () {
                  List<GamePlayer> formattedPlayers = players.map((p) => GamePlayer(
                    name: p.name, 
                    gender: p.gender
                  )).toList();

                  Navigator.push(context, MaterialPageRoute(
                    builder: (context) => ActionVeriteScreen(
                      category: cat['name'], 
                      isOnline: false,       
                      localPlayers: formattedPlayers, 
                    ),
                  ));
                },
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        cat['color'].withValues(alpha: 0.3),
                        cat['color'].withValues(alpha: 0.05),
                      ],
                    ),
                    border: Border.all(color: cat['color'].withValues(alpha: 0.5), width: 1.5),
                    borderRadius: BorderRadius.circular(25),
                    boxShadow: [
                      BoxShadow(
                        color: cat['color'].withValues(alpha: 0.15),
                        blurRadius: 15,
                        spreadRadius: 2,
                        offset: const Offset(0, 5)
                      )
                    ]
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        cat['emoji'], 
                        style: const TextStyle(
                          fontSize: 40,
                          shadows: [Shadow(color: Colors.black45, blurRadius: 10, offset: Offset(2, 2))]
                        )
                      ),
                      const SizedBox(height: 12),
                      Text(
                        cat['name'], 
                        style: const TextStyle(
                          color: Colors.white, 
                          fontWeight: FontWeight.w800, 
                          fontSize: 16,
                          letterSpacing: 1
                        )
                      ),
                    ],
                  ),
                ),
              )
              .animate()
              .fade(duration: const Duration(milliseconds: 400))
              .scale(
                begin: const Offset(0.8, 0.8), 
                curve: Curves.easeOutBack, 
                delay: Duration(milliseconds: index * 50)
              );
            },
          ),
        ),
      ),
    );
  }
}