import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'action_verite_screen.dart';
import 'je_nai_jamais_screen.dart';
import 'tribunal_screen.dart';
import 'tu_prefere_screen.dart';
import 'home_screen.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:audioplayers/audioplayers.dart';

// --- GESTIONNAIRE DE BRUITAGES (SFX) ---
final AudioPlayer globalSfxPlayer = AudioPlayer()..setPlayerMode(PlayerMode.lowLatency);

// 1. LES PARAMÈTRES GLOBAUX DU JOUEUR (Accessibles depuis tous les écrans)
double userSfxVolume = 0.5; // Le curseur commence à 50% par défaut
bool isSfxMuted = false;

// 2. LE MIXEUR INTELLIGENT
void playSfx(String fileName, {double soundRatio = 1.0}) async {
  if (isSfxMuted) return; // Si le joueur a mis mute, on ne joue rien
  
  try {
    await globalSfxPlayer.stop();
    // Volume Curseur (ex: 0.5) * Volume du Son (ex: 0.4)
    await globalSfxPlayer.setVolume(userSfxVolume * soundRatio); 
    await globalSfxPlayer.play(AssetSource('audio/$fileName'));
  } catch (e) {
    debugPrint("SFX ignoré (clic trop rapide)");
  }
}

// 3. TES SONS PRÉCONFIGURÉS
void playPop() {
  playSfx('pop.mp3', soundRatio: 0.4); 
}

void playHammer() {
  playSfx('hammer.mp3', soundRatio: 0.4); 
}

void playBloop() {
  playSfx('bloop.mp3', soundRatio: 0.4); 
}

void playBloopNotif() {
  playSfx('bloop_notif.mp3', soundRatio: 0.4); 
}

void playSwoosh() {
  playSfx('swoosh.mp3', soundRatio: 0.4); 
}

// --- LECTEUR DE MUSIQUE GLOBAL ---
final AudioPlayer globalBgmPlayer = AudioPlayer();
bool isBgmStarted = false;
double globalBgmVolume = 0.5;
bool isGlobalBgmMuted = false;

void startGlobalBgm() async {
  if (isBgmStarted) return;
  try {
    isBgmStarted = true;
    globalBgmPlayer.setReleaseMode(ReleaseMode.loop);
    await globalBgmPlayer.play(AssetSource('audio/party_theme.mp3'), volume: isGlobalBgmMuted ? 0 : globalBgmVolume);
  } catch (e) {
    isBgmStarted = false;
    debugPrint("Erreur BGM globale: $e");
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized(); // Indispensable pour Firebase
  
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  await AudioPlayer.global.setAudioContext(AudioContext(
    iOS: AudioContextIOS(
      category: AVAudioSessionCategory.playback, // Autorise de jouer par-dessus d'autres sons sur iPhone
      options: {AVAudioSessionOptions.mixWithOthers},
    ),
    android: AudioContextAndroid(
      isSpeakerphoneOn: false,
      stayAwake: true,
      contentType: AndroidContentType.music,
      usageType: AndroidUsageType.media,
      audioFocus: AndroidAudioFocus.none, // Ne pas voler la priorité audio !
    ),
  ));

  // Précharger le son en mémoire vive pour zéro latence
  await globalSfxPlayer.setSource(AssetSource('audio/pop.mp3'));
  await globalSfxPlayer.setSource(AssetSource('audio/hammer.mp3'));
  await globalSfxPlayer.setSource(AssetSource('audio/bloop.mp3'));
  await globalSfxPlayer.setSource(AssetSource('audio/bloop_notif.mp3'));
  await globalSfxPlayer.setSource(AssetSource('audio/swoosh.mp3'));
  cleanOldLobbies();
  runApp(const ActionVeriteApp());
}

// 1. LA CLASSE PLAYER (Modèle de données)
class Player {
  String name;
  String gender; // 'H' pour Homme, 'F' pour Femme
  int score;
  Player({required this.name, required this.gender, this.score = 0});
}

class ActionVeriteApp extends StatelessWidget {
  const ActionVeriteApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF101012),
      ),
      home: const SplashScreen(), // DÉMARRAGE SUR LE SPLASH SCREEN
    );
  }
}

