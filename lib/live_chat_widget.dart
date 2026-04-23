import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class LiveChatWidget extends StatefulWidget {
  final String lobbyId;
  final String currentPlayerName;

  const LiveChatWidget({
    super.key,
    required this.lobbyId,
    required this.currentPlayerName,
  });

  @override
  State<LiveChatWidget> createState() => _LiveChatWidgetState();
}

class _LiveChatWidgetState extends State<LiveChatWidget> {
  final TextEditingController _chatController = TextEditingController();

  void _sendMessage() async {
    if (_chatController.text.trim().isEmpty) return;
    String text = _chatController.text.trim();
    _chatController.clear();
    
    try {
      await FirebaseFirestore.instance
          .collection('lobbies')
          .doc(widget.lobbyId)
          .collection('messages')
          .add({
        'text': text,
        'sender': widget.currentPlayerName,
        'timestamp': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint("Erreur message: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 15, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        children: [
          // En-tête du chat
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.chat_bubble_outline, color: Colors.blueAccent, size: 16),
                const SizedBox(width: 8),
                const Text("Chat du Lobby", style: TextStyle(color: Colors.white70, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
          const Divider(color: Colors.white10, height: 1),
          
          // Zone des messages
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('lobbies')
                  .doc(widget.lobbyId)
                  .collection('messages')
                  .orderBy('timestamp', descending: true) // Les plus récents en bas
                  .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const Center(child: CircularProgressIndicator(color: Colors.blueAccent));
                var messages = snapshot.data!.docs;
                if (messages.isEmpty) return const Center(child: Text("Sois le premier à parler...", style: TextStyle(color: Colors.white38, fontStyle: FontStyle.italic)));
                
                return ListView.builder(
                  reverse: true, // Auto-scroll vers le bas
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    var msg = messages[index].data() as Map<String, dynamic>;
                    bool isMe = msg['sender'] == widget.currentPlayerName;
                    
                    return Align(
                      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 5, top: 5),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: isMe ? Colors.blueAccent.withValues(alpha: 0.2) : Colors.white.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(15).copyWith(
                            bottomRight: isMe ? const Radius.circular(0) : const Radius.circular(15),
                            bottomLeft: !isMe ? const Radius.circular(0) : const Radius.circular(15),
                          ),
                          border: Border.all(color: isMe ? Colors.blueAccent.withValues(alpha: 0.5) : Colors.white24),
                        ),
                        child: Column(
                          crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                          children: [
                            if (!isMe) Text(msg['sender'] ?? 'Anonyme', style: const TextStyle(color: Colors.blueAccent, fontSize: 10, fontWeight: FontWeight.bold)),
                            Text(msg['text'] ?? '', style: const TextStyle(color: Colors.white, fontSize: 14)),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
          
          // Zone de texte pour envoyer
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _chatController,
                    style: const TextStyle(color: Colors.white, fontSize: 14),
                    decoration: InputDecoration(
                      hintText: "Envoyer un message...",
                      hintStyle: const TextStyle(color: Colors.white38),
                      filled: true,
                      fillColor: Colors.black26,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 15, vertical: 10),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: BorderSide.none),
                    ),
                    onSubmitted: (_) => _sendMessage(),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  decoration: const BoxDecoration(color: Colors.blueAccent, shape: BoxShape.circle),
                  child: IconButton(
                    icon: const Icon(Icons.send, color: Colors.white, size: 18),
                    onPressed: _sendMessage,
                  ),
                )
              ],
            ),
          )
        ],
      ),
    );
  }
}