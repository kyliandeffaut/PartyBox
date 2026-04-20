import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'action_verite_screen.dart';

// 1. C'EST MAINTENANT UN STATEFUL WIDGET
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
  // 2. LE BOUCLIER ANTI-BUG EST ICI
  bool _isLeavingManually = false; 

  Future<void> _leaveLobby() async {
    setState(() {
      _isLeavingManually = true;
    });

    final docRef = FirebaseFirestore.instance.collection('lobbies').doc(widget.lobbyId);
    
    // 1. On récupère les données actuelles du lobby avant de partir
    final doc = await docRef.get();
    if (!doc.exists) return;

    List players = List.from(doc.data()?['players'] ?? []);
    String currentHost = doc.data()?['host'] ?? '';

    // 2. On retire le joueur actuel de la liste locale
    players.removeWhere((p) => p['name'] == widget.currentPlayerName);

    if (players.isEmpty) {
      // S'il n'y a plus personne, on supprime carrément le lobby
      await docRef.delete();
    } else {
      Map<String, dynamic> updates = {
        'players': players,
      };

      // 3. LA SUCCESSION : Si je suis le chef, je donne ma couronne au 1er de la liste restante
      if (widget.currentPlayerName == currentHost) {
        updates['host'] = players[0]['name']; 
      }

      await docRef.update(updates);
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
          _leaveLobby(); 
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
              colorFilter: ColorFilter.mode(
                Colors.black.withValues(alpha: 0.8), 
                BlendMode.darken
              ),
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
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    letterSpacing: 4,
                    shadows: [Shadow(color: Colors.blueAccent, blurRadius: 20)],
                  ),
                ),
                // Le mot de passe écoute Firebase en direct pour s'afficher si on DEVIENT chef !
                StreamBuilder<DocumentSnapshot>(
                  stream: FirebaseFirestore.instance.collection('lobbies').doc(widget.lobbyId).snapshots(),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData || !snapshot.data!.exists) return const SizedBox();
                    
                    var data = snapshot.data!.data() as Map<String, dynamic>;
                    bool amITheHost = widget.currentPlayerName == (data['host'] ?? '');

                    // Si je suis le chef actuellement dans la base de données, j'affiche le MDP
                    if (amITheHost) {
                      return Padding(
                        padding: const EdgeInsets.only(top: 15),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 8),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.1), 
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.lock_outline, color: Colors.white70, size: 16),
                              const SizedBox(width: 8),
                              Text(
                                "MDP : ${widget.password}",
                                style: const TextStyle(color: Colors.white, fontSize: 14, letterSpacing: 1),
                              ),
                            ],
                          ),
                        ),
                      );
                    }
                    
                    // Si je ne suis pas le chef, je n'affiche rien (une boite vide invisible)
                    return const SizedBox(); 
                  },
                ),

                const SizedBox(height: 40),
                const Text("Joueurs connectés :", style: TextStyle(color: Colors.white70)),
                const SizedBox(height: 20),

                Expanded(
                  child: StreamBuilder<DocumentSnapshot>(
                    stream: FirebaseFirestore.instance.collection('lobbies').doc(widget.lobbyId).snapshots(),
                    builder: (context, snapshot) {
                      if (snapshot.hasError) return const Center(child: Text("Erreur de connexion", style: TextStyle(color: Colors.white)));
                      if (!snapshot.hasData) return const Center(child: CircularProgressIndicator(color: Colors.pinkAccent));

                      var data = snapshot.data!.data() as Map<String, dynamic>?;
                      if (data == null) return const Center(child: Text("Lobby introuvable", style: TextStyle(color: Colors.white)));

                      List players = data['players'] ?? [];
                      String hostName = data['host'] ?? '';

                      bool isMeStillHere = players.any((p) => p['name'] == widget.currentPlayerName);

                      // 🔥 3. ON UTILISE LE BOUCLIER ICI !
                      // Si je n'y suis plus ET que ce n'est pas moi qui suis parti...
                      if (!isMeStillHere && !_isLeavingManually) {
                        WidgetsBinding.instance.addPostFrameCallback((_) {
                          if (context.mounted) {
                            Navigator.of(context).pop(); 
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text("Le chef du lobby t'a expulsé ❌", style: TextStyle(color: Colors.white)),
                                backgroundColor: Colors.redAccent,
                              ),
                            );
                          }
                        });
                        return const Center(child: Text("Expulsion en cours...", style: TextStyle(color: Colors.redAccent, fontSize: 18)));
                      }

                      if (data['status'] == 'playing') {
                        WidgetsBinding.instance.addPostFrameCallback((_) {
                          if (context.mounted) {
                            Navigator.pushReplacement(
                              context,
                              MaterialPageRoute(
                                builder: (context) => ActionVeriteScreen(
                                  lobbyId: widget.lobbyId,
                                  category: data['category'] ?? 'Soft', 
                                  isOnline: true,
                                  currentPlayerName: widget.currentPlayerName,
                                ),
                              ),
                            );
                          }
                        });
                        return const Center(child: CircularProgressIndicator(color: Colors.greenAccent));
                      }

                      if (players.isEmpty) {
                        return const Center(
                          child: Text("En attente de joueurs...", style: TextStyle(color: Colors.white38, fontStyle: FontStyle.italic))
                        );
                      }

                      return ListView.builder(
                        itemCount: players.length,
                        itemBuilder: (context, index) {
                          var player = players[index] as Map<String, dynamic>;
                          String name = player['name'] ?? "Anonyme";
                          String gender = player['gender'] ?? "H";

                          bool isMe = name == widget.currentPlayerName; 
                          bool isHost = name == hostName; 
                          bool amIHost = widget.currentPlayerName == hostName; 

                          return Container(
                            margin: const EdgeInsets.symmetric(horizontal: 30, vertical: 8),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.05),
                              borderRadius: BorderRadius.circular(15),
                            ),
                            child: ListTile(
                              leading: Icon(
                                Icons.person, 
                                color: gender == 'H' ? Colors.blueAccent : Colors.pinkAccent 
                              ),
                              title: Row(
                                children: [
                                  Text(
                                    name, 
                                    style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w500)
                                  ),
                                  if (isHost) ...[
                                    const SizedBox(width: 8),
                                    const Icon(Icons.star, color: Colors.amber, size: 20), 
                                  ]
                                ],
                              ),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min, 
                                children: [
                                  const Icon(Icons.check_circle, color: Colors.greenAccent, size: 20),
                                  if (amIHost && !isMe) ...[
                                    const SizedBox(width: 5), 
                                    IconButton(
                                      icon: const Icon(Icons.close, color: Colors.redAccent),
                                      onPressed: () {
                                        FirebaseFirestore.instance.collection('lobbies').doc(widget.lobbyId).update({
                                          'players': FieldValue.arrayRemove([
                                            {'name': name, 'gender': gender}
                                          ])
                                        });
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

                    if (widget.isHost) {
                      return Padding(
                        padding: const EdgeInsets.all(30.0),
                        child: Column(
                          children: [
                            ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.greenAccent,
                                minimumSize: const Size(double.infinity, 60),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                              ),
                              onPressed: () async {
                                await FirebaseFirestore.instance.collection('lobbies').doc(widget.lobbyId).update({
                                  'status': 'playing'
                                });
                                
                                if (context.mounted) {
                                  Navigator.pushReplacement(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => ActionVeriteScreen(
                                        lobbyId: widget.lobbyId,
                                        category: data['category'] ?? 'Soft', 
                                        isOnline: true,
                                        currentPlayerName: widget.currentPlayerName,
                                      ),
                                    ),
                                  );
                                }
                              },
                              child: const Text("LANCER LA PARTIE", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 18)),
                            ),
                            
                            const SizedBox(height: 15),
                            
                            OutlinedButton(
                              style: OutlinedButton.styleFrom(
                                side: const BorderSide(color: Colors.white24),
                                minimumSize: const Size(double.infinity, 50),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                              ),
                              onPressed: () {
                                showModalBottomSheet(
                                  context: context,
                                  backgroundColor: const Color(0xFF1A1A1D),
                                  shape: const RoundedRectangleBorder(
                                    borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
                                  ),
                                  builder: (BuildContext context) {
                                    List<String> gameModes = ['Action ou Vérité', 'Je n\'ai jamais'];
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
                                          const SizedBox(height: 10),
                                        ],
                                      ),
                                    );
                                  },
                                );
                              },
                              child: Text("MODE : ${data['gameMode'] ?? 'Action ou Vérité'}", style: const TextStyle(color: Colors.white70, fontSize: 14)),
                            ),

                            const SizedBox(height: 15),

                            OutlinedButton(
                              style: OutlinedButton.styleFrom(
                                side: const BorderSide(color: Colors.white24),
                                minimumSize: const Size(double.infinity, 50),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                              ),
                              onPressed: () {
                                showModalBottomSheet(
                                  context: context,
                                  backgroundColor: const Color(0xFF1A1A1D),
                                  isScrollControlled: true,
                                  shape: const RoundedRectangleBorder(
                                    borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
                                  ),
                                  builder: (BuildContext context) {
                                    return StreamBuilder<DocumentSnapshot>(
                                      stream: FirebaseFirestore.instance.collection('lobbies').doc(widget.lobbyId).snapshots(),
                                      builder: (context, snapshot) {
                                        if (!snapshot.hasData || !snapshot.data!.exists) return const SizedBox();
                                        var sheetData = snapshot.data!.data() as Map<String, dynamic>;
                                        
                                        String currentMode = sheetData['gameMode'] ?? 'Action ou Vérité';
                                        String currentCategory = sheetData['category'] ?? 'Soft';

                                        final List<Map<String, dynamic>> fullCategories = [
                                          {'name': 'Soft', 'color': const Color(0xFF4ADE80), 'emoji': '🍭'},
                                          {'name': 'Famille', 'color': const Color(0xFF2DD4BF), 'emoji': '🏠'},
                                          {'name': 'Dehors', 'color': const Color(0xFF3B82F6), 'emoji': '🌳'},
                                          {'name': 'Bar', 'color': const Color(0xFF8B5CF6), 'emoji': '🍻'},
                                          {'name': 'Sans Filtre', 'color': const Color(0xFFF59E0B), 'emoji': '🙊'},
                                          {'name': 'Séduction', 'color': const Color(0xFFF43F5E), 'emoji': '🫦'},
                                          {'name': 'Couple', 'color': const Color(0xFFEC4899), 'emoji': '💞'},
                                          {'name': 'Hot', 'color': const Color(0xFFE11D48), 'emoji': '🔥'},
                                        ];

                                        return Padding(
                                          padding: const EdgeInsets.all(25.0),
                                          child: Column(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Text("PARAMÈTRES : ${currentMode.toUpperCase()}", style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 1), textAlign: TextAlign.center),
                                              const SizedBox(height: 25),
                                              
                                              if (currentMode == 'Action ou Vérité') ...[
                                                const Text("Choisis l'intensité :", style: TextStyle(color: Colors.white70, fontSize: 14)),
                                                const SizedBox(height: 15),
                                                Wrap(
                                                  spacing: 8,
                                                  runSpacing: 8,
                                                  alignment: WrapAlignment.center,
                                                  children: fullCategories.map((cat) {
                                                    bool isSelected = currentCategory == cat['name'];
                                                    return ChoiceChip(
                                                      label: Text("${cat['emoji']} ${cat['name']}", style: TextStyle(color: isSelected ? Colors.white : Colors.white70, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)),
                                                      selected: isSelected,
                                                      selectedColor: cat['color'], 
                                                      backgroundColor: Colors.white.withValues(alpha: 0.1),
                                                      side: BorderSide.none,
                                                      onSelected: (bool selected) {
                                                        FirebaseFirestore.instance.collection('lobbies').doc(widget.lobbyId).update({'category': cat['name']});
                                                      },
                                                    );
                                                  }).toList(),
                                                ),
                                              ] else ...[
                                                const Icon(Icons.construction, color: Colors.pinkAccent, size: 40),
                                                const SizedBox(height: 15),
                                                const Text("Paramètres à venir pour ce mode.", style: TextStyle(color: Colors.white70)),
                                              ],
                                              
                                              const SizedBox(height: 30),
                                              ElevatedButton(
                                                style: ElevatedButton.styleFrom(
                                                  backgroundColor: Colors.pinkAccent,
                                                  minimumSize: const Size(double.infinity, 50),
                                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                                                ),
                                                onPressed: () => Navigator.pop(context),
                                                child: const Text("VALIDER", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                                              ),
                                            ],
                                          ),
                                        );
                                      }
                                    );
                                  },
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
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.05),
                                borderRadius: BorderRadius.circular(15),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(Icons.gamepad, color: Colors.pinkAccent, size: 20),
                                  const SizedBox(width: 10),
                                  Text(
                                    "MODE PRÉVU : ${data['gameMode'] ?? 'Action ou Vérité'}",
                                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w500),
                                  ),
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
}