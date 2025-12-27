import 'package:flutter/material.dart';
import 'services/api_service.dart';
import 'chatroom_page.dart';

class ChatListPage extends StatefulWidget {
  const ChatListPage({super.key});

  @override
  State<ChatListPage> createState() => _ChatListPageState();
}

class _ChatListPageState extends State<ChatListPage> {
  bool _loading = true;
  List<Map<String, dynamic>> _users = [];

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  Future<void> _loadUsers() async {
    try {
      final users = await ApiService.getAllUsers();
      final transformed = users.map<Map<String, dynamic>>((u) {
        return {
          'id': u['id'] ?? 0,
          'firstName': u['firstName'] ?? 'Unknown',
          'lastName': u['lastName'] ?? 'User',
          'fullName': (u['fullName'] ?? '').toString().isNotEmpty
              ? u['fullName']
              : '${u['firstName'] ?? ''} ${u['lastName'] ?? ''}'.trim(),
          'picUrlAvatar': u['picUrlAvatar'] ?? '',
          'lastMessage': u['lastMessage'] ?? 'Available for chat',
          'lastMessageTime': DateTime.now(),
          'unreadCount': u['unreadCount'] ?? 0,
          'isOnline': true,
        };
      }).toList();
      setState(() {
        _users = transformed;
        _loading = false;
      });
    } catch (e) {
      setState(() => _loading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load users: $e')),
        );
      }
    }
  }

  String _formatTime(DateTime dt) {
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Chats'),
        backgroundColor: const Color(0xFF075E54),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView.separated(
              itemCount: _users.length,
              separatorBuilder: (_, __) => const Divider(height: 0, indent: 72),
              itemBuilder: (context, index) {
                final u = _users[index];
                final name = (u['fullName'] ?? '').toString().isNotEmpty
                    ? u['fullName']
                    : '${u['firstName']} ${u['lastName']}';
                final avatarUrl = (u['picUrlAvatar'] ?? '').toString();
                final unread = u['unreadCount'] ?? 0;
                final time = (u['lastMessageTime'] is DateTime)
                    ? u['lastMessageTime'] as DateTime
                    : DateTime.now();
                return ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
                  leading: CircleAvatar(
                    radius: 24,
                    backgroundColor: const Color(0xFF075E54),

                    backgroundImage: () {
                      final url = ApiService.getFullAvatarUrl(avatarUrl);
                      return url != null ? NetworkImage(url) : null;
                    }(),
                    child: () {
                      final url = ApiService.getFullAvatarUrl(avatarUrl);
                      return url == null
                          ? Text(
                              name.isNotEmpty ? name[0].toUpperCase() : '?',
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                            )
                          : null;
                    }(),
                  ),
                  title: Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  subtitle: Text(
                    (u['lastMessage'] ?? 'Available for chat').toString(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  trailing: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(_formatTime(time), style: const TextStyle(fontSize: 12, color: Colors.grey)),
                      if (unread > 0)
                        Container(
                          margin: const EdgeInsets.only(top: 6),
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: const BoxDecoration(
                            color: Color(0xFF25D366),
                            borderRadius: BorderRadius.all(Radius.circular(10)),
                          ),
                          child: Text('$unread', style: const TextStyle(color: Colors.white, fontSize: 11)),
                        ),
                    ],
                  ),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ChatroomPage(
                          initialUser: u,
                          standalone: true,
                        ),
                      ),
                    );
                  },
                );
              },
            ),
    );
  }
}