// --- ÉCRAN 0 : LE SPLASH SCREEN ANIMÉ (DEFFAUT STUDIO) ---
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _navigateToHome();
  }

  _navigateToHome() async {
    // Le splash screen dure exactement 3.5 secondes
    await Future.delayed(const Duration(milliseconds: 3500));
    
    if (mounted) {
      // Redirection fluide en fondu vers l'accueil
      Navigator.pushReplacement(
        context,
        PageRouteBuilder(
          pageBuilder: (context, animation, secondaryAnimation) => const HomeScreen(),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return FadeTransition(opacity: animation, child: child);
          },
          transitionDuration: const Duration(milliseconds: 800),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black, // Fond bien sombre pour le néon
      body: Stack(
        children: [
          // 1. Le Logo au centre avec bords arrondis et animation unique
          Center(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20), // 1. BORDS ARRONDIS
              child: Image.asset(
                'assets/images/logo.png', // Ton logo
                width: 220,
              ),
            )
            // 2. ANIMATION PLUS LENTE ET UNIQUE
            // .forward() joue l'animation une seule fois (pas de boucle)
            .animate(onPlay: (controller) => controller.forward()) 
            // Fade-in plus lent (1.2 secondes)
            .fadeIn(duration: const Duration(milliseconds: 1200))
            // Pulse plus lent (2.5 secondes) et non-répétitif
            .scaleXY(
              begin: 0.95, 
              end: 1.05, 
              duration: const Duration(milliseconds: 2500)
            ), 
          ),
          
          // 2. La Signature DEFFAUT STUDIO en bas
          Positioned(
            bottom: 60,
            left: 0,
            right: 0,
            child: Column(
              children: [
                const Divider(
                  color: Colors.white24,
                  indent: 100,
                  endIndent: 100,
                  thickness: 1,
                ),
                const SizedBox(height: 15),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text(
                      "DEFFAUT",
                      style: TextStyle(
                        fontWeight: FontWeight.w900, // Gras
                        fontSize: 18,
                        color: Colors.white,
                        letterSpacing: 5.0,
                        shadows: [Shadow(color: Colors.blueAccent, blurRadius: 10)], // Lueur néon bleue
                      ),
                    ),
                    const SizedBox(width: 5), // Espace
                    const Text(
                      "STUDIO",
                      style: TextStyle(
                        fontWeight: FontWeight.w300, // Très fin pour le contraste
                        fontSize: 18,
                        color: Colors.white,
                        letterSpacing: 5.0,
                        shadows: [Shadow(color: Colors.blueAccent, blurRadius: 10)], // Lueur néon bleue
                      ),
                    ),
                  ],
                ),
              ],
            )
            .animate()
            // Arrive légèrement après le logo (effet de fondu et de glissement vers le haut)
            .fadeIn(delay: const Duration(milliseconds: 500), duration: const Duration(milliseconds: 1000))
            .slideY(begin: 0.5, end: 0, curve: Curves.easeOut),
          ),
        ],
      ),
    );
  }
}

// --- ÉCRAN 1 : SAISIE DES JOUEURS ---
class PlayerScreen extends StatefulWidget {
  const PlayerScreen({super.key});

