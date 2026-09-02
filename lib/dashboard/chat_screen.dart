import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ChatScreen extends StatefulWidget {
  final String? userName;
  final String? avatarUrl;

  const ChatScreen({super.key, this.userName, this.avatarUrl});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _supabase = Supabase.instance.client;
  final TextEditingController _messageController = TextEditingController();

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    // Ensure user is signed in
    if (_supabase.auth.currentUser == null) {
      await _supabase.auth.signInAnonymously();
    }

    final user = _supabase.auth.currentUser;
    if (user == null) return;

    final String senderName = widget.userName != null && widget.userName!.isNotEmpty
        ? widget.userName!
        : "User_${user.id.substring(0, 5)}";

    final String finalAvatarUrl = widget.avatarUrl ?? 'https://ui-avatars.com/api/?name=$senderName';

    try {
      await _supabase.from('chat_messages').insert({
        'user_id': user.id,
        'user_name': senderName,
        'message': text,
        'avatar_url': finalAvatarUrl,
      });
      _messageController.clear();
    } catch (e) {
      debugPrint("Error sending message: $e");
    }
  }

  Future<void> _showChatOptions(BuildContext context, Map<String, dynamic> msg) async {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Message Options"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.edit, color: Colors.blue),
              title: const Text("Edit"),
              onTap: () {
                Navigator.pop(context);
                _showEditDialog(context, msg);
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete, color: Colors.red),
              title: const Text("Delete"),
              onTap: () {
                Navigator.pop(context);
                _deleteChatMessage(msg['id']);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _deleteChatMessage(dynamic messageId) async {
    try {
      await _supabase.from('chat_messages').delete().eq('id', messageId);
    } catch (e) {
      debugPrint("Delete Error: $e");
    }
  }

  Future<void> _showEditDialog(BuildContext context, Map<String, dynamic> msg) async {
    final TextEditingController editController = TextEditingController(text: msg['message']);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Edit Message"),
        content: TextField(
          controller: editController,
          autofocus: true,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
          ElevatedButton(
            onPressed: () async {
              final newText = editController.text.trim();
              if (newText.isNotEmpty) {
                await _supabase
                    .from('chat_messages')
                    .update({'message': newText})
                    .eq('id', msg['id']);
              }
              if (context.mounted) Navigator.pop(context);
            },
            child: const Text("Save"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final String? currentUserId = _supabase.auth.currentUser?.id;

    return Scaffold(
      appBar: AppBar(
        title: const Text("Public Chat", style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        elevation: 0.5,
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      body: Column(
        children: [
          // 1. Chat List
          Expanded(
            child: StreamBuilder<List<Map<String, dynamic>>>(
              stream: _supabase
                  .from('chat_messages')
                  .stream(primaryKey: ['id'])
                  .order('created_at', ascending: false)
                  .limit(50),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator.adaptive());
                }

                final messages = snapshot.data!;
                if (messages.isEmpty) {
                  return const Center(child: Text("No messages yet. Say something!"));
                }

                return ListView.builder(
                  reverse: true,
                  padding: const EdgeInsets.all(12),
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final msg = messages[index];
                    final bool isMe = (msg['user_id'] != null && msg['user_id'] == currentUserId);

                    return GestureDetector(
                      onLongPress: isMe ? () => _showChatOptions(context, msg) : null,
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 10.0),
                        child: Row(
                          mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
                          children: [
                            if (!isMe) ...[
                              CircleAvatar(
                                radius: 14,
                                backgroundImage: msg['avatar_url'] != null
                                    ? NetworkImage(msg['avatar_url'])
                                    : NetworkImage('https://ui-avatars.com/api/?name=${msg['user_name'] ?? 'U'}'),
                              ),
                              const SizedBox(width: 8),
                            ],
                            Flexible(
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                decoration: BoxDecoration(
                                  color: isMe ? Colors.blueAccent : Colors.grey.shade200,
                                  borderRadius: BorderRadius.circular(18),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    if (!isMe)
                                      Text(
                                        msg['user_name'] ?? "Unknown",
                                        style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey),
                                      ),
                                    Text(
                                      msg['message'] ?? "",
                                      style: TextStyle(color: isMe ? Colors.white : Colors.black, fontSize: 15),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),

          // 2. Input Field Area
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            color: Colors.white,
            child: SafeArea(
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _messageController,
                      decoration: InputDecoration(
                        hintText: "Say something...",
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide.none),
                        filled: true,
                        fillColor: Colors.grey.shade100,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  CircleAvatar(
                    backgroundColor: Colors.blueAccent,
                    child: IconButton(
                      icon: const Icon(Icons.send, color: Colors.white, size: 18),
                      onPressed: _sendMessage,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}