import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'main.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'waiting_room_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'qr_scanner_screen.dart';
import 'package:flutter/foundation.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  int _secretTapCount = 0;
  bool _isPremiumUnlocked = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this); 
    _checkPremiumStatus(); 
    if (!kIsWeb) {
      startGlobalBgm(); // Appel de la nouvelle fonction globale
    }
  }

  // 2. LA FONCTION QUI INTERCEPTE LA MISE EN ARRIÈRE-PLAN
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // On met en pause si l'app est réduite (mobile), cachée (web), ou inactive (appels/notifications)
    if (state == AppLifecycleState.paused || state == AppLifecycleState.hidden || state == AppLifecycleState.inactive) {
      globalBgmPlayer.pause();
    } 
    else if (state == AppLifecycleState.resumed) {
      if (!isGlobalBgmMuted) {
        globalBgmPlayer.resume();
      }
    }
  }

  void _updateVolume(double newVolume) {
    setState(() {
      globalBgmVolume = newVolume;
      if (!isGlobalBgmMuted) {
        globalBgmPlayer.setVolume(globalBgmVolume);
      }
    });
  }

  void _updateSfxVolume(double newVolume) {
    setState(() {
      userSfxVolume = newVolume;
    });
  }

  void _toggleSfxMute() {
    setState(() {
      isSfxMuted = !isSfxMuted; 
    });
  }

  void _toggleMute() {
    setState(() {
      isGlobalBgmMuted = !isGlobalBgmMuted;
      globalBgmPlayer.setVolume(isGlobalBgmMuted ? 0 : globalBgmVolume);
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this); 
    // (J'ai retiré le _bgmPlayer.dispose() qui tuait la musique)
    super.dispose();
  }

  Future<void> _checkPremiumStatus() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _isPremiumUnlocked = prefs.getBool('isPremium') ?? false;
    });
  }

  void _handleSecretTap() {
    _secretTapCount++;
    if (_secretTapCount >= 7) {
      _secretTapCount = 0; 
      _showSecretDialog(); 
    }
  }

  // --- FENÊTRE DES PARAMÈTRES ---
  void _showSettingsDialog() {
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => AlertDialog(
          backgroundColor: const Color(0xFF1A1A1D),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text("PARAMÈTRES", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, letterSpacing: 2)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text("Volume de la musique", style: TextStyle(color: Colors.white70)),
              const SizedBox(height: 10),
              Row(
                children: [
                  IconButton(
                    icon: Icon(isGlobalBgmMuted ? Icons.volume_off : Icons.volume_up, color: Colors.pinkAccent),
                    onPressed: () {
                      _toggleMute();
                      setModalState(() {});
                    },
                  ),
                  Expanded(
                    child: Slider(
                      value: globalBgmVolume,
                      min: 0.0,
                      max: 1.0,
                      activeColor: Colors.pinkAccent,
                      inactiveColor: Colors.white12,
                      onChanged: isGlobalBgmMuted ? null : (val) {
                        _updateVolume(val);
                        setModalState(() {});
                      },
                    ),
                  ),
                  Text("${(globalBgmVolume * 100).toInt()}%", style: const TextStyle(color: Colors.white, fontSize: 12)),
                ],
              ),
              // --- 2. SLIDER BRUITAGES ---
              const Text("Volume des bruitages", style: TextStyle(color: Colors.white70)),
              const SizedBox(height: 10),
              Row(
                children: [
                  IconButton(
                    icon: Icon(isSfxMuted ? Icons.volume_off : Icons.volume_up, color: Colors.blueAccent),
                    onPressed: () {
                      _toggleSfxMute();
                      setModalState(() {});
                    },
                  ),
                  Expanded(
                    child: Slider(
                      value: userSfxVolume, 
                      min: 0.0,
                      max: 1.0,
                      activeColor: Colors.blueAccent,
                      inactiveColor: Colors.white12,
                      onChanged: isSfxMuted ? null : (val) { 
                        _updateSfxVolume(val);
                        setModalState(() {}); 
                      },
                      onChangeEnd: (val) {
                        if (!isSfxMuted) playPop();
                      },
                    ),
                  ),
                  Text("${(userSfxVolume * 100).toInt()}%", style: const TextStyle(color: Colors.white, fontSize: 12)),
                ],
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("FERMER", style: TextStyle(color: Colors.pinkAccent, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  void _showSecretDialog() {
    TextEditingController secretController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1D),
        title: const Text("CODE :", style: TextStyle(color: Colors.white)),
        content: TextField(
          controller: secretController,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(
            hintText: "Code",
            hintStyle: TextStyle(color: Colors.white54),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () async {
              if (secretController.text == "KYKS606") {
                final prefs = await SharedPreferences.getInstance();
                await prefs.setBool('isPremium', true);
                if (context.mounted) {
                  setState(() => _isPremiumUnlocked = true);
                  Navigator.pop(context);
                }
              } else if (secretController.text == "DEFF606") {
                final prefs = await SharedPreferences.getInstance();
                await prefs.setBool('isPremium', false);
                if (context.mounted) {
                  setState(() => _isPremiumUnlocked = false);
                  Navigator.pop(context);
                }
              } else {
                Navigator.pop(context);
              }
            },
            child: const Text("VALIDER", style: TextStyle(color: Colors.pinkAccent)),
          )
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerDown: (_) => startGlobalBgm(),
      child: Scaffold(
        extendBodyBehindAppBar: true, // Permet à l'image de fond d'être sous l'appbar
        appBar: AppBar(
          toolbarHeight: 70, // On agrandit la boîte de l'AppBar !
          backgroundColor: Colors.transparent,
          elevation: 0,
          actions: [
            // --- BOUTON PARAMÈTRES EN HAUT À DROITE ---
            Padding(
              padding: const EdgeInsets.only(top: 20), // Ajoute 20 pixels d'espace en haut
              child: Listener(
                onPointerDown: (_) => playPop(),
                child: IconButton(
                  iconSize: 45, 
                  icon: const Icon(Icons.settings, color: Colors.white70),
                  onPressed: _showSettingsDialog,
                ),
              ),
            ),
            const SizedBox(width: 15), // Espace par rapport à la droite
          ],
        ),
        body: Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: const Color(0xFF101012),
            image: DecorationImage(
              image: const AssetImage('assets/images/background.jpg'),
              fit: BoxFit.cover,
              colorFilter: ColorFilter.mode(
                Colors.black.withValues(alpha: 0.6),
                BlendMode.darken,
              ),
            ),
          ),
          child: SafeArea(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                GestureDetector(
                  onTap: _handleSecretTap,
                  child: const Text(
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
                ),

                if (_isPremiumUnlocked)
                  const Padding(
                    padding: EdgeInsets.only(top: 10),
                    child: Text("👑 Version VIP", style: TextStyle(color: Colors.amber, fontSize: 12, fontWeight: FontWeight.bold)),
                  ),

                const SizedBox(height: 80),

                _mainButton(context, "CRÉER UN LOBBY", Icons.add_moderator, Colors.pinkAccent, () {
                  Navigator.push(context, MaterialPageRoute(builder: (context) => const CreateLobbyScreen()));
                }),

                const SizedBox(height: 20),

                _mainButton(context, "REJOINDRE UN LOBBY", Icons.login, Colors.blueAccent, () {
                  Navigator.push(context, MaterialPageRoute(builder: (context) => const JoinLobbyScreen()));
                }),

                const SizedBox(height: 50),
                const Divider(color: Colors.white24, indent: 50, endIndent: 50),
                const SizedBox(height: 30),

                _mainButton(context, "JOUER EN LOCAL", Icons.phone_android, Colors.greenAccent, () {
                  Navigator.push(context, MaterialPageRoute(builder: (context) => const PlayerScreen()));
                }),
                
                // Placée en bas, elle repousse tout ton bloc central vers le haut !
                const SizedBox(height: 50),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _mainButton(BuildContext context, String text, IconData icon, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTapDown: (_) {
        playPop(); 
      },
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
  final TextEditingController _pseudoController = TextEditingController(); // 1. Ajouté
  
  String _selectedGender = 'H'; // 2. Ajouté
  bool _isLoading = false;

  Future<void> _createLobby() async {
    String name = _nameController.text.trim();
    String password = _passwordController.text.trim();
    String pseudo = _pseudoController.text.trim(); // 3. Récupère le pseudo
    String lobbyName = _nameController.text.trim();

    // 1. Vérifier si le nom est déjà pris
    var existingLobby = await FirebaseFirestore.instance
        .collection('lobbies')
        .where('lobbyName', isEqualTo: lobbyName)
        .get();

    if (existingLobby.docs.isNotEmpty) {
      // Si la liste n'est pas vide, le nom existe déjà
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Ce nom de lobby est déjà utilisé !")),
      );
      return; // On arrête la fonction ici
    }

    if (name.isEmpty || password.isEmpty || pseudo.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Remplis tous les champs, y compris ton pseudo !")),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      // Création du Lobby
      DocumentReference lobbyRef = await FirebaseFirestore.instance.collection('lobbies').add({
        'lobbyName': name,
        'password': password,
        'status': 'waiting',
        'host': pseudo,
        'gameMode': 'Action ou Vérité',
        'players': [
          {'name': pseudo, 'gender': _selectedGender}
        ],
        'createdAt': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => WaitingRoomScreen(
            lobbyId: lobbyRef.id,
            lobbyName: name,
            currentPlayerName: pseudo,
            currentPlayerGender: _selectedGender,
            isHost: true,
            password: password,
          ),
        ),
      );

    } catch (e) {
      debugPrint("Erreur lors de la création : $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // Fonction pour les boutons de genre
  Widget _genderButton({required String label, required String value}) {
    bool isSelected = _selectedGender == value;
    return Expanded(
      child: GestureDetector(
        onTapDown: (_) => playPop(),
        onTap: () => setState(() => _selectedGender = value),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 15),
          decoration: BoxDecoration(
            color: isSelected 
                ? (value == 'H' ? Colors.blueAccent : Colors.pinkAccent) 
                : Colors.white.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(15),
          ),
          child: Center(
            child: Text(label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent, 
        elevation: 0, 
        leading: Listener(
          onPointerDown: (_) => playPop(),
          child: const BackButton(color: Colors.white),
        ),
      ),
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(
          color: const Color(0xFF101012),
          image: DecorationImage(
            image: const AssetImage('assets/images/background.jpg'),
            fit: BoxFit.cover,
            colorFilter: ColorFilter.mode(Colors.black.withValues(alpha: 0.7), BlendMode.darken),
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(30.0),
            child: Column(
              children: [
                const Text("CRÉER UN LOBBY", style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: 3)),
                const SizedBox(height: 40),

                // 🛠️ INTERFACE : Pseudo et Genre
                _buildInput(controller: _pseudoController, hint: "Ton Pseudo", icon: Icons.person),
                const SizedBox(height: 20),
                const Text("TON GENRE :", style: TextStyle(color: Colors.white70, fontSize: 12)),
                const SizedBox(height: 10),
                Row(
                  children: [
                    _genderButton(label: "HOMME", value: "H"),
                    const SizedBox(width: 15),
                    _genderButton(label: "FEMME", value: "F"),
                  ],
                ),
                
                const SizedBox(height: 30),
                const Divider(color: Colors.white24),
                const SizedBox(height: 20),

                // Champs du Lobby
                _buildInput(controller: _nameController, hint: "Nom du Lobby", icon: Icons.meeting_room),
                const SizedBox(height: 20),
                _buildInput(controller: _passwordController, hint: "Mot de passe", icon: Icons.lock, isPassword: true),
                
                const SizedBox(height: 40),

                _isLoading 
                ? const CircularProgressIndicator(color: Colors.pinkAccent)
                : Listener(
                    onPointerDown: (_) => playPop(),
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.pinkAccent,
                        minimumSize: const Size(double.infinity, 60),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                      ),
                      onPressed: _createLobby,
                      child: const Text("CRÉER ET REJOINDRE", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
  Widget _buildInput({
    required TextEditingController controller, 
    required String hint, 
    required IconData icon, 
    bool isPassword = false
  }) {
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
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15), 
          borderSide: BorderSide.none
        ),
      ),
    );
  }
}

class JoinLobbyScreen extends StatefulWidget {
  const JoinLobbyScreen({super.key});

  @override
  State<JoinLobbyScreen> createState() => _JoinLobbyScreenState();
}
class _JoinLobbyScreenState extends State<JoinLobbyScreen> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _pseudoController = TextEditingController();
  
  // Étape A : La variable pour le genre (juste ici au début)
  String _selectedGender = 'H'; 
  bool _isLoading = false;

  Future<void> _joinLobby() async {
    String lobbyName = _nameController.text.trim();
    String password = _passwordController.text.trim();
    String pseudo = _pseudoController.text.trim();

    if (lobbyName.isEmpty || password.isEmpty || pseudo.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Remplis tous les champs !")),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      var query = await FirebaseFirestore.instance
          .collection('lobbies')
          .where('lobbyName', isEqualTo: lobbyName)
          .where('password', isEqualTo: password)
          .limit(1)
          .get();

      if (query.docs.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Lobby introuvable ou mauvais mot de passe.")),
          );
        }
      } else {
        var doc = query.docs.first;
        String docId = doc.id;

        // Étape B : On envoie le pseudo ET le genre sélectionné
        await FirebaseFirestore.instance.collection('lobbies').doc(docId).update({
          'players': FieldValue.arrayUnion([
            {'name': pseudo, 'gender': _selectedGender} 
          ])
        });

        if (!mounted) return;

        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => WaitingRoomScreen(
              lobbyId: docId,
              lobbyName: lobbyName,
              currentPlayerName: pseudo,
              currentPlayerGender: _selectedGender,
              isHost: false,
              password: password,
            ),
          ),
        );
      }
    } catch (e) {
      debugPrint("Erreur : $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // Petit widget pour créer les boutons Homme/Femme facilement
  Widget _genderButton({required String label, required String value}) {
    bool isSelected = _selectedGender == value;
    return Expanded(
      child: GestureDetector(
        onTapDown: (_) => playPop(),
        onTap: () => setState(() => _selectedGender = value),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 15),
          decoration: BoxDecoration(
            color: isSelected 
                ? (value == 'H' ? Colors.blueAccent : Colors.pinkAccent) 
                : Colors.white.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(15),
            border: Border.all(
              color: isSelected ? Colors.white : Colors.transparent,
              width: 2
            ),
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.white : Colors.white54,
                fontWeight: FontWeight.bold
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent, 
        elevation: 0, 
        leading: Listener(
          onPointerDown: (_) => playPop(),
          child: const BackButton(color: Colors.white),
        ),
      ),
      body: Container(
        width: double.infinity,
        height: double.infinity, // Pour remplir tout l'écran
        decoration: BoxDecoration(
          color: const Color(0xFF101012),
          image: DecorationImage(
            image: const AssetImage('assets/images/background.jpg'),
            fit: BoxFit.cover,
            colorFilter: ColorFilter.mode(Colors.black.withValues(alpha: 0.7), BlendMode.darken),
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(30.0),
            child: Column(
              children: [
                const SizedBox(height: 20),
                const Text("REJOINDRE", style: TextStyle(fontSize: 30, fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: 4)),
                const SizedBox(height: 40),

                _buildInput(controller: _pseudoController, hint: "Ton Pseudo", icon: Icons.person),
                const SizedBox(height: 25),

                // Étape C : Les boutons de genre
                const Text("TON GENRE :", style: TextStyle(color: Colors.white70, fontSize: 12, letterSpacing: 2)),
                const SizedBox(height: 10),
                Row(
                  children: [
                    _genderButton(label: "HOMME", value: "H"),
                    const SizedBox(width: 15),
                    _genderButton(label: "FEMME", value: "F"),
                  ],
                ),

                const SizedBox(height: 25),

                // --- BOUTON DE SCAN QR CODE ---
                Listener(
                  onPointerDown: (_) => playPop(),
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.pinkAccent.withValues(alpha: 0.2),
                      side: const BorderSide(color: Colors.pinkAccent),
                      minimumSize: const Size(double.infinity, 55),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                    ),
                    icon: const Icon(Icons.qr_code_scanner, color: Colors.pinkAccent),
                    label: const Text(
                      "SCANNER UN QR CODE",
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, letterSpacing: 1),
                    ),
                    onPressed: () async {
                      String pseudo = _pseudoController.text.trim();
                      if (pseudo.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Tape ton pseudo en haut d'abord ! 👆"), backgroundColor: Colors.orange));
                        return;
                      }

                      // 1. Ouvre la caméra
                      final result = await Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const QRScannerScreen()),
                      );

                      // Si l'utilisateur a appuyé sur retour sans scanner
                      if (result == null) return;

                      // 2. Si le scan a marché et renvoie des données
                      if (result is Map) {
                        setState(() => _isLoading = true);
                        
                        String scannedLobbyId = result['lobbyId']?.toString().trim() ?? "";
                        String scannedPassword = result['password']?.toString().trim() ?? "";

                        // VÉRIFICATION 1 : Est-ce qu'on a bien reçu l'ID ?
                        if (scannedLobbyId.isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Erreur: ID introuvable dans le QR Code"), backgroundColor: Colors.red));
                          setState(() => _isLoading = false);
                          return;
                        }

                        try {
                          var doc = await FirebaseFirestore.instance.collection('lobbies').doc(scannedLobbyId).get();
                          
                          // VÉRIFICATION 2 : Est-ce que le lobby existe sur Firebase ?
                          if (!doc.exists) {
                            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Lobby introuvable sur Firebase (ID: $scannedLobbyId)"), backgroundColor: Colors.red));
                          } 
                          // VÉRIFICATION 3 : Est-ce que le mot de passe est bon ?
                          else if (doc.data()?['password'] != scannedPassword) {
                            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Mauvais mot de passe dans le QR !"), backgroundColor: Colors.red));
                          } 
                          // TOUT EST BON : ON CONNECTE !
                          else {
                            String lobbyName = doc.data()?['lobbyName'] ?? 'Lobby';
                            await doc.reference.update({
                              'players': FieldValue.arrayUnion([{'name': pseudo, 'gender': _selectedGender}])
                            });

                            if (!mounted) return;
                            Navigator.push(context, MaterialPageRoute(builder: (context) => WaitingRoomScreen(
                                  lobbyId: scannedLobbyId, lobbyName: lobbyName,
                                  currentPlayerName: pseudo, currentPlayerGender: _selectedGender,
                                  isHost: false, password: scannedPassword,
                            )));
                          }
                        } catch (e) {
                          // VÉRIFICATION 4 : Erreur de connexion / Firebase
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Erreur système: $e"), backgroundColor: Colors.red));
                        } finally {
                          if (mounted) setState(() => _isLoading = false);
                        }
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Format QR non reconnu par l'écran."), backgroundColor: Colors.red));
                      }
                    },
                  ),
                ),
                
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 20),
                  child: Row(
                    children: [
                      Expanded(child: Divider(color: Colors.white24)),
                      Padding(padding: EdgeInsets.symmetric(horizontal: 10), child: Text("OU", style: TextStyle(color: Colors.white54, fontWeight: FontWeight.bold))),
                      Expanded(child: Divider(color: Colors.white24)),
                    ],
                  ),
                ),
                const SizedBox(height: 25),
                _buildInput(controller: _nameController, hint: "Nom du Lobby", icon: Icons.meeting_room),
                const SizedBox(height: 20),
                _buildInput(controller: _passwordController, hint: "Mot de passe", icon: Icons.lock, isPassword: true),
                
                const SizedBox(height: 40),

                _isLoading 
                ? const CircularProgressIndicator(color: Colors.blueAccent)
                : Listener(
                  onPointerDown: (_) => playPop(),
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blueAccent,
                      minimumSize: const Size(double.infinity, 60),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                    ),
                    onPressed: _joinLobby,
                    child: const Text("SE CONNECTER", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

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