  @override
  State<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends State<PlayerScreen> {
  final List<Player> players = []; // Liste d'objets Player maintenant
  final TextEditingController _controller = TextEditingController();
  String selectedGender = 'H'; // Genre sélectionné par défaut

  void addPlayer() {
    if (_controller.text.trim().isNotEmpty) {
      setState(() {
        players.add(Player(
          name: _controller.text.trim(),
          gender: selectedGender,
        ));
        _controller.clear();
      });
    }
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
          child: IconButton(
            icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
            onPressed: () => Navigator.pop(context),
          ),
        )
      ),
      body: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF101012), 
          image: DecorationImage(
            image: const AssetImage('assets/images/background.jpg'),
            fit: BoxFit.cover, // Prends tout l'écran
            colorFilter: ColorFilter.mode(
              Colors.black.withValues(alpha: 0.5), // Ajuste l'alpha (0.0 à 1.0) pour assombrir plus ou moins
              BlendMode.darken,
            ),
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              const SizedBox(height: 40),
              Text(
                "QUI JOUE ?",
                style: const TextStyle(
                  fontSize: 32, // On le met un peu plus grand
                  fontWeight: FontWeight.w900, // Police extra-grasse
                  color: Color.fromARGB(255, 255, 255, 255),
                  letterSpacing: 6, // Plus d'espace entre les lettres pour faire classe
                  shadows: [
                    Shadow(
                      color: Colors.pinkAccent,
                      blurRadius: 10, // Halo rose proche
                    ),
                    Shadow(
                      color: Colors.blueAccent,
                      blurRadius: 10, // Halo bleu plus large derrière
                    ),
                  ],
                ),
              )
              .animate(onPlay: (controller) => controller.repeat(reverse: true)) // On boucle l'animation
              .shimmer(duration: 2.seconds, color: Colors.white.withValues(alpha: 0.4)) // Un petit reflet brillant
              .scaleXY(end: 1.15, duration: 2.seconds), // Respire très doucement
              
              const SizedBox(height: 20),
              // SÉLECTEUR DE GENRE
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _genderButton("HOMME", 'H'),
                  const SizedBox(width: 15),
                  _genderButton("FEMME", 'F'),
                ],
              ),

              Padding(
                padding: const EdgeInsets.all(20.0),
                child: TextField(
                  controller: _controller,
                  decoration: InputDecoration(
                    hintText: "Entrez un prénom...",
                    filled: true,
                    fillColor: Colors.white.withValues(alpha: 0.05),
                    suffixIcon: Listener(
                      onPointerDown: (_) => playPop(),
                      child: IconButton(
                        icon: const Icon(Icons.add_circle, color: Colors.greenAccent), 
                        onPressed: addPlayer,
                      ),
                    ),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(15)),
                  ),
                  onSubmitted: (_) => addPlayer(),
                ),
              ),
              
              Expanded(
                child: ListView.builder(
                  itemCount: players.length,
                  itemBuilder: (context, index) => Card(
                    color: Colors.white.withValues(alpha: 0.1),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                    margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 5), // Ajoute de l'espace entre les joueurs
                    child: ListTile(
                      leading: Icon(
                        players[index].gender == 'H' ? Icons.male : Icons.female,
                        color: players[index].gender == 'H' ? Colors.blue : Colors.pinkAccent,
                      ),
                      title: Text(players[index].name, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
                      trailing: Listener(
                        onPointerDown: (_) => playPop(),
                        child: IconButton(
                          icon: const Icon(Icons.remove_circle, color: Colors.redAccent),
                          onPressed: () => setState(() => players.removeAt(index)),
                        ),
                      ),
                    ),
                  )
                  .animate() // L'animation !
                  .fade(duration: 400.ms)
                  .slideX(begin: 0.5, end: 0, curve: Curves.easeOutBack),
                ),
              ),
              
              if (players.length >= 2)
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: GestureDetector(
                    onTapDown: (_) {
                      playPop(); 
                    },
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => GameSelectionScreen(players: players))),
                    child: Container(
                      width: double.infinity,
                      height: 60,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF00C6FF), Color(0xFF0072FF)], 
                        ),
                        borderRadius: BorderRadius.circular(30),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.blue.withValues(alpha: 0.5), 
                            blurRadius: 20, 
                            spreadRadius: 2,
                            offset: const Offset(0, 5)
                          )
                        ],
                      ),
                      child: const Center(
                        child: Text(
                          "C'EST PARTI !",
                          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: 2),
                        ),
                      ),
                    )
                    .animate(onPlay: (controller) => controller.repeat(reverse: true))
                    .scaleXY(end: 1.03, duration: 1.seconds)
                    .shimmer(delay: 2.seconds, duration: 1.seconds),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _genderButton(String label, String gender) {
    bool isSelected = selectedGender == gender;
    return GestureDetector(
      onTapDown: (_) {
        playPop(); 
      },
      onTap: () => setState(() => selectedGender = gender),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? (gender == 'H' ? Colors.blue : Colors.pinkAccent) : Colors.white10,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: isSelected ? Colors.white : Colors.white24),
        ),
        child: Text(label, style: TextStyle(fontWeight: FontWeight.bold, color: isSelected ? Colors.white : Colors.white38)),
      ),
    );
  }
}

