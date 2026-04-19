import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_animate/flutter_animate.dart';

class WaitingRoomScreen extends StatelessWidget {
  final String lobbyId;
  final String lobbyName;

  const WaitingRoomScreen({super.key, required this.lobbyId, required this.lobbyName});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
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
                    if (snapshot.hasError) return const Center(child: Text("Erreur de connexion"));
                    if (!snapshot.hasData) return const Center(child: CircularProgressIndicator(color: Colors.pinkAccent));
                    
                    var data = snapshot.data!.data() as Map<String, dynamic>?;
                    if (data == null) return const Center(child: Text("Lobby introuvable"));
                    
                    List players = data['players'] ?? [];

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
                            title: Text(
                              name, 
                              style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w500)
                            ),
                            trailing: const Icon(Icons.check_circle, color: Colors.greenAccent, size: 20),
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
    );
  }
}