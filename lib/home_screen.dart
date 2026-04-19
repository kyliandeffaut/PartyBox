import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'main.dart'; // Pour pouvoir accéder à PlayerScreen()
import 'package:cloud_firestore/cloud_firestore.dart';
import 'waiting_room_screen.dart';

// --- ÉCRAN D'ACCUEIL PRINCIPAL ---
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

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
              Colors.black.withValues(alpha: 0.6), // Assombrit un peu pour bien voir les boutons
              BlendMode.darken,
            ),
          ),
        ),
        child: SafeArea(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // LE TITRE DU JEU
              const Text(
                "PARTYBOX",
                style: TextStyle(
                  fontSize: 45,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                  letterSpacing: 8,
                  shadows: [
                    Shadow(color: Colors.pinkAccent, blurRadius: 20),
                    Shadow(color: Colors.blueAccent, blurRadius: 40),
                  ],
                ),
              )
              .animate(onPlay: (controller) => controller.repeat(reverse: true))
              .scaleXY(end: 1.15, duration: 2.seconds)
              .shimmer(duration: 2.seconds, color: Colors.white.withValues(alpha: 0.5)),

              const SizedBox(height: 80),

              // BOUTON : CRÉER UN LOBBY
              _mainButton(context, "CRÉER UN LOBBY", Icons.add_moderator, Colors.pinkAccent, () {
                Navigator.push(context, MaterialPageRoute(builder: (context) => const CreateLobbyScreen()));
              }),

              const SizedBox(height: 20),

              // BOUTON : REJOINDRE UN LOBBY
              _mainButton(context, "REJOINDRE UN LOBBY", Icons.login, Colors.blueAccent, () {
                Navigator.push(context, MaterialPageRoute(builder: (context) => const JoinLobbyScreen()));
              }),

              const SizedBox(height: 50),
              const Divider(color: Colors.white24, indent: 50, endIndent: 50),
              const SizedBox(height: 30),

              // BOUTON : JOUER EN LOCAL (Ramène vers l'ancien écran)
              _mainButton(context, "JOUER EN LOCAL", Icons.phone_android, Colors.greenAccent, () {
                Navigator.push(context, MaterialPageRoute(builder: (context) => const PlayerScreen()));
              }),
            ],
          ),
        ),
      ),
    );
  }

  // Design générique pour les 3 gros boutons de l'accueil
  Widget _mainButton(BuildContext context, String text, IconData icon, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: MediaQuery.of(context).size.width * 0.8,
        height: 65,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withValues(alpha: 0.5), width: 2),
          boxShadow: [
            BoxShadow(color: color.withValues(alpha: 0.2), blurRadius: 15)
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(width: 15),
            Text(text, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
          ],
        ),
      ).animate().fade(duration: 600.ms).slideY(begin: 0.3, curve: Curves.easeOut),
    );
  }
}

// --- ÉCRAN : CRÉER UN LOBBY ---
class CreateLobbyScreen extends StatefulWidget {
  const CreateLobbyScreen({super.key});

  @override
  State<CreateLobbyScreen> createState() => _CreateLobbyScreenState();
}