// --- ÉCRAN : SÉLECTION DU JEU ---
class GameSelectionScreen extends StatelessWidget {
  final List<Player> players;
  const GameSelectionScreen({super.key, required this.players});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent, 
        elevation: 0,
        leading: Listener(
          onPointerDown: (_) => playPop(),
          child: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white), 
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
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const SizedBox(height: 20),
                const Text(
                  "CHOISIS TON JEU", 
                  style: TextStyle(
                    color: Colors.white, 
                    fontSize: 26, 
                    fontWeight: FontWeight.w900, 
                    letterSpacing: 4
                  )
                ).animate().fade().scale(),
                
                const SizedBox(height: 40),
                
                // --- JEU 1 : ACTION OU VÉRITÉ ---
                _menuCard(
                  context, 
                  "Action ou Vérité", 
                  "🎭", 
                  const Color(0xFFFB4040), 
                  () {
                    Navigator.push(context, MaterialPageRoute(
                      builder: (context) => CategoryScreen(players: players)
                    ));
                  }
                ),
                
                const SizedBox(height: 20),
                
                // --- JEU 2 : JE N'AI JAMAIS ---
                _menuCard(
                  context, 
                  "Je n'ai jamais", 
                  "🤫", 
                  Colors.deepPurpleAccent, 
                  () {
                    Navigator.push(context, MaterialPageRoute(
                      builder: (context) => JeNaiJamaisScreen(players: players)
                    ));
                  }
                ),

                const SizedBox(height: 20),

                // --- JEU 3 : LE TRIBUNAL  ---
                _menuCard(
                  context, 
                  "Le Tribunal", 
                  "⚖️", 
                  Colors.amber.shade600, 
                  () {
                    Navigator.push(context, MaterialPageRoute(
                      builder: (context) => TribunalScreen(players: players)
                    ));
                  }
                ),

                const SizedBox(height: 20),

                // --- JEU 4 : TU PRÉFÈRES ? ---
                _menuCard(
                  context, 
                  "Tu préfères ?", 
                  "🤔", 
                  Colors.tealAccent.shade400, 
                  () {
                    Navigator.push(context, MaterialPageRoute(
                      builder: (context) => TuPrefereScreen(players: players)
                    ));
                  }
                ),
                
                const SizedBox(height: 40), // Petit espace en bas
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ✨ LA FONCTION DE CARTE STYLÉE
  Widget _menuCard(BuildContext context, String title, String emoji, Color color, VoidCallback onPress) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 30),
      child: InkWell(
        onTapDown: (_) {
          playPop();
        },
        onTap: onPress,
        borderRadius: BorderRadius.circular(25),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(25),
          decoration: BoxDecoration(
            // EFFET GLASSMORPHISM
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                color.withValues(alpha: 0.3),
                color.withValues(alpha: 0.05),
              ],
            ),
            borderRadius: BorderRadius.circular(25),
            border: Border.all(color: color.withValues(alpha: 0.5), width: 1.5),
            boxShadow: [
              BoxShadow(
                color: color.withValues(alpha: 0.15),
                blurRadius: 15,
                offset: const Offset(0, 8),
              )
            ],
          ),
          child: Row(
            children: [
              Text(emoji, style: const TextStyle(fontSize: 40)),
              const SizedBox(width: 20),
              Expanded(
                child: Text(
                  title.toUpperCase(),
                  style: const TextStyle(
                    color: Colors.white, 
                    fontSize: 18, 
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1
                  ),
                ),
              ),
              const Icon(Icons.arrow_forward_ios, color: Colors.white, size: 18),
            ],
          ),
        ),
      ).animate().fadeIn(duration: 600.ms).slideY(begin: 0.2, curve: Curves.easeOutBack),
    );
  }
}

Future<void> cleanOldLobbies() async {
  debugPrint("🧹 Nettoyage des vieux lobbys en cours...");
  
  // On calcule l'heure d'il y a 24 heures
  DateTime twentyFourHoursAgo = DateTime.now().subtract(const Duration(hours: 24));

  // On récupère les lobbys plus vieux que ça
  var oldLobbies = await FirebaseFirestore.instance
      .collection('lobbies')
      .where('createdAt', isLessThan: twentyFourHoursAgo)
      .get();

  // On les supprime un par un
  for (var doc in oldLobbies.docs) {
    await doc.reference.delete();
  }
  
  debugPrint("✅ Nettoyage terminé : ${oldLobbies.docs.length} lobbys supprimés.");
}