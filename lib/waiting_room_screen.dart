import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_animate/flutter_animate.dart';

class WaitingRoomScreen extends StatelessWidget {
  final String lobbyId;
  final String lobbyName;
  final String currentPlayerName; 
  final String currentPlayerGender;

  const WaitingRoomScreen({super.key, required this.lobbyId, required this.lobbyName, required this.currentPlayerName, required this.currentPlayerGender});

  void _leaveLobby() {
    FirebaseFirestore.instance.collection('lobbies').doc(lobbyId).update({
      'players': FieldValue.arrayRemove([
        {'name': currentPlayerName, 'gender': currentPlayerGender}
      ])
    });
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false, // 1. On bloque la sortie immédiate pour TOUT le monde
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return; // Sécurité si l'écran est déjà fermé

        // 2. Le dialogue qui s'ouvre peu importe comment on a essayé de quitter
        final bool shouldLeave = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            backgroundColor: const Color(0xFF1A1A1D),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: const Text('Quitter le lobby ?', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            content: const Text('Es-tu sûr de vouloir retourner à l\'accueil ?', style: TextStyle(color: Colors.white70)),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false), // Annule
                child: const Text('ANNULER', style: TextStyle(color: Colors.white54)),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.pinkAccent,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: () => Navigator.pop(context, true), // Confirme
                child: const Text('QUITTER', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ) ?? false;

        // 3. Si le joueur a confirmé, on quitte et on nettoie
        if (shouldLeave) {
          _leaveLobby(); 
          if (context.mounted) {
            Navigator.of(context).pop(); // Ici on force la sortie car il a dit OUI
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
                const SizedBox(height: 30),
                // NOM DU LOBBY EN NÉON
                Text(
                  lobbyName,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    letterSpacing: 4,
                    shadows: [Shadow(color: Colors.blueAccent, blurRadius: 20)],
                  ),
                ),
                const Text(
                  "SALLE D'ATTENTE", 
                  style: TextStyle(color: Colors.pinkAccent, fontWeight: FontWeight.bold, letterSpacing: 2)
                ),
              
                const SizedBox(height: 50),
                
                const Text("Joueurs connectés :", style: TextStyle(color: Colors.white70)),
                
                const SizedBox(height: 20),

                // LISTE DES JOUEURS EN TEMPS RÉEL (Grâce au StreamBuilder)
                Expanded(
                  child: StreamBuilder<DocumentSnapshot>(
                    stream: FirebaseFirestore.instance.collection('lobbies').doc(lobbyId).snapshots(),
                    builder: (context, snapshot) {
                      if (snapshot.hasError) return const Center(child: Text("Erreur de connexion", style: TextStyle(color: Colors.white)));
                      if (!snapshot.hasData) return const Center(child: CircularProgressIndicator(color: Colors.pinkAccent));

                      var data = snapshot.data!.data() as Map<String, dynamic>?;
                      if (data == null) return const Center(child: Text("Lobby introuvable", style: TextStyle(color: Colors.white)));

                      List players = data['players'] ?? [];
                      String hostName = data['host'] ?? '';

                      // 🔥 3. LA VÉRIFICATION MAGIQUE : Est-ce que je suis toujours dans la liste ?
                      bool isMeStillHere = players.any((p) => p['name'] == currentPlayerName);

                      if (!isMeStillHere) {
                        // Si je n'y suis plus, on me vire de l'écran !
                        WidgetsBinding.instance.addPostFrameCallback((_) {
                          if (context.mounted) {
                            Navigator.of(context).pop(); // Retour à l'accueil
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

                      if (players.isEmpty) {
                        return const Center(
                          child: Text("En attente de joueurs...", style: TextStyle(color: Colors.white38, fontStyle: FontStyle.italic))
                        );
                      }

                      return ListView.builder(
                        itemCount: players.length,
                        itemBuilder: (context, index) {
                          // On transforme l'élément en Map pour lire le nom et le genre
                          var player = players[index] as Map<String, dynamic>;
                          String name = player['name'] ?? "Anonyme";
                          String gender = player['gender'] ?? "H";

                          bool isMe = name == currentPlayerName; // Est-ce que c'est moi ?
                          bool isHost = name == hostName; // Est-ce que ce joueur est le chef ?
                          bool amIHost = currentPlayerName == hostName; // Est-ce que MOI je suis le chef ?

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
                                    // L'icône étoile/couronne dorée !
                                    const Icon(Icons.star, color: Colors.amber, size: 20), 
                                  ]
                                ],
                              ),
                              // 4. L'affichage des statuts à droite
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min, // Très important pour ne pas casser l'affichage
                                children: [
                                  // Tout le monde a le check vert (pour dire qu'ils sont "Prêts/Connectés")
                                  const Icon(Icons.check_circle, color: Colors.greenAccent, size: 20),
                                  
                                  // Si je suis le CHEF ET que ce joueur n'est PAS moi, j'ajoute la croix rouge
                                  if (amIHost && !isMe) ...[
                                    const SizedBox(width: 5), // Petit espace entre le check et la croix
                                    IconButton(
                                      icon: const Icon(Icons.close, color: Colors.redAccent),
                                      onPressed: () {
                                        // Logique d'expulsion
                                        FirebaseFirestore.instance.collection('lobbies').doc(lobbyId).update({
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

                // BOUTON POUR LANCER (Seulement pour le créateur)
                Padding(
                  padding: const EdgeInsets.all(30.0),
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.greenAccent,
                      minimumSize: const Size(double.infinity, 60),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                    ),
                    onPressed: () {
                      // On gérera le lancement de la partie juste après !
                    },
                    child: const Text(
                      "LANCER LA PARTIE", 
                      style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 18)
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      )
    );
  }
}