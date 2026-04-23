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
      // Quand on ferme le chat, on considère qu'on a tout lu
      setState(() {
        _isChatOpen = false;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('lobbies')
          .doc(widget.lobbyId)
          .collection('messages')
          .snapshots(),
      builder: (context, snapshot) {
        int currentCount = snapshot.hasData ? snapshot.data!.docs.length : 0;
        
        // Si le chat est ouvert, on met à jour le compteur de "lus" en temps réel
        if (_isChatOpen) {
          _lastSeenMessageCount = currentCount;
        }

        bool hasNewMessages = currentCount > _lastSeenMessageCount && !_isChatOpen;

        return Stack(
          alignment: Alignment.center,
          children: [
            FloatingActionButton(
              backgroundColor: Colors.blueAccent,
              elevation: 8,
              onPressed: () {
                _lastSeenMessageCount = currentCount; // On marque comme lu
                _showChatSheet(context);
              },
              child: const Icon(Icons.chat_bubble_outline, color: Colors.white),
            ),
            // LA PETITE BULLE ROUGE (Badge)
            if (hasNewMessages)
              Positioned(
                right: 0,
                top: 0,
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: const BoxDecoration(
                    color: Colors.red,
                    shape: BoxShape.circle,
                  ),
                  constraints: const BoxConstraints(minWidth: 12, minHeight: 12),
                ),
              ),
          ],
        );
      },
    );
  }
}