class _CreateLobbyScreenState extends State<CreateLobbyScreen> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _isLoading = false;

  // FONCTION MAGIQUE : CRÉER LE LOBBY DANS LE CLOUD
  Future<void> _createLobby() async {
    String name = _nameController.text.trim();
    String password = _passwordController.text.trim();

    var existingLobby = await FirebaseFirestore.instance
      .collection('lobbies')
      .where('lobbyName', isEqualTo: name)
      .where('status', isEqualTo: 'waiting') // On ne cherche que les lobbys actifs
      .get();

    if (existingLobby.docs.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Ce nom de lobby est déjà utilisé !")),
      );
      return;
    }

    if (name.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Remplis tous les champs !")),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      DocumentReference lobbyRef = await FirebaseFirestore.instance.collection('lobbies').add({
        'lobbyName': name,
        'password': password,
        'createdAt': FieldValue.serverTimestamp(),
        'players': [], 
        'status': 'waiting',
      });

      debugPrint("Lobby créé avec l'ID : ${lobbyRef.id}");

      if (!mounted) return; // Sécurité

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => WaitingRoomScreen(
            lobbyId: lobbyRef.id,
            lobbyName: name,
          ),
        ),
      );
      
      // Ici on ajoutera la navigation vers la salle d'attente plus tard
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Lobby créé avec succès !")),
      );
      
    } catch (e) {
      debugPrint("Erreur lors de la création : $e");
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.white), 
          onPressed: () => Navigator.pop(context)
        ),
      ),
      body: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          color: const Color(0xFF101012),
          image: DecorationImage(
            image: const AssetImage('assets/images/background.jpg'),
            fit: BoxFit.cover,
            colorFilter: ColorFilter.mode(Colors.black.withValues(alpha: 0.7), BlendMode.darken),
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(30.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text(
                  "NOUVEAU LOBBY", 
                  style: TextStyle(fontSize: 30, fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: 4)
                ),
                const SizedBox(height: 50),
                
                // CHAMP NOM DU LOBBY
                TextField(
                  controller: _nameController,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: "Nom du Lobby (ex: Soirée de Kylian)",
                    hintStyle: const TextStyle(color: Colors.white54),
                    filled: true,
                    fillColor: Colors.white.withValues(alpha: 0.1),
                    prefixIcon: const Icon(Icons.meeting_room, color: Colors.white70),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none),
                  ),
                ),
                const SizedBox(height: 20),

                // CHAMP MOT DE PASSE
                TextField(
                  controller: _passwordController,
                  obscureText: true,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: "Mot de passe",
                    hintStyle: const TextStyle(color: Colors.white54),
                    filled: true,
                    fillColor: Colors.white.withValues(alpha: 0.1),
                    prefixIcon: const Icon(Icons.lock, color: Colors.white70),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none),
                  ),
                ),
                
                const SizedBox(height: 50),

                // BOUTON D'ACTION
                _isLoading 
                  ? const CircularProgressIndicator(color: Colors.pinkAccent) // Affiche un chargement si on clique
                  : ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.pinkAccent,
                        minimumSize: const Size(double.infinity, 60),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                      ),
                      onPressed: _createLobby, // 👈 Appelle la fonction Firebase
                      child: const Text("CRÉER ET ATTENDRE LES JOUEURS", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                    ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// L'écran Rejoindre reste en bas car il est plus simple
class JoinLobbyScreen extends StatefulWidget {
  const JoinLobbyScreen({super.key});

  @override
  State<JoinLobbyScreen> createState() => _JoinLobbyScreenState();
}

class _JoinLobbyScreenState extends State<JoinLobbyScreen> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _pseudoController = TextEditingController(); // Nouveau !
  bool _isLoading = false;

  Future<void> _joinLobby() async {
    String lobbyName = _nameController.text.trim();
    String password = _passwordController.text.trim();
    String pseudo = _pseudoController.text.trim();

    if (lobbyName.isEmpty || password.isEmpty || pseudo.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Remplis tous les champs, même ton pseudo !")),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      // 1. On cherche le lobby avec le bon nom et le bon mot de passe
      var query = await FirebaseFirestore.instance
          .collection('lobbies')
          .where('lobbyName', isEqualTo: lobbyName)
          .where('password', isEqualTo: password)
          .where('status', isEqualTo: 'waiting')
          .limit(1)
          .get();

      if (query.docs.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Lobby introuvable ou mauvais mot de passe.")),
          );
        }
      } else {
        // 2. Si on a trouvé, on récupère l'ID du document
        var doc = query.docs.first;
        String docId = doc.id;

        // 3. On ajoute notre pseudo à la liste des joueurs sur Firebase
        await FirebaseFirestore.instance.collection('lobbies').doc(docId).update({
          'players': FieldValue.arrayUnion([pseudo])
        });

        if (!mounted) return;

        // 4. On file dans la salle d'attente !
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => WaitingRoomScreen(
              lobbyId: docId,
              lobbyName: lobbyName,
            ),
          ),
        );
      }
    } catch (e) {
      debugPrint("Erreur lors de la connexion : $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(backgroundColor: Colors.transparent, elevation: 0, leading: const BackButton(color: Colors.white)),
      body: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          color: const Color(0xFF101012),
          image: DecorationImage(
            image: const AssetImage('assets/images/background.jpg'),
            fit: BoxFit.cover,
            colorFilter: ColorFilter.mode(Colors.black.withValues(alpha: 0.7), BlendMode.darken),
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView( // Pour éviter les bugs de clavier
            padding: const EdgeInsets.all(30.0),
            child: Column(
              children: [
                const SizedBox(height: 50),
                const Text("REJOINDRE", style: TextStyle(fontSize: 30, fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: 4)),
                const SizedBox(height: 50),

                // CHAMP PSEUDO
                _buildInput(controller: _pseudoController, hint: "Ton Pseudo", icon: Icons.person),
                const SizedBox(height: 20),

                // CHAMP NOM DU LOBBY
                _buildInput(controller: _nameController, hint: "Nom du Lobby", icon: Icons.meeting_room),
                const SizedBox(height: 20),

                // CHAMP MOT DE PASSE
                _buildInput(controller: _passwordController, hint: "Mot de passe", icon: Icons.lock, isPassword: true),
                
                const SizedBox(height: 50),

                _isLoading 
                ? const CircularProgressIndicator(color: Colors.blueAccent)
                : ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blueAccent,
                      minimumSize: const Size(double.infinity, 60),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                    ),
                    onPressed: _joinLobby,
                    child: const Text("SE CONNECTER", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // Petit widget d'aide pour ne pas répéter le code des TextField
  Widget _buildInput({required TextEditingController controller, required String hint, required IconData icon, bool isPassword = false}) {
    return TextField(
      controller: controller,
      obscureText: isPassword,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: Colors.white54),
        filled: true,
        fillColor: Colors.white.withValues(alpha: 0.1),
        prefixIcon: Icon(icon, color: Colors.white70),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none),
      ),
    );
  }
}