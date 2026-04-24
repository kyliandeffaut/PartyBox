import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'live_chat_widget.dart';

class LiveChatFAB extends StatefulWidget {
  final String lobbyId;
  final String currentPlayerName;

  const LiveChatFAB({
    super.key,
    required this.lobbyId,
    required this.currentPlayerName,
  });

  @override
  State<LiveChatFAB> createState() => _LiveChatFABState();
}

class _LiveChatFABState extends State<LiveChatFAB> {
  int _lastSeenMessageCount = 0;
  bool _isChatOpen = false;

  // --- VARIABLES POUR LE DÉPLACEMENT ---
  Offset _position = const Offset(0, 0);
  bool _isInit = false;
  bool _isDragging = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Au démarrage, on place la bulle en bas à droite (comme avant)
    if (!_isInit) {
      final size = MediaQuery.of(context).size;
      _position = Offset(size.width - 75, size.height - 90);
      _isInit = true;
    }
  }

  void _showChatSheet(BuildContext context) {
    setState(() {
      _isChatOpen = true;
    });

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1A1A1D),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
      ),
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
          child: SizedBox(
            height: MediaQuery.of(context).size.height * 0.7,
            child: LiveChatWidget(
              lobbyId: widget.lobbyId,
              currentPlayerName: widget.currentPlayerName,
            ),
          ),
        );
      },
    ).then((_) {
      if (mounted) {
        setState(() {
          _isChatOpen = false;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('lobbies')
          .doc(widget.lobbyId)
          .collection('messages')
          .snapshots(),
      builder: (context, snapshot) {
        int currentCount = snapshot.hasData ? snapshot.data!.docs.length : 0;
        
        if (_isChatOpen) {
          _lastSeenMessageCount = currentCount;
        }

        bool hasNewMessages = currentCount > _lastSeenMessageCount && !_isChatOpen;

        // AnimatedPositioned permet de faire glisser la bulle en douceur quand on lâche
        return AnimatedPositioned(
          duration: _isDragging ? Duration.zero : const Duration(milliseconds: 300),
          curve: Curves.easeOutBack,
          left: _position.dx,
          top: _position.dy,
          child: GestureDetector(
            onPanStart: (details) {
              setState(() => _isDragging = true);
            },
            onPanUpdate: (details) {
              // La bulle suit le doigt
              setState(() {
                _position += details.delta;
              });
            },
            onPanEnd: (details) {
              // EFFET MAGNÉTIQUE (Snap aux bords)
              double newX = _position.dx;
              double newY = _position.dy;

              // Si on lâche la bulle dans la moitié droite, elle colle à droite, sinon à gauche
              if (newX + 28 > size.width / 2) {
                newX = size.width - 75; // Collé à droite
              } else {
                newX = 15; // Collé à gauche
              }

              // On empêche la bulle de sortir de l'écran en haut ou en bas
              if (newY < 60) newY = 60;
              if (newY > size.height - 100) newY = size.height - 100;

              setState(() {
                _isDragging = false;
                _position = Offset(newX, newY);
              });
            },
            child: Material(
              color: Colors.transparent,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  FloatingActionButton(
                    backgroundColor: Colors.blueAccent,
                    elevation: _isDragging ? 15 : 8, // L'ombre grandit quand on soulève la bulle
                    onPressed: () {
                      _lastSeenMessageCount = currentCount;
                      _showChatSheet(context);
                    },
                    child: const Icon(Icons.chat_bubble_outline, color: Colors.white),
                  ),
                  // LA PETITE BULLE ROUGE (Badge)
                  if (hasNewMessages)
                    Positioned(
                      right: -2,
                      top: -2,
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: const BoxDecoration(
                          color: Colors.red,
                          shape: BoxShape.circle,
                          boxShadow: [BoxShadow(color: Colors.black45, blurRadius: 4)],
                        ),
                        constraints: const BoxConstraints(minWidth: 14, minHeight: 14),
